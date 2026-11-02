// Upload video langsung ke server: galeri -> POST /v1/uploads -> jobId.
// Null = pengguna batal memilih. Tanpa dependency tambahan selain image_picker.
import 'dart:convert';
import 'dart:io';

import 'package:image_picker/image_picker.dart';

/// Pilih video dari galeri lalu streaming ke `POST /v1/uploads`.
/// onProgress: 0..1 selama kirim. Lempar bila gagal; null bila batal.
Future<String?> uploadVideo({
  required String apiBase,
  String? creator,
  void Function(double)? onProgress,
}) async {
  final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
  if (picked == null) return null;
  final file = File(picked.path);
  final len = await file.length();
  if (len == 0) throw Exception('upload: file kosong');
  final client = HttpClient();
  try {
    final req = await client
        .postUrl(Uri.parse('$apiBase/v1/uploads'))
        .timeout(const Duration(seconds: 20));
    req.headers.contentType = ContentType('video', 'mp4');
    if (creator != null && creator.isNotEmpty) {
      req.headers.set('x-creator', creator);
    }
    req.contentLength = len;
    var sent = 0;
    await for (final chunk in file.openRead()) {
      req.add(chunk);
      sent += chunk.length;
      onProgress?.call(sent / len);
    }
    final res = await req.close().timeout(const Duration(seconds: 30));
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode != 202) {
      throw Exception('upload ${res.statusCode}: $body');
    }
    final jobId =
        (jsonDecode(body) as Map<String, dynamic>)['jobId'] as String?;
    if (jobId == null || jobId.isEmpty) {
      throw Exception('upload: empty jobId');
    }
    return jobId;
  } finally {
    client.close();
  }
}
