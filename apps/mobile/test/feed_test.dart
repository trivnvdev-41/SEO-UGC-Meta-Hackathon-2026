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
}
