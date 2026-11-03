// Detail artikel native: judul, foto, isi, skor, link video asli.
// Pengganti WebView untuk bacaan di dalam app.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'feed.dart';
import 'md.dart';
import 'saba_theme.dart';
import 'vote.dart';

/// Tombol Ikut ala mock, toggle lokal per sesi (tanpa backend, pola VoteStore).
class _FollowButton extends StatefulWidget {
  const _FollowButton({required this.creator});

  final String creator;

  static final Set<String> following = {};

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  @override
  Widget build(BuildContext context) {
    final on = _FollowButton.following.contains(widget.creator);
    return GestureDetector(
      onTap: () => setState(() {
        on
            ? _FollowButton.following.remove(widget.creator)
            : _FollowButton.following.add(widget.creator);
      }),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: on ? SabaColors.greyFill : sabaBlue,
            borderRadius: BorderRadius.circular(999)),
        child: Text(on ? 'Diikuti' : 'Ikut',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: on ? SabaColors.muted2 : Colors.white)),
      ),
    );
  }
}

/// Kartu referensi: label platform + URL, ketuk untuk buka.
/// Tanpa script embed pihak ketiga (ringan).
class _RefCard extends StatelessWidget {
  const _RefCard(
      {required this.url, required this.isVideo, required this.onOpen});

  final String url;
  final bool isVideo;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final source = articleSource(url);
    final label = isVideo && source.isEmpty
        ? 'Video asli'
        : isVideo
            ? 'Video asli • $source'
            : source.isEmpty
                ? 'Tautan'
                : source;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(SabaRadius.card),
              border: Border.all(color: SabaColors.borderSoft)),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: SabaColors.chipBlueBg,
                    borderRadius: BorderRadius.circular(10)),
                child: Text(
                    label.characters.first,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: SabaColors.primary)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: SabaColors.muted2)),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new,
                  size: 16, color: SabaColors.muted2),
            ],
          ),
        ),
      ),
    );
  }
}

class ArticleDetailPage extends StatefulWidget {  const ArticleDetailPage(
      {super.key, required this.jobId, required this.apiBase});

  final String jobId;
  final String apiBase;

  @override
  State<ArticleDetailPage> createState() => _ArticleDetailPageState();
}

class _ArticleDetailPageState extends State<ArticleDetailPage> {
  static const _channel = MethodChannel('saba/share');
  FeedArticle? _article;
  String? _error;
  int _tab = 0; // tab diskusi lokal (visual, isi ikut backend #12).

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

