import 'package:flutter_test/flutter_test.dart';
import 'package:seo_ugc/feed.dart';

Map<String, dynamic> fixture({
  String id = '18',
  String brand = 'Power Up',
  String? rating = '4',
  List<String> images = const ['http://x/f.jpg'],
}) {
  return {
    'id': id,
    'id_body': {'title': 'Judul', 'meta': 'Ringkasan', 'body_md': '## H'},
    'images': images,
    'videoUrl': 'https://youtube.com/shorts/abc',
    'json_ld': {
      'review': {
        'reviewRating': rating == null ? null : {'ratingValue': rating},
      },
      'brand': {'name': brand},
    },
  };
}

void main() {
  test('fromJson memetakan semua field', () {
    final a = FeedArticle.fromJson(fixture());
    expect(a.id, '18');
    expect(a.title, 'Judul');
    expect(a.excerpt, 'Ringkasan');
    expect(a.images, hasLength(1));
    expect(a.rating, '4/5');
    expect(a.brand, 'Power Up');
  });

  test('tanpa rating/brand tetap aman', () {
    final a = FeedArticle.fromJson(fixture(brand: '', rating: null));
    expect(a.rating, isNull);
    expect(a.brand, isEmpty);
    final noBody = FeedArticle.fromJson({'id': 'x'});
    expect(noBody.title, isEmpty);
    expect(noBody.images, isEmpty);
  });

  test('feedBrands unik dan lewati yang kosong', () {
    final list = [
      FeedArticle.fromJson(fixture(id: '1', brand: 'A')),
      FeedArticle.fromJson(fixture(id: '2', brand: 'B')),
      FeedArticle.fromJson(fixture(id: '3', brand: 'A')),
      FeedArticle.fromJson(fixture(id: '4', brand: '')),
    ];
    expect(feedBrands(list), ['A', 'B']);
    expect(filterFeed(list, 'A').map((a) => a.id), ['1', '3']);
    expect(filterFeed(list, null), hasLength(4));
    expect(feedBrands([]), isEmpty);
  });

  test('articleSource melabeli TikTok/YouTube', () {
    expect(articleSource('https://www.tiktok.com/@a/video/1'), 'TikTok');
    expect(articleSource('https://youtube.com/shorts/abc'), 'YouTube');
    expect(articleSource('https://youtu.be/abc'), 'YouTube');
    expect(articleSource('https://example.com/x'), isEmpty);
    expect(articleSource('bukan-url'), isEmpty);
  });

  test('timeAgo label Indonesia', () {
    final now = DateTime(2026, 11, 1, 12);
    expect(timeAgo('not-a-date', now: now), isEmpty);
    expect(timeAgo('', now: now), isEmpty);
    expect(
        timeAgo(
            now.subtract(const Duration(seconds: 10)).toIso8601String(),
            now: now),
        'baru saja');
    expect(
        timeAgo(now.subtract(const Duration(minutes: 5)).toIso8601String(),
            now: now),
        '5 mnt lalu');
    expect(
        timeAgo(now.subtract(const Duration(hours: 3)).toIso8601String(),
            now: now),
        '3 jam lalu');
    expect(
        timeAgo(now.subtract(const Duration(days: 3)).toIso8601String(),
            now: now),
        '3 hari lalu');
    expect(
        timeAgo(now.subtract(const Duration(days: 14)).toIso8601String(),
            now: now),
        '2 mgg lalu');
  });
}
