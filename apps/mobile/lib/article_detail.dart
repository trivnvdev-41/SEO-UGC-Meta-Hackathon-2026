// Detail artikel native: judul, foto, isi, skor, link video asli.
// Pengganti WebView untuk bacaan di dalam app.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'feed.dart';
import 'md.dart';
import 'vote.dart';

class ArticleDetailPage extends StatefulWidget {
  const ArticleDetailPage(
      {super.key, required this.jobId, required this.apiBase});

  final String jobId;
  final String apiBase;

  @override
  State<ArticleDetailPage> createState() => _ArticleDetailPageState();
}

class _ArticleDetailPageState extends State<ArticleDetailPage> {
  static const _channel = MethodChannel('dev.seougc/share');
  FeedArticle? _article;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final a = await fetchFeedArticle(widget.apiBase, widget.jobId);
      if (mounted) setState(() => _article = a);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _openVideo(String url) async {
    try {
      await _channel.invokeMethod('openUrl', url);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak bisa membuka browser')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = _article;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
          title: const Text('Ulasan'),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white),
      body: _error != null
          ? Center(child: Text('Gagal memuat: $_error'))
          : a == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: const Color(0xFFEBEBEB))),
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
                                        color: zhihuBlue.withValues(
                                            alpha: 0.3))),
                                child: const Text('c/',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: zhihuBlue)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        'c/${a.brand.isNotEmpty ? a.brand : 'ulasan'}${a.creator.isNotEmpty ? ' • ${a.creator}' : ''}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight:
                                                FontWeight.bold)),
                                    const Text(
                                        'Ulasan produk • dari video kreator',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFF8590A6))),
                                  ],
                                ),
                              ),
                              if (a.rating != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: const Color(0xFFFFF7E6),
                                      borderRadius:
                                          BorderRadius.circular(999),
                                      border: Border.all(
                                          color:
                                              const Color(0xFFF5C542))),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star,
                                          size: 14,
                                          color: Colors.amber),
                                      const SizedBox(width: 4),
                                      Text(a.rating!,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight:
                                                  FontWeight.bold)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(a.title,
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  height: 1.3)),
                          const SizedBox(height: 6),
                          Text(a.excerpt,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF444444),
                                  height: 1.5)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              VotePill(
                                  articleId: a.id),
                              const SizedBox(width: 8),
                              VoteDown(articleId: a.id),
                              const SizedBox(width: 8),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6),
                                decoration: BoxDecoration(
                                    color:
                                        const Color(0xFFF0F2F5),
                                    borderRadius:
                                        BorderRadius.circular(
                                            999),
                                    border: Border.all(
                                        color: const Color(
                                            0xFFE5E8EC))),
                                child: Text(
                                    '${baseVotes(a.id) ~/ 6} Komentar',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF444444),
                                        fontWeight:
                                            FontWeight.w600)),
                              ),
                              const Spacer(),
                              IconButton(
                                visualDensity:
                                    VisualDensity.compact,
                                icon: const Icon(Icons.share_outlined,
                                    size: 18),
                                color:
                                    const Color(0xFF8590A6),
                                onPressed: () async {
                                  await Clipboard.setData(
                                      ClipboardData(
                                          text:
                                              '${widget.apiBase}/v1/articles/${a.id}'));
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(
                                          context)
                                      .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  'Link artikel disalin')));
                                },
                              ),
                              IconButton(
                                visualDensity:
                                    VisualDensity.compact,
                                icon: const Icon(
                                    Icons.bookmark_border,
                                    size: 18),
                                color:
                                    const Color(0xFF8590A6),
                                onPressed: () =>
                                    ScaffoldMessenger.of(
                                            context)
                                        .showSnackBar(
                                            const SnackBar(
                                                content: Text(
                                                    'Disimpan (demo lokal)'))),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (a.images.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: const Color(0xFFEBEBEB))),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(12),
                              child: Image.network(a.images.first,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      const SizedBox()),
                            ),
                            if (a.images.length > 1)
                              Padding(
                                padding: const EdgeInsets.only(
                                    top: 8),
                                child: SizedBox(
                                  height: 96,
                                  child: ListView.separated(
                                    scrollDirection:
                                        Axis.horizontal,
                                    itemCount:
                                        a.images.length - 1,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(
                                            width: 8),
                                    itemBuilder: (_, i) =>
                                        ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(
                                              12),
                                      child: Image.network(
                                          a.images[i + 1],
                                          width: 96,
                                          height: 96,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _,
                                                  _) =>
                                              const SizedBox()),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: const Color(0xFFEBEBEB))),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          ...mdBlocks(context, a.body,
                              onLink: (url) =>
                                  _openVideo(url)),
                          if (a.videoUrl.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () =>
                                    _openVideo(a.videoUrl),
                                icon: const Icon(Icons
                                    .play_circle_outline),
                                label: const Text(
                                    'Tonton video asli'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

/// GET `/v1/articles/<jobId>` -> FeedArticle (null bila 404).
Future<FeedArticle?> fetchFeedArticle(String apiBase, String jobId) async {
  final client = HttpClient();
  try {
    final req = await client
        .getUrl(Uri.parse('$apiBase/v1/articles/$jobId'))
        .timeout(const Duration(seconds: 20));
    final res = await req.close().timeout(const Duration(seconds: 20));
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode == 200) {
      return FeedArticle.fromJson(
          jsonDecode(body) as Map<String, dynamic>);
    }
    return null;
  } finally {
    client.close();
  }
}

/// GET /v1/articles -> daftar id (dibatasi 20 terbaru).
Future<List<String>> fetchFeedIds(String apiBase) async {
  final client = HttpClient();
  try {
    final req = await client
        .getUrl(Uri.parse('$apiBase/v1/articles'))
        .timeout(const Duration(seconds: 20));
    final res = await req.close().timeout(const Duration(seconds: 20));
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode != 200) return [];
    final ids = (jsonDecode(body) as Map<String, dynamic>)['ids'];
    return [for (final id in (ids as List?) ?? const []) '$id']
        .take(20)
        .toList();
  } finally {
    client.close();
  }
}
