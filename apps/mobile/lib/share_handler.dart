// Share handler: ekstrak URL pertama dari teks Share Sheet,
// lalu dikirim sebagai {url} ke POST /v1/convert (lihat main.dart).
final _urlRe = RegExp(r'https?://\S+');
final _allowedHost =
    RegExp(r'(^|\.)(tiktok\.com|instagram\.com)$', caseSensitive: false);

String? extractSharedUrl(String? text) {
  if (text == null) return null;
  final m = _urlRe.firstMatch(text);
  if (m == null) return null;
  // Buang tanda baca penutup yang menempel di akhir URL.
  return m.group(0)!.replaceAll(RegExp(r'[)\]}>,.;]+$'), '');
}

bool isSupportedUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https') return false;
  if (uri.userInfo.isNotEmpty) return false;
  return _allowedHost.hasMatch(uri.host);
}

/// URL dari share sheet yang boleh dikirim ke API (TikTok/Instagram https).
String? supportedSharedUrl(String? text) {
  final url = extractSharedUrl(text);
  if (url == null) return null;
  return isSupportedUrl(url) ? url : null;
}

Map<String, String> convertPayload(String url) => {'url': url};
