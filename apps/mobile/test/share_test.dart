import 'package:flutter_test/flutter_test.dart';
import 'package:saba/share.dart';

void main() {
  test('5 target share dengan URL ter-encode', () {
    final out = buildShareLinks('https://saba.ink/article/x', 'Judul A&B');
    expect(out.map((t) => t.key).toList(), ['wa', 'x', 'fb', 'tg', 'copy']);
    expect(out[0].href, contains('wa.me'));
    expect(out[0].href,
        contains(Uri.encodeComponent('https://saba.ink/article/x')));
    expect(out[1].href, contains('twitter.com/intent/tweet'));
    expect(out[2].href, contains('facebook.com/sharer'));
    expect(out[3].href, contains('t.me/share/url'));
    expect(out[4].href, 'https://saba.ink/article/x');
  });
}
