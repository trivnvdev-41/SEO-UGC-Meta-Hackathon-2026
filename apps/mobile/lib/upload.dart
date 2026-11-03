// Upload video langsung ke server: galeri -> POST /v1/uploads -> jobId.
// Null = pengguna batal memilih. Tanpa dependency tambahan selain image_picker.
import 'dart:convert';
import 'dart:io';

import 'package:image_picker/image_picker.dart';

/// Status job untuk Inbox ala mockup (selesai / progres / gagal).
class JobRecord {
  JobRecord({required this.id, required this.label}) : at = DateTime.now();

  final String id;
  final String label;
  String status = 'converting'; // converting | done | failed
  double pct = 0;
  String? error;
  DateTime at;
}

/// Riwayat upload sesi ini (in-memory, pola VoteStore).
class JobHistory {
  static final List<JobRecord> records = [];

  static JobRecord add(String id, String label) {
    final r = JobRecord(id: id, label: label);
    records.insert(0, r);
    return r;
  }

  static void progress(String id, double pct) {
    for (final r in records) {
      if (r.id == id) r.pct = pct;
    }
  }

  static void done(String id) {
    for (final r in records) {
      if (r.id == id) {
        r
          ..status = 'done'
          ..pct = 1
          ..at = DateTime.now();
      }
    }
  }

  static void fail(String id, String error) {
    for (final r in records) {
      if (r.id == id) {
        r
          ..status = 'failed'
          ..error = error
          ..at = DateTime.now();
      }
    }
  }
}

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
