// Model + helper feed artikel (murni, tanpa I/O agar bisa di-unit-test).
// Sumber: GET /v1/articles -> {ids} lalu GET /v1/articles/<id> per item.

class FeedArticle {
  FeedArticle({
    required this.id,
    required this.title,
    required this.excerpt,
    required this.body,
    required this.images,
    required this.videoUrl,
    required this.rating,
    required this.brand,
    required this.creator,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String excerpt;
  final String body;
  final List<String> images;
  final String videoUrl;
  final String? rating;
  final String brand;
  final String creator;
  final String createdAt;

  factory FeedArticle.fromJson(Map<String, dynamic> json) {
    final body = (json['id_body'] as Map?) ?? const {};
    final ld = (json['json_ld'] as Map?) ?? const {};
    final review = (ld['review'] as Map?) ?? const {};
    final rating = (review['reviewRating'] as Map?) ?? const {};
    final brand = (ld['brand'] as Map?) ?? const {};
    return FeedArticle(
      id: '${json['id'] ?? ''}',
      title: '${body['title'] ?? ''}',
      excerpt: '${body['meta'] ?? ''}',
      body: '${body['body_md'] ?? ''}',
      images: [
        for (final u in (json['images'] as List?) ?? const []) '$u'
      ],
      videoUrl: '${json['videoUrl'] ?? ''}',
      rating: rating['ratingValue'] != null
          ? '${rating['ratingValue']}/5'
          : null,
      brand: '${brand['name'] ?? ''}',
      creator: '${json['creator'] ?? ''}',
      createdAt: '${json['createdAt'] ?? ''}',
    );
  }
}

/// Label waktu relatif ID ala mock ("3 hari lalu"); '' bila tak terparse.
String timeAgo(String iso, {DateTime? now}) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '';
  final d = (now ?? DateTime.now()).difference(dt);
  if (d.inMinutes < 1) return 'baru saja';
  if (d.inHours < 1) return '${d.inMinutes} mnt lalu';
  if (d.inHours < 24) return '${d.inHours} jam lalu';
  if (d.inDays < 7) return '${d.inDays} hari lalu';
  if (d.inDays < 30) return '${d.inDays ~/ 7} mgg lalu';
  return '${d.inDays ~/ 30} bln lalu';
}

/// Merek unik untuk chip filter; kosong bila tak ada merek.
List<String> feedBrands(List<FeedArticle> articles) {
  final seen = <String>[];
  for (final a in articles) {
    if (a.brand.isNotEmpty && !seen.contains(a.brand)) seen.add(a.brand);
  }
  return seen;
}

List<FeedArticle> filterFeed(List<FeedArticle> articles, String? brand) {
  if (brand == null || brand.isEmpty) return articles;
  return articles.where((a) => a.brand == brand).toList();
}

/// Label sumber video untuk kartu feed; '' bila tak dikenali.
String articleSource(String videoUrl) {
  final host = Uri.tryParse(videoUrl)?.host.toLowerCase() ?? '';
  if (host.contains('tiktok.com')) return 'TikTok';
  if (host.contains('youtube.com') || host.contains('youtu.be')) {
    return 'YouTube';
  }
  return '';
}
