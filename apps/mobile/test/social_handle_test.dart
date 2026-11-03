// Lookup @handle kreator sosmed via oEmbed publik (murni + network tipis).
import 'package:flutter_test/flutter_test.dart';
import 'package:saba/social_handle.dart';

const ytJson = {
  'author_name': 'Rick Astley',
  'author_url': 'https://www.youtube.com/@RickAstleyYT',
};

const ytChannelJson = {
  'author_name': 'Some Channel',
  'author_url': 'https://www.youtube.com/channel/UC123abc',
};

const ttJson = {
  'author_name': 'nba',
  'author_url': 'https://www.tiktok.com/@nba',
};

void main() {
  test('YouTube: handle dari author_url, nama tampil terpisah', () {
    final h = parseOEmbed(
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ', ytJson)!;
    expect(h.platform, 'youtube');
    expect(h.handle, '@RickAstleyYT');
    expect(h.name, 'Rick Astley');
  });

  test('YouTube youtu.be ikut didukung', () {
    final h = parseOEmbed('https://youtu.be/dQw4w9WgXcQ', ytJson)!;
    expect(h.handle, '@RickAstleyYT');
  });

  test('TikTok: handle dari author_url', () {
    final h = parseOEmbed(
        'https://www.tiktok.com/@nba/video/1', ttJson)!;
    expect(h.platform, 'tiktok');
    expect(h.handle, '@nba');
  });

  test('tanpa author_url pakai author_name + @', () {
    final h = parseOEmbed(
        'https://www.tiktok.com/@nba/video/1', {'author_name': 'nba'})!;
    expect(h.handle, '@nba');
  });

  test('channel-ID tanpa @ -> fallback nama', () {
    final h = parseOEmbed(
        'https://www.youtube.com/watch?v=x', ytChannelJson)!;
    expect(h.handle, '@Some Channel');
  });

  test('Instagram/FB/X/asing -> null', () {
    expect(
        parseOEmbed('https://www.instagram.com/p/abc/', {'author_name': 'x'}),
        isNull);
    expect(parseOEmbed('https://example.com/x', ytJson), isNull);
    expect(parseOEmbed('bukan-url', {}), isNull);
  });

  test('tryParseOEmbed aman untuk body rusak', () {
    expect(tryParseOEmbed('https://www.youtube.com/watch?v=x', 'bukan json'),
        isNull);
    final h = tryParseOEmbed(
        'https://www.youtube.com/watch?v=x',
        '{"author_name":"A","author_url":"https://www.youtube.com/@A"}')!;
    expect(h.handle, '@A');
  });
}
