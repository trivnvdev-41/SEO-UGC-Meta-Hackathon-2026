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

  group('supportedSharedUrl (filter host)', () {
    test('terima TikTok & Instagram https', () {
      expect(supportedSharedUrl('share https://vt.tiktok.com/ZSabc/'),
          'https://vt.tiktok.com/ZSabc/');
      expect(supportedSharedUrl('https://www.instagram.com/reel/ABC/'),
          'https://www.instagram.com/reel/ABC/');
      expect(supportedSharedUrl('https://www.youtube.com/shorts/abc123'),
          'https://www.youtube.com/shorts/abc123');
      expect(supportedSharedUrl('https://youtu.be/abc123'),
          'https://youtu.be/abc123');
    });

    test('tolak host lain, http, dan userinfo', () {
      expect(supportedSharedUrl('https://evil.com/x'), isNull);
      expect(supportedSharedUrl('https://tiktok.com.evil.com/x'), isNull);
      expect(supportedSharedUrl('https://youtube.com.evil.com/x'), isNull);
      expect(supportedSharedUrl('http://www.tiktok.com/@a/video/1'), isNull);
      expect(supportedSharedUrl('https://user:pw@tiktok.com/x'), isNull);
      expect(supportedSharedUrl('http://169.254.169.254/latest'), isNull);
      expect(supportedSharedUrl('tanpa link'), isNull);
    });
  });

  test('convertPayload bentuk body API', () {
    expect(convertPayload('https://vt.tiktok.com/x/'),
        {'url': 'https://vt.tiktok.com/x/'});
  });
}
