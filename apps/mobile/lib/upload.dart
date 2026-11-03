// Upload a video straight to the server: gallery -> POST /v1/uploads -> jobId.
// Null = user cancelled picking. No extra dependency besides image_picker.
import 'dart:convert';
import 'dart:io';

import 'package:image_picker/image_picker.dart';

/// Job status for the mockup-style Inbox (done / progress / failed).
class JobRecord {
  JobRecord({required this.id, required this.label}) : at = DateTime.now();

  final String id;
  final String label;
  String status = 'converting'; // converting | done | failed
  double pct = 0;
  String? error;
  DateTime at;
}

/// This session's upload history (in-memory, VoteStore pattern).
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

/// Pick a video from the gallery, then stream it to `POST /v1/uploads`.
/// references: extra social links (max 3, https) via the x-references header.
/// onProgress: 0..1 while sending. Throws on failure; null if cancelled.
Future<String?> uploadVideo({
  required String apiBase,
  String? creator,
  List<String> references = const [],
  void Function(double)? onProgress,
}) async {
  final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
  if (picked == null) return null;
  final file = File(picked.path);
  final len = await file.length();
  if (len == 0) throw Exception('upload: empty file');
  final client = HttpClient();
  try {
    final req = await client
        .postUrl(Uri.parse('$apiBase/v1/uploads'))
        .timeout(const Duration(seconds: 20));
    req.headers.contentType = ContentType('video', 'mp4');
    if (creator != null && creator.isNotEmpty) {
      req.headers.set('x-creator', creator);
    }
    if (references.isNotEmpty) {
      req.headers.set('x-references', jsonEncode(references));
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
