// Article feed model + helpers (pure, no I/O so it stays unit-testable).
// Source: GET /v1/articles -> {ids} then GET /v1/articles/<id> per item.

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
    required this.references,
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
  final List<String> references;

  factory FeedArticle.fromJson(Map<String, dynamic> json) {
    // The API sometimes returns an object as a list (e.g. brand: [...]);
    // a direct cast (as Map?) would throw and kill the whole feed.
    Map m(dynamic v) => v is Map ? v : const {};
    final body = m(json['id_body']);
    final ld = m(json['json_ld']);
    final review = m(ld['review']);
    final rating = m(review['reviewRating']);
    final brand = m(ld['brand']);
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
      references: _httpsRefs(json['references']),
    );
  }
}

/// Relative time label ("3 days ago"); '' when unparseable.
String timeAgo(String iso, {DateTime? now}) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '';
  final d = (now ?? DateTime.now()).difference(dt);
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) {
    final m = d.inMinutes;
    return '$m min${m == 1 ? '' : 's'} ago';
  }
  if (d.inHours < 24) {
    final h = d.inHours;
    return '$h hr${h == 1 ? '' : 's'} ago';
  }
  if (d.inDays < 7) {
    final days = d.inDays;
    return '$days day${days == 1 ? '' : 's'} ago';
  }
  if (d.inDays < 30) {
    final w = d.inDays ~/ 7;
    return '$w wk${w == 1 ? '' : 's'} ago';
  }
  final mo = d.inDays ~/ 30;
  return '$mo mo${mo == 1 ? '' : 's'} ago';
}

/// Unique brands for filter chips; empty when there are none.
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

/// Valid https references, max 4 (article detail reference cards).
List<String> _httpsRefs(dynamic raw) {
  final out = <String>[];
  for (final u in (raw as List?) ?? const []) {
    final s = '$u';
    if (s.startsWith('https://')) out.add(s);
    if (out.length >= 4) break;
  }
  return out;
}

/// Video source label for feed cards; '' when unrecognized.
/// 5 platforms: TikTok / YouTube / Instagram / Facebook / X.
String articleSource(String videoUrl) {
  final host = Uri.tryParse(videoUrl)?.host.toLowerCase() ?? '';
  if (host.contains('tiktok.com')) return 'TikTok';
  if (host.contains('youtube.com') || host.contains('youtu.be')) {
    return 'YouTube';
  }
  if (host.contains('instagram.com')) return 'Instagram';
  if (host.contains('facebook.com') || host.contains('fb.watch')) {
    return 'Facebook';
  }
  if (host.contains('x.com') || host.contains('twitter.com')) return 'X';
  return '';
}
