import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'article_page.dart';
import 'notify.dart';
import 'share_handler.dart';

// 10.0.2.2 = localhost mesin host dari Android emulator.
// Override: flutter run --dart-define=API_BASE=https://api.example.com
//   --dart-define=WEB_BASE=https://web.example.com
const apiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://10.0.2.2:4301',
);
const webBase = String.fromEnvironment(
  'WEB_BASE',
  defaultValue: 'http://10.0.2.2:4320',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initNotif();
  runApp(const SeoUgcApp());
}

class SeoUgcApp extends StatelessWidget {
  const SeoUgcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SEO UGC',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF2F6B4F)),
      home: const SharePage(),
    );
  }
}

/// Satu entri riwayat convert (in-memory, terbaru dulu).
class JobEntry {
  JobEntry({required this.jobId, required this.url}) : at = DateTime.now();

  final String jobId;
  final String url;
  final DateTime at;
  String status = 'processing'; // processing | done | failed
  String? articleUrl;
  String? error;

  String get time =>
      '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
}

class SharePage extends StatefulWidget {
  const SharePage({super.key});

  @override
  State<SharePage> createState() => _SharePageState();
}

class _SharePageState extends State<SharePage> with WidgetsBindingObserver {
  static const _channel = MethodChannel('dev.seougc/share');

  String _status = 'Bagikan video TikTok/IG/YouTube ke SEO UGC untuk mulai.';
  String? _lastUrl;
  String? _articleUrl;
  bool _busy = false;
  String? _error;
  final List<JobEntry> _history = [];

