// Klien draft Langkah 2: ambil / PATCH / publish draft.
// Murni (tanpa widget) agar bisa di-unit-test.
import 'dart:convert';
import 'dart:io';

/// Draft dari GET /v1/drafts/:id (bentuk publik, tanpa bundle internal).
class DraftData {
  DraftData({
    required this.transcript,
    required this.confidence,
    required this.frames,
    required this.selectedIndices,
    required this.title,
    required this.creator,
    required this.references,
  });

  final String transcript;
  final double? confidence;
  final List<String> frames;
  final List<int> selectedIndices;
  final String title;
  final String creator;
  final List<String> references;

  /// Label keyakinan ala mockup ("92% pas"); '-' bila tak ada.
  String get confidenceLabel =>
      confidence == null ? '–' : '${confidence!.toStringAsFixed(0)}% pas';

  factory DraftData.fromJson(Map<String, dynamic> json) {
    final d = (json['draft'] as Map?) ?? const {};
    return DraftData(
      transcript: '${d['transcript'] ?? ''}',
      confidence: (d['confidence'] as num?)?.toDouble(),
      frames: [for (final u in (d['frames'] as List?) ?? const []) '$u']
          .where((u) => u.startsWith('https://'))
          .take(6)
          .toList(),
      selectedIndices: [
        for (final i in (d['selectedIndices'] as List?) ?? const [])
          if (i is int) i
      ],
      title: '${d['title'] ?? ''}',
      creator: '${d['creator'] ?? ''}',
      references: [for (final u in (d['references'] as List?) ?? const []) '$u']
          .where((u) => u.startsWith('https://'))
          .take(3)
          .toList(),
    );
  }
}

/// GET /v1/drafts/:id -> DraftData (null bila 404/belum siap).
Future<DraftData?> fetchDraft(String apiBase, String jobId) async {
  final client = HttpClient();
  try {
    final req = await client
        .getUrl(Uri.parse('$apiBase/v1/drafts/$jobId'))
        .timeout(const Duration(seconds: 20));
    final res = await req.close().timeout(const Duration(seconds: 20));
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode != 200) return null;
    return DraftData.fromJson(jsonDecode(body) as Map<String, dynamic>);
  } finally {
    client.close();
  }
}

/// PATCH /v1/drafts/:id -> true bila 200.
Future<bool> patchDraft(String apiBase, String jobId,
    {String? title,
    int? coverIndex,
    String? transcript,
    List<String>? references}) async {
  final client = HttpClient();
  try {
    final req = await client
        .openUrl('PATCH', Uri.parse('$apiBase/v1/drafts/$jobId'))
        .timeout(const Duration(seconds: 20));
    req.headers.contentType = ContentType.json;
    final payload = <String, dynamic>{};
    if (title != null) payload['title'] = title;
    if (coverIndex != null) payload['coverIndex'] = coverIndex;
    if (transcript != null) payload['transcript'] = transcript;
    if (references != null) payload['references'] = references;
    req.write(jsonEncode(payload));
    final res = await req.close().timeout(const Duration(seconds: 20));
    await res.transform(utf8.decoder).join();
    return res.statusCode == 200;
  } finally {
    client.close();
  }
}

/// POST /v1/drafts/:id/publish -> jobId artikel (null bila gagal).
Future<String?> publishDraft(String apiBase, String jobId,
    {String? title,
    int? coverIndex,
    String? transcript,
    List<String>? references,
    required bool edited}) async {
  final client = HttpClient();
  try {
    final req = await client
        .postUrl(Uri.parse('$apiBase/v1/drafts/$jobId/publish'))
        .timeout(const Duration(seconds: 20));
    req.headers.contentType = ContentType.json;
    final payload = <String, dynamic>{'edited': edited};
    if (title != null) payload['title'] = title;
    if (coverIndex != null) payload['coverIndex'] = coverIndex;
    if (transcript != null) payload['transcript'] = transcript;
    if (references != null) payload['references'] = references;
    req.write(jsonEncode(payload));
    final res = await req.close().timeout(const Duration(seconds: 30));
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode != 202) return null;
    final id = (jsonDecode(body) as Map<String, dynamic>)['jobId'];
    return id is String && id.isNotEmpty ? id : null;
  } finally {
    client.close();
  }
}

/// Poll draft sampai siap (maks ~10 menit). Null bila timeout/batal.
/// `alive` dipanggil tiap putaran; kembalikan false untuk berhenti.
Future<DraftData?> pollDraft(String apiBase, String jobId,
    {bool Function()? alive}) async {
  for (var i = 0; i < 120; i++) {
    if (alive != null && !alive()) return null;
    try {
      final d = await fetchDraft(apiBase, jobId);
      if (d != null) return d;
    } catch (_) {
      // Jaringan putus: coba lagi sampai batas poll.
    }
    await Future<void>.delayed(const Duration(seconds: 5));
  }
  return null;
}

/// Poll artikel sampai 200 (maks ~10 menit). False bila timeout/batal.
Future<bool> pollArticleDone(String apiBase, String jobId,
    {bool Function()? alive}) async {
  final client = HttpClient();
  try {
    for (var i = 0; i < 120; i++) {
      if (alive != null && !alive()) return false;
      try {
        final req = await client
            .getUrl(Uri.parse('$apiBase/v1/articles/$jobId'))
            .timeout(const Duration(seconds: 20));
        final res = await req.close().timeout(const Duration(seconds: 20));
        await res.transform(utf8.decoder).join();
        if (res.statusCode == 200) return true;
      } catch (_) {
        // Coba lagi.
      }
      await Future<void>.delayed(const Duration(seconds: 5));
    }
    return false;
  } finally {
    client.close();
  }
}

/// Pecah input link ref (koma/baris baru/spasi), saring https, maks 3.
List<String> parseRefInput(String raw) {
  final out = <String>[];
  for (final part in raw.split(RegExp(r'[\s,]+'))) {
    final u = part.trim();
    if (u.startsWith('https://') && !out.contains(u)) out.add(u);
    if (out.length >= 3) break;
  }
  return out;
}
