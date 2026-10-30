import 'package:flutter_test/flutter_test.dart';
import 'package:seo_ugc/share_handler.dart';

void main() {
  group('extractSharedUrl', () {
    test('ambil URL dari teks share TikTok', () {
      expect(
        extractSharedUrl('Cek video ini https://vt.tiktok.com/ZSabc123/ keren!'),
        'https://vt.tiktok.com/ZSabc123/',
      );
    });

    test('teks hanya URL', () {
      expect(extractSharedUrl('https://www.instagram.com/reel/ABC123/'),
          'https://www.instagram.com/reel/ABC123/');
    });

    test('buang tanda baca penutup', () {
      expect(extractSharedUrl('link (https://vt.tiktok.com/x/).'),
          'https://vt.tiktok.com/x/');
    });

    test('tanpa URL / null', () {
      expect(extractSharedUrl('tidak ada link'), isNull);
      expect(extractSharedUrl(null), isNull);
      expect(extractSharedUrl(''), isNull);
    });
  });

  test('convertPayload bentuk body API', () {
    expect(convertPayload('https://vt.tiktok.com/x/'),
        {'url': 'https://vt.tiktok.com/x/'});
  });
}
