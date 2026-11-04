// Step 2 draft client: fetch / PATCH / publish a draft.
// Pure (no widgets) so it stays unit-testable.
import 'dart:convert';
import 'dart:io';

/// Draft from GET /v1/drafts/:id (public shape, no internal bundle).
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

  /// Mockup-style confidence label ("92% match"); '-' when missing.
  String get confidenceLabel =>
      confidence == null ? '–' : '${confidence!.toStringAsFixed(0)}% match';

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

/// GET /v1/drafts/:id -> DraftData (null on 404/not ready).
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

/// PATCH /v1/drafts/:id -> true on 200.
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

/// POST /v1/drafts/:id/publish -> article jobId (null on failure).
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

/// Map the two upload phases onto one continuous 0..90 bar:
/// real upload fills the first 20%, draft polling continues 20..90.
/// Never hits 100% early, so the bar can't claim completion prematurely.
int continuousPct({int? uploadPct, required int draftPct}) {
  if (uploadPct != null) return (uploadPct * 0.2).round().clamp(0, 20);
  return 20 + (draftPct * 70 ~/ 92).clamp(0, 70);
}

/// Poll a draft until ready (max ~10 min). Null on timeout/cancel.
/// `alive` is called each round; return false to stop.
Future<DraftData?> pollDraft(String apiBase, String jobId,
    {bool Function()? alive}) async {
  for (var i = 0; i < 120; i++) {
    if (alive != null && !alive()) return null;
    try {
      final d = await fetchDraft(apiBase, jobId);
      if (d != null) return d;
    } catch (_) {
      // Network dropped: retry until the poll limit.
    }
    await Future<void>.delayed(const Duration(seconds: 5));
  }
  return null;
}

/// Poll an article until 200 (max ~10 min). False on timeout/cancel.
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
        // Retry.
      }
      await Future<void>.delayed(const Duration(seconds: 5));
    }
    return false;
  } finally {
    client.close();
  }
}

/// Split ref link input (comma/newline/space), keep https, max 3.
List<String> parseRefInput(String raw) {
  final out = <String>[];
  for (final part in raw.split(RegExp(r'[\s,]+'))) {
    final u = part.trim();
    if (u.startsWith('https://') && !out.contains(u)) out.add(u);
    if (out.length >= 3) break;
  }
  return out;
}