  Future<void> _copyLink(String id) async {
    await Clipboard.setData(
        ClipboardData(text: '${widget.apiBase}/v1/articles/$id'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link artikel disalin')),
    );
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
    if (a == null) {
      return Scaffold(
      backgroundColor: SabaColors.bgCool,
      appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white),
        body: _error != null
            ? Center(child: Text('Gagal memuat: $_error'))
            : const Center(child: CircularProgressIndicator()),
      );
    }
    final ago = timeAgo(a.createdAt);
    final handle = '@${a.brand.isNotEmpty ? a.brand : 'ulasan'}';
    final tags = [
      if (a.brand.isNotEmpty) '#$handle',
      '#Ulasan',
      if (articleSource(a.videoUrl).isNotEmpty)
        '#${articleSource(a.videoUrl)}',
    ];
    return Scaffold(
      backgroundColor: SabaColors.bgCool,
      appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: Text('$handle • Komunitas',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              tooltip: 'Bagikan',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.share_outlined, size: 20),
              color: SabaColors.muted2,
              onPressed: () => _copyLink(a.id),
            ),
            IconButton(
              tooltip: 'Lainnya',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.more_horiz, size: 20),
              color: SabaColors.muted2,
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Laporkan & blokir segera hadir'))),
            ),
          ]),
      body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // Kartu penulis + judul + tag.
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(SabaRadius.card),
                  border:
                      Border.all(color: SabaColors.borderCard)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: SabaColors.greyFill,
                        child: Text(
                            a.creator.isNotEmpty
                                ? a.creator
                                    .trim()
                                    .replaceAll('@', '')[0]
                                    .toUpperCase()
                                : 'S',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: SabaColors.muted2)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                                a.creator.isNotEmpty
                                    ? '$handle • ${a.creator}'
                                    : handle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold)),
                            Text(
                                'Kreator SABA • ${ago.isEmpty ? 'baru saja' : ago}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: SabaColors.muted2)),
                          ],
                        ),
                      ),
                      if (a.creator.isNotEmpty) ...[
                        _FollowButton(creator: a.creator),
                        const SizedBox(width: 8),
                      ],
                      if (a.rating != null)
                        Container(
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: const Color(0xFFFFF7E6),
                              borderRadius:
                                  BorderRadius.circular(999),
                              border: Border.all(
                                  color: const Color(0xFFF5C542))),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star,
                                  size: 14, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(a.rating!,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
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
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      children: [
                        for (final t in tags)
                          Text(t,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: SabaColors.primary)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Isi artikel (serif).
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(SabaRadius.card),
                  border:
                      Border.all(color: SabaColors.borderCard)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (a.excerpt.isNotEmpty) ...[
                    Text(a.excerpt,
                        style: SabaTextStyles.articleBody.copyWith(
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                  ],
                  ...mdBlocks(context, a.body,
                      onLink: (url) => _openVideo(url)),
                  if (a.images.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SizedBox(
                        height: 96,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: a.images.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(width: 8),
                          itemBuilder: (_, i) => ClipRRect(
                            borderRadius: BorderRadius.circular(
                                SabaRadius.img),
                            child: Image.network(a.images[i],
                                width: 96,
                                height: 96,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const SizedBox()),
                          ),
                        ),
                      ),
                    ),
                  if (a.videoUrl.isNotEmpty || a.references.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: SabaColors.bgCool,
                          borderRadius: BorderRadius.circular(
                              SabaRadius.card)),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text('REFERENSI',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: SabaColors.muted2)),
                          const SizedBox(height: 8),
                          for (final u in [
                            if (a.videoUrl.isNotEmpty) a.videoUrl,
                            ...a.references,
                          ].take(4))
                            _RefCard(
                                url: u,
                                isVideo: u == a.videoUrl,
                                onOpen: () => _openVideo(u)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Bar aksi.
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(SabaRadius.card),
                  border:
                      Border.all(color: SabaColors.borderCard)),
              child: VoteBar(
                articleId: a.id,
                onShare: () => _copyLink(a.id),
              ),
            ),
            // Komentar.
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(SabaRadius.card),
                  border:
                      Border.all(color: SabaColors.borderCard)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Tanggapan & Jawaban Komunitas',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: SabaColors.greyFill,
                            borderRadius: BorderRadius.circular(
                                SabaRadius.pill)),
                        child: Text('${baseVotes(a.id) ~/ 6}',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: SabaColors.muted2)),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(
                                content: Text('Filter segera hadir'))),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                  SabaRadius.pill),
                              border: Border.all(
                                  color: SabaColors.borderSoft)),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.filter_list,
                                  size: 12,
                                  color: SabaColors.muted2),
                              SizedBox(width: 4),
                              Text('Filter',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: SabaColors.muted2)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (var i = 0; i < 3; i++)
                        GestureDetector(
                          onTap: () => setState(() => _tab = i),
                          child: Container(
                            margin:
                                const EdgeInsets.only(right: 16),
                            padding: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                                border: Border(
                                    bottom: BorderSide(
                                        color: _tab == i
                                            ? SabaColors.primary
                                            : Colors.transparent,
                                        width: 2))),
                            child: Text(
                                ['Semua', 'Terkurasi', 'Praktisi'][i],
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: _tab == i
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: _tab == i
                                        ? SabaColors.primary
                                        : SabaColors.muted2)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                      'Belum ada tanggapan. Jadilah yang pertama menanggapi ulasan ini.',
                      style: TextStyle(
                          fontSize: 12, color: SabaColors.muted2)),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(
                            content:
                                Text('Diskusi segera hadir'))),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                          color: SabaColors.greyFill,
                          borderRadius: BorderRadius.circular(
                              SabaRadius.pill)),
                      child: const Row(
                        children: [
                          Icon(Icons.chat_bubble_outline,
                              size: 16, color: SabaColors.muted2),
                          SizedBox(width: 8),
                          Text('Tulis tanggapan…',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: SabaColors.muted2)),
                        ],
                      ),
                    ),
                  ),
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
    final idsRaw = (jsonDecode(body) as Map<String, dynamic>)['ids'];
    return [for (final id in (idsRaw is List ? idsRaw : const [])) '$id']
        .take(20)
        .toList();
  } finally {
    client.close();
  }
}
