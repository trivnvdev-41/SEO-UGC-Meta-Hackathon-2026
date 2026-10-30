import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'share_handler.dart';

// 10.0.2.2 = localhost mesin host dari Android emulator.
// Override: flutter run --dart-define=API_BASE=https://api.example.com
const apiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://10.0.2.2:4301',
);

void main() {
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

class SharePage extends StatefulWidget {
  const SharePage({super.key});

  @override
  State<SharePage> createState() => _SharePageState();
}

class _SharePageState extends State<SharePage> with WidgetsBindingObserver {
  static const _channel = MethodChannel('dev.seougc/share');

  String _status = 'Bagikan video TikTok/IG ke SEO UGC untuk mulai.';
  String? _lastUrl;
  bool _busy = false;

  String? _lastHandled;
  DateTime? _lastHandledAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'shared') await _handleText(call.arguments as String?);
    });
    _loadInitial();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Share saat app sudah terbuka (singleTask) bisa datang sebelum channel siap;
  // ambil ulang pending text setiap app kembali ke depan.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadInitial();
  }

  Future<void> _loadInitial() async {
    try {
      final text = await _channel.invokeMethod<String>('getInitialSharedText');
      if (text != null) await _handleText(text);
    } on MissingPluginException {
      // Platform tanpa channel (mis. iOS extension belum terpasang).
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
      _set(extractSharedUrl(text) == null
          ? 'Tidak ada URL di teks yang dibagikan.'
          : 'Link diabaikan: hanya TikTok/Instagram (https) yang didukung.');
      return;
    }
    setState(() {
      _busy = true;
      _lastUrl = url;
      _status = 'Mengirim $url ...';
    });
    try {
      final jobId = await postConvert(url);
      _set('Job dibuat: $jobId');
    } catch (e) {
      _set('Gagal: $e');
    }
  }

  void _set(String status) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = status;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SEO UGC')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_busy) const LinearProgressIndicator(),
            const SizedBox(height: 16),
            Text(_status, style: Theme.of(context).textTheme.bodyLarge),
            if (_lastUrl != null) ...[
              const SizedBox(height: 12),
              SelectableText(_lastUrl!),
            ],
          ],
        ),
      ),
    );
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
    return (jsonDecode(body) as Map<String, dynamic>)['jobId'] as String? ?? '';
  } finally {
    client.close();
  }
}
