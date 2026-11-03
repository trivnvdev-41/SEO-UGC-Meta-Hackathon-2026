// Tebak @handle kreator dari link sosmed via oEmbed publik (tanpa API key).
// Didukung: YouTube + TikTok. Instagram/Facebook/X butuh token (tidak didukung).
// Best-effort: gagal jaringan/format -> null, penelepon pakai label fallback.
import 'dart:convert';
import 'dart:io';

class SocialHandle {
  const SocialHandle(
      {required this.platform, required this.handle, required this.name});

  final String platform; // 'youtube' | 'tiktok'
  final String handle; // selalu diawali '@', siap tampil
  final String name; // nama tampilan (bisa kosong)

  @override
  String toString() => '$platform:$handle';
}

String _withAt(String s) {
  final t = s.trim();
  if (t.isEmpty) return t;
  return t.startsWith('@') ? t : '@$t';
}

/// Parse 1 respons oEmbed -> SocialHandle (murni, ter-test).
/// [pageUrl] dipakai menentukan platform; [json] isi oEmbed-nya.
SocialHandle? parseOEmbed(String pageUrl, Map<String, dynamic> json) {
  final host = Uri.tryParse(pageUrl)?.host.toLowerCase() ?? '';
  final isYt = host.contains('youtube.com') || host.contains('youtu.be');
  final isTt = host.contains('tiktok.com');
  if (!isYt && !isTt) return null;

  final authorUrl = '${json['author_url'] ?? ''}';
  String handle = '';
  for (final seg in Uri.tryParse(authorUrl)?.pathSegments ?? <String>[]) {
    if (seg.startsWith('@') && seg.length > 1) {
      handle = seg;
      break;
    }
  }
  final authorName = '${json['author_name'] ?? ''}'.trim();
  handle = handle.isNotEmpty ? handle : authorName;
  if (handle.isEmpty) return null;
  return SocialHandle(
    platform: isYt ? 'youtube' : 'tiktok',
    handle: _withAt(handle),
    name: authorName,
  );
}

String _oembedEndpoint(String pageUrl) {
  final host = Uri.tryParse(pageUrl)?.host.toLowerCase() ?? '';
  final u = Uri.encodeQueryComponent(pageUrl);
  if (host.contains('youtube.com') || host.contains('youtu.be')) {
    return 'https://www.youtube.com/oembed?url=$u&format=json';
  }
  return 'https://www.tiktok.com/oembed?url=$u';
}

/// Lookup handle kreator. Hanya YouTube/TikTok; lainnya langsung null.
/// [cache] opsional: map url -> handle untuk hemat request per sesi.
Future<SocialHandle?> lookupSocialHandle(String pageUrl,
    {Map<String, SocialHandle?>? cache, HttpClient Function()? clientFactory}) async {
  final host = Uri.tryParse(pageUrl)?.host.toLowerCase() ?? '';
  final supported =
      host.contains('youtube.com') || host.contains('youtu.be') || host.contains('tiktok.com');
  if (!supported) return null;
  if (cache != null && cache.containsKey(pageUrl)) return cache[pageUrl];
  final client = (clientFactory ?? HttpClient.new)();
  try {
    final req = await client
        .getUrl(Uri.parse(_oembedEndpoint(pageUrl)))
        .timeout(const Duration(seconds: 10));
    final res = await req.close().timeout(const Duration(seconds: 10));
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode != 200) return null;
    final parsed = tryParseOEmbed(pageUrl, body);
    if (cache != null) cache[pageUrl] = parsed;
    return parsed;
  } catch (_) {
    return null;
  } finally {
    client.close();
  }
}

/// Parse body oEmbed mentah -> SocialHandle (null bila bukan JSON valid).
SocialHandle? tryParseOEmbed(String pageUrl, String body) {
  try {
    final json = jsonDecode(body);
    if (json is Map<String, dynamic>) return parseOEmbed(pageUrl, json);
    return null;
  } catch (_) {
    return null;
  }
}
