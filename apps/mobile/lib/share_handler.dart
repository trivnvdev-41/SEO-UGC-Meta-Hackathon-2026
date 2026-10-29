// Share handler: ekstrak URL pertama dari teks Share Sheet,
// lalu dikirim sebagai {url} ke POST /v1/convert.
final _urlRe = RegExp(r'https?://\S+');

String? extractSharedUrl(String? text) {
  if (text == null) return null;
  final m = _urlRe.firstMatch(text);
  return m?.group(0);
}

Map<String, String> convertPayload(String url) => {'url': url};