  String? _lastHandled;
  DateTime? _lastHandledAt;
  int _pollSeq = 0; // token poll aktif; poll lama berhenti saat tersalip/cancel.
  bool _foreground = true; // false = notifikasi info saat job selesai.
  final _manual = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    onNotifTap = (payload) async {
      if (payload != null) _openArticle(payload);
    };
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'shared') await _handleText(call.arguments as String?);
    });
    _loadInitial();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    onNotifTap = null;
    _manual.dispose();
    super.dispose();
  }

  // Share saat app sudah terbuka (singleTask) bisa datang sebelum channel siap;
  // ambil ulang pending text setiap app kembali ke depan.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed) _loadInitial();
  }

  Future<void> _loadInitial() async {
    try {
      final text = await _channel.invokeMethod<String>('getInitialSharedText');
      if (text != null) await _handleText(text);
    } on MissingPluginException {
      // Non-Android (channel hanya ada di MainActivity Android).
    }
  }

  Future<void> _handleText(String? text) async {
    final url = supportedSharedUrl(text);
    if (url != null) {
      final now = DateTime.now();
      final dup = url == _lastHandled &&
          _lastHandledAt != null &&
          now.difference(_lastHandledAt!) < const Duration(seconds: 5);
      if (dup) return;
      _lastHandled = url;
      _lastHandledAt = now;
    }
    if (url == null) {
      _set(
        extractSharedUrl(text) == null
            ? 'Tidak ada URL di teks yang dibagikan.'
            : 'Link diabaikan: hanya TikTok/Instagram/YouTube (https) yang didukung.',
        isError: true,
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _lastUrl = url;
      _articleUrl = null;
      _status = 'Mengirim $url ...';
      _manual.clear();
    });
    final seq = ++_pollSeq;
    try {
      final jobId = await postConvert(url);
      final entry = JobEntry(jobId: jobId, url: url);
      setState(() {
        _history.insert(0, entry);
        if (_history.length > 20) _history.removeLast();
        _status = 'Job dibuat: $jobId — menunggu artikel...';
      });
      await _pollArticle(entry, seq);
      if (!mounted || seq != _pollSeq) return; // tersalip job baru/cancel.
      setState(() {
        if (entry.status == 'done') {
          _articleUrl = entry.articleUrl;
          _status = 'Artikel jadi: $jobId';
        } else {
          _error = entry.error;
          _status = 'Job $jobId gagal: ${entry.error}';
        }
        _busy = false;
      });
      // Info di background saja; di foreground user sudah melihat status card.
      if (!_foreground) {
        if (entry.status == 'done') {
          await notifyJob('Artikel jadi', entry.articleUrl!,
              payload: entry.articleUrl);
        } else {
          await notifyJob('Job $jobId gagal', entry.error ?? 'unknown');
        }
      }
    } catch (e) {
      if (!mounted || seq != _pollSeq) return; // tersalip job baru/cancel.
      _set('Gagal: $e', isError: true);
    }
  }

  /// Poll `GET /v1/articles/<jobId>` sampai 200 (maks ~6 menit).
  /// Berhenti saat `seq` tersalip (job baru/cancel): entry ditandai dibatalkan.
  Future<void> _pollArticle(JobEntry entry, int seq) async {
    for (var i = 0; i < 72; i++) {
      if (!mounted || seq != _pollSeq) {
        if (entry.status == 'processing') {
          entry
            ..status = 'failed'
            ..error = 'dibatalkan';
        }
        return;
      }
      try {
        if (await fetchArticle(entry.jobId)) {
          entry
            ..status = 'done'
            ..articleUrl = '$webBase/article/${entry.jobId}';
          return;
        }
      } catch (_) {
        // Jaringan sempat putus: coba lagi sampai batas poll.
      }
      await Future<void>.delayed(const Duration(seconds: 5));
    }
    entry
      ..status = 'failed'
      ..error = 'timeout: artikel belum jadi setelah 6 menit';
  }

  void _set(String status, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = status;
      _error = isError ? status : null;
    });
  }

  Future<void> _copyArticle(String articleUrl) async {
    await Clipboard.setData(ClipboardData(text: articleUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link artikel disalin')),
    );
  }

  /// Artikel dibuka di dalam app. Browser eksternal tak lagi dipakai
  /// (channel `openUrl` di MainActivity tinggal sebagai cadangan).
  Future<void> _openArticle(String articleUrl) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ArticlePage(url: articleUrl)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('SEO UGC')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manual,
                    decoration: const InputDecoration(
                      hintText: 'Tempel link TikTok/IG/YouTube…',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.url,
                    onSubmitted: _handleText,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _busy ? null : () => _handleText(_manual.text),
                  child: const Text('Kirim'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _StatusCard(
              busy: _busy,
              status: _status,
              url: _lastUrl,
              isError: _error != null,
            ),
            if (_busy)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(() => _pollSeq++),
                  icon: const Icon(Icons.close),
                  label: const Text('Batal'),
                ),
              ),
            if (_articleUrl != null) ...[
              const SizedBox(height: 12),
              Card(
                color: theme.colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Text('Artikel jadi!',
                        style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      SelectableText(_articleUrl!),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          FilledButton.icon(
                            onPressed: () => _copyArticle(_articleUrl!),
                            icon: const Icon(Icons.copy),
                            label: const Text('Salin link'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => _openArticle(_articleUrl!),
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Buka'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Riwayat (${_history.length})',
                    style: theme.textTheme.titleMedium),
                const Spacer(),
                if (_history.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(_history.clear),
                    child: const Text('Hapus'),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: _history.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'N',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '1. Share video dari TikTok/IG/YouTube ke SEO UGC\n'
                            '2. Tunggu notifikasi — artikel dimasak di server\n'
                            '3. Buka dan baca artikel di dalam app ini',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _history.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final e = _history[i];
                        return _HistoryTile(
                          entry: e,
                          onCopy: () => _copyArticle(e.articleUrl!),
                          onOpen: () => _openArticle(e.articleUrl!),
                          onRetry: e.status == 'failed' && !_busy
                              ? () => _handleText(e.url)
                              : null,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.busy,
    required this.status,
    required this.url,
    required this.isError,
  });

  final bool busy;
  final String status;
  final String? url;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = busy
        ? Icons.hourglass_top
        : isError
            ? Icons.error_outline
            : Icons.check_circle_outline;
    final color = isError
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(status,
                      style: theme.textTheme.bodyLarge),
                ),
              ],
            ),
            if (busy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (url != null) ...[
              const SizedBox(height: 8),
              SelectableText(url!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.entry,
    required this.onCopy,
    required this.onOpen,
    required this.onRetry,
  });

  final JobEntry entry;
  final VoidCallback onCopy;
  final VoidCallback onOpen;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chip = switch (entry.status) {
      'done' => const Chip(
          avatar: Icon(Icons.check, size: 16),
          label: Text('done'),
        ),
      'failed' => Chip(
          avatar: const Icon(Icons.close, size: 16),
          label: const Text('failed'),
          backgroundColor: theme.colorScheme.errorContainer,
        ),
      _ => const Chip(
          avatar: SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          label: Text('processing'),
        ),
    };
    return Card(
      elevation: 0,
      child: ListTile(
        leading: const Icon(Icons.movie_outlined),
        title: Text(entry.url,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium),
        subtitle: Text('${entry.jobId} · ${entry.time}'
            '${entry.error != null ? '\n${entry.error}' : ''}'),
        isThreeLine: entry.error != null,
        trailing: Wrap(
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            chip,
            if (entry.status == 'done') ...[
              IconButton(
                tooltip: 'Salin link artikel',
                icon: const Icon(Icons.copy),
                onPressed: onCopy,
              ),
              IconButton(
                tooltip: 'Buka artikel',
                icon: const Icon(Icons.open_in_new),
                onPressed: onOpen,
              ),
            ],
            if (onRetry != null)
              IconButton(
                tooltip: 'Coba lagi',
                icon: const Icon(Icons.refresh),
                onPressed: onRetry,
              ),
          ],
        ),
      ),
    );
  }
}

/// `GET /v1/articles/<jobId>` → true jika 200 (artikel jadi).
Future<bool> fetchArticle(String jobId) async {
  final client = HttpClient();
  try {
    final req = await client
        .getUrl(Uri.parse('$apiBase/v1/articles/$jobId'))
        .timeout(const Duration(seconds: 20));
    final res = await req.close().timeout(const Duration(seconds: 20));
    await res.transform(utf8.decoder).join();
    return res.statusCode == 200;
  } finally {
    client.close();
  }
}

/// POST /v1/convert → jobId. Tanpa dependency tambahan (dart:io).
Future<String> postConvert(String url) async {
  final client = HttpClient();
  try {
    final req = await client.postUrl(Uri.parse('$apiBase/v1/convert'));
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode(convertPayload(url)));
    final res = await req.close().timeout(const Duration(seconds: 20));
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode != 202) {
      throw Exception('api ${res.statusCode}: $body');
    }
    final jobId =
        (jsonDecode(body) as Map<String, dynamic>)['jobId'] as String?;
    if (jobId == null || jobId.isEmpty) throw Exception('api: empty jobId');
    return jobId;
  } finally {
    client.close();
  }
}
