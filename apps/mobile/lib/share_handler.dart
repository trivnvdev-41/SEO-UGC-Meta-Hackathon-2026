// Share handler: ekstrak URL pertama dari teks Share Sheet,
// lalu dikirim sebagai {url} ke POST /v1/convert (lihat main.dart).
final _urlRe = RegExp(r'https?://\S+');

String? extractSharedUrl(String? text) {
  if (text == null) return null;
  final m = _urlRe.firstMatch(text);
  if (m == null) return null;
  // Buang tanda baca penutup yang menempel di akhir URL.
  return m.group(0)!.replaceAll(RegExp(r'[)\]}>,.;]+$'), '');
}

Map<String, String> convertPayload(String url) => {'url': url};
