import 'package:flutter_test/flutter_test.dart';
import 'package:saba/feed.dart';

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

  test('brand/review berbentuk list tidak membunuh parse', () {
    // Regresi: job_f8a3de71cd3b punya json_ld.brand berupa list;
    // 1 artikel begini membuat seluruh feed kosong di release.
    final raw = fixture();
    raw['json_ld'] = {
      'brand': [
        {'name': 'A'},
        {'name': 'B'}
      ]
    };
    final a = FeedArticle.fromJson(raw);
    expect(a.brand, isEmpty);
    expect(a.title, 'Judul');
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

  test('articleSource melabeli 5 platform', () {
    expect(articleSource('https://www.tiktok.com/@a/video/1'), 'TikTok');
    expect(articleSource('https://youtube.com/shorts/abc'), 'YouTube');
    expect(articleSource('https://youtu.be/abc'), 'YouTube');
    expect(articleSource('https://www.instagram.com/p/AbC123/'), 'Instagram');
    expect(
        articleSource('https://www.facebook.com/reel/123456789012345'),
        'Facebook');
    expect(articleSource('https://x.com/u/status/123'), 'X');
    expect(articleSource('https://twitter.com/u/status/123'), 'X');
    expect(articleSource('https://example.com/x'), isEmpty);
    expect(articleSource('bukan-url'), isEmpty);
  });

  test('references diparse, non-https dibuang, maks 4', () {
    final raw = fixture();
    raw['references'] = [
      'https://instagram.com/p/abc/',
      'http://tanpa-s.test/x',
      'https://x.com/u/status/1',
      'https://facebook.com/reel/123456',
      'https://tiktok.com/@a/video/1',
    ];
    final a = FeedArticle.fromJson(raw);
    expect(a.references, [
      'https://instagram.com/p/abc/',
      'https://x.com/u/status/1',
      'https://facebook.com/reel/123456',
      'https://tiktok.com/@a/video/1',
    ]);
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
