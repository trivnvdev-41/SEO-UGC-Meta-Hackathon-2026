import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'article_detail.dart';
import 'feed.dart';
import 'notify.dart';
import 'share_handler.dart';
import 'vote.dart';

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

/// Satu job convert aktif (polling). Riwayat kini diganti feed artikel.
class JobEntry {
  JobEntry({required this.jobId, required this.url});

  final String jobId;
  final String url;
  String status = 'processing'; // processing | done | failed
  String? error;
}

class SharePage extends StatefulWidget {
  const SharePage({super.key});

  @override
  State<SharePage> createState() => _SharePageState();
}

class _SharePageState extends State<SharePage> with WidgetsBindingObserver {
  static const _channel = MethodChannel('dev.seougc/share');

  String _status = 'Bagikan video TikTok/YouTube ke SEO UGC untuk mulai.';
  String? _lastUrl;
  String? _doneJobId;
  bool _busy = false;
  String? _error;
  List<FeedArticle> _feed = [];
  bool _feedLoading = true;
  String? _brandFilter;
  int _tab = 0; // 0=Untuk Anda, 1=Populer, 2=Terbaru
  String _query = '';
  int _navIndex = 0;
  final _search = TextEditingController();

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
    _loadFeed();
  }

  /// Muat feed artikel untuk home. Gagal = feed kosong (status card bicara).
  Future<void> _loadFeed() async {
    if (!mounted) return;
    setState(() => _feedLoading = true);
    try {
      final ids = await fetchFeedIds(apiBase);
      final out = <FeedArticle>[];
      for (final id in ids) {
        if (!mounted) return;
        final a = await fetchFeedArticle(apiBase, id);
        if (a != null) out.add(a);
      }
      if (!mounted) return;
      setState(() {
        _feed = out;
        _feedLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _feedLoading = false);
    }
  }

  /// Feed tampil: filter merek + search lokal + sort tab.
  List<FeedArticle> _visibleFeed() {
    var list = filterFeed(_feed, _brandFilter);
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where((a) =>
              '${a.title} ${a.excerpt} ${a.brand} ${a.creator}'
                  .toLowerCase()
                  .contains(q))
          .toList();
    }
    if (_tab == 1) {
      list = [...list]
        ..sort((a, b) => baseVotes(b.id).compareTo(baseVotes(a.id)));
    }
    return list;
  }

  /// 3 teratas by votes untuk seksi trending.
  List<FeedArticle> _trending() {
    final list = [..._feed]
      ..sort((a, b) => baseVotes(b.id).compareTo(baseVotes(a.id)));
    return list.take(3).toList();
  }

  void _onNav(int i) {
    if (i == 0) {
      setState(() => _navIndex = 0);
      return;
    }
    setState(() => _navIndex = i);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Segera hadir — baru Beranda yang jadi')),
    );
    setState(() => _navIndex = 0);
  }

  /// Sheet tempel link (FAB +): alur convert yang sama, UI ala mockup.
  void _openConvertSheet() {
    final ctrl = TextEditingController(text: _manual.text);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Buat artikel dari link',
                style: Theme.of(ctx).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                hintText: 'Tempel link TikTok/YouTube…',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () {
                      Navigator.of(ctx).pop();
                      _handleText(ctrl.text);
                    },
              child: const Text('Kirim'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    onNotifTap = null;
    _manual.dispose();
    _search.dispose();
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
            : 'Link diabaikan: hanya TikTok/YouTube (https) yang didukung.',
        isError: true,
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _lastUrl = url;
      _doneJobId = null;
      _status = 'Mengirim $url ...';
      _manual.clear();
    });
    final seq = ++_pollSeq;
    try {
      final jobId = await postConvert(url);
      final entry = JobEntry(jobId: jobId, url: url);
      setState(() => _status = 'Job dibuat: $jobId — menunggu artikel...');
      await _pollArticle(entry, seq);
      if (!mounted || seq != _pollSeq) return; // tersalip job baru/cancel.
      setState(() {
        if (entry.status == 'done') {
          _doneJobId = jobId;
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
          await notifyJob('Artikel jadi', jobId, payload: jobId);
        } else {
          await notifyJob('Job $jobId gagal', entry.error ?? 'unknown');
        }
      }
      if (entry.status == 'done') _loadFeed();
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
          entry.status = 'done';
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

  Future<void> _copyArticle(String jobId) async {
    await Clipboard.setData(
        ClipboardData(text: '$webBase/article/$jobId'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link artikel disalin')),
    );
  }

  /// Detail artikel native di dalam app.
  Future<void> _openArticle(String jobId) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) =>
              ArticleDetailPage(jobId: jobId, apiBase: apiBase)),
    );
  }

  Color get _bg => const Color(0xFFF4F6F9);

  Widget _pill(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? zhihuBlue : const Color(0xFFF0F2F5),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                color: selected ? Colors.white : const Color(0xFF444444),
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.w500)),
      ),
    );
  }

  Widget _trendingCard() {
    final top = _trending();
    if (top.isEmpty) return const SizedBox();
    const rankColors = [Color(0xFFFF5A00), Colors.amber, Color(0xFF8590A6)];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEBEBEB))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: Color(0xFFFF5A00), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              const Text('TOPIK PALING RAMAI',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() {
                  _tab = 1;
                  _brandFilter = null;
                }),
                child: const Text('Lihat Semua',
                    style: TextStyle(fontSize: 11, color: zhihuBlue)),
              ),
            ],
          ),
          const Divider(height: 16, color: Color(0xFFF0F2F5)),
          for (var i = 0; i < top.length; i++)
            GestureDetector(
              onTap: () => _openArticle(top[i].id),
              child: Padding(
                padding: EdgeInsets.only(bottom: i < top.length - 1 ? 10 : 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 16,
                      child: Text('${i + 1}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: rankColors[i])),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(top[i].title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(
                              '${compactVotes(baseVotes(top[i].id))} popularitas • ${top[i].brand.isNotEmpty ? top[i].brand : 'ulasan'}',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF8590A6))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _forumCard(FeedArticle a) {
    final comments = baseVotes(a.id) ~/ 6;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEBEBEB))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: zhihuBlue.withValues(alpha: 0.3))),
                child: const Text('c/',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: zhihuBlue)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'c/${a.brand.isNotEmpty ? a.brand : 'ulasan'}${a.creator.isNotEmpty ? ' • ${a.creator}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                    const Text('Ulasan produk • dari video kreator',
                        style: TextStyle(
                            fontSize: 10, color: Color(0xFF8590A6))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _openArticle(a.id),
            child: Text(a.title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold, height: 1.3)),
          ),
          const SizedBox(height: 4),
          Text(a.excerpt,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF444444), height: 1.5)),
          if (a.images.isNotEmpty) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(a.images.first,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox()),
            ),
          ],
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFF0F2F5)),
          const SizedBox(height: 8),
          Row(
            children: [
              VotePill(articleId: a.id, compact: true),
              const SizedBox(width: 6),
              VoteDown(articleId: a.id),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _openArticle(a.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF0F2F5),
                      borderRadius: BorderRadius.circular(999),
                      border:
                          Border.all(color: const Color(0xFFE5E8EC))),
                  child: Text('$comments Komentar',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF444444),
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.share_outlined, size: 18),
                color: const Color(0xFF8590A6),
                onPressed: () => _copyArticle(a.id),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.bookmark_border, size: 18),
                color: const Color(0xFF8590A6),
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Disimpan (demo lokal)'))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding:
                  const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                            color: Color(0xFF2F6B4F),
                            shape: BoxShape.circle),
                        child: const Text('N',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ),
                      const SizedBox(width: 8),
                      const Text('SEO UGC',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10),
                          decoration: BoxDecoration(
                              color: const Color(0xFFF0F2F5),
                              borderRadius:
                                  BorderRadius.circular(999),
                              border: Border.all(
                                  color:
                                      const Color(0xFFE5E8EC))),
                          child: TextField(
                            controller: _search,
                            onChanged: (v) =>
                                setState(() => _query = v),
                            decoration: const InputDecoration(
                              hintText: 'Cari ulasan…',
                              border: InputBorder.none,
                              isDense: true,
                              icon: Icon(Icons.search,
                                  size: 16,
                                  color: Color(0xFF8590A6)),
                            ),
                            style:
                                const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                            Icons.notifications_outlined,
                            size: 20),
                        color: const Color(0xFF444444),
                        onPressed: () =>
                            ScaffoldMessenger.of(context)
                                .showSnackBar(const SnackBar(
                                    content: Text(
                                        'Belum ada notifikasi baru'))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _pill(
                            'Untuk Anda',
                            _tab == 0 &&
                                _brandFilter == null, () =>
                                setState(() {
                                  _tab = 0;
                                  _brandFilter = null;
                                })),
                        const SizedBox(width: 8),
                        _pill(
                            'Populer',
                            _tab == 1 &&
                                _brandFilter == null, () =>
                                setState(() {
                                  _tab = 1;
                                  _brandFilter = null;
                                })),
                        const SizedBox(width: 8),
                        _pill(
                            'Terbaru',
                            _tab == 2 &&
                                _brandFilter == null, () =>
                                setState(() {
                                  _tab = 2;
                                  _brandFilter = null;
                                })),
                        for (final b
                            in feedBrands(_feed)) ...[
                          const SizedBox(width: 8),
                          _pill(
                              b,
                              _brandFilter == b,
                              () => setState(
                                  () => _brandFilter = b)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_busy ||
                _error != null ||
                _doneJobId != null)
              Container(
                width: double.infinity,
                color: Colors.white,
                padding:
                    const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    _StatusCard(
                      busy: _busy,
                      status: _status,
                      url: _lastUrl,
                      isError: _error != null,
                    ),
                    if (_busy)
                      Align(
                        alignment:
                            Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () =>
                              setState(() => _pollSeq++),
                          icon:
                              const Icon(Icons.close),
                          label:
                              const Text('Batal'),
                        ),
                      ),
                    if (_doneJobId != null)
                      Padding(
                        padding:
                            const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            FilledButton.icon(
                              onPressed: () =>
                                  _openArticle(
                                      _doneJobId!),
                              icon: const Icon(
                                  Icons.open_in_new,
                                  size: 16),
                              label:
                                  const Text('Baca'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _copyArticle(
                                      _doneJobId!),
                              icon: const Icon(
                                  Icons.copy,
                                  size: 16),
                              label: const Text(
                                  'Salin link'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _trendingCard(),
                  const SizedBox(height: 12),
                  if (_feedLoading)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                          child:
                              CircularProgressIndicator()),
                    )
                  else if (_visibleFeed().isEmpty)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 24),
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: theme.colorScheme
                                  .primaryContainer,
                              borderRadius:
                                  BorderRadius.circular(
                                      20),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'N',
                              style: theme
                                  .textTheme.headlineMedium
                                  ?.copyWith(
                                color: theme.colorScheme
                                    .onPrimaryContainer,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '1. Share video dari TikTok/YouTube ke SEO UGC\n'
                            '2. Tunggu notifikasi — artikel dimasak di server\n'
                            '3. Buka dan baca artikel di dalam app ini',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(
                              color: theme
                                  .colorScheme.outline,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    for (final a in _visibleFeed()) ...[
                      _forumCard(a),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openConvertSheet,
        backgroundColor: zhihuBlue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _navIndex,
        onTap: _onNav,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: zhihuBlue,
        unselectedItemColor: const Color(0xFF8590A6),
        selectedFontSize: 10,
        unselectedFontSize: 10,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home), label: 'Beranda'),
          BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              label: 'Jelajah'),
          BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              label: 'Kotak Masuk'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'Profil'),
        ],
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
