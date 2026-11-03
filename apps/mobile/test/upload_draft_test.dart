// Pure client draft Langkah 2: parse + validasi lokal.
import 'package:flutter_test/flutter_test.dart';
import 'package:saba/upload_draft.dart';

Map<String, dynamic> draftJson({
  String transcript = 'halo dunia',
  double? confidence = 92.4,
  List<String> frames = const ['https://cdn.test/f0.jpg'],
  List<int> selected = const [0],
  String title = 'Judul',
}) {
  return {
    'jobId': 'job_1',
    'status': 'draft_ready',
    'draft': {
      'transcript': transcript,
      'confidence': confidence,
      'frames': frames,
      'selectedIndices': selected,
      'title': title,
      'creator': '@tes',
      'references': ['https://instagram.com/p/abc/'],
    },
  };
}

void main() {
  test('DraftData.fromJson memetakan semua field + saring url', () {
    final d = DraftData.fromJson(draftJson(
      frames: ['https://cdn.test/f0.jpg', 'http://jelek/x', 'bukan-url'],
    ));
    expect(d.transcript, 'halo dunia');
    expect(d.confidence, 92.4);
    expect(d.frames, ['https://cdn.test/f0.jpg']);
    expect(d.selectedIndices, [0]);
    expect(d.title, 'Judul');
    expect(d.references, ['https://instagram.com/p/abc/']);
  });

  test('confidenceLabel persen atau strip', () {
    expect(DraftData.fromJson(draftJson()).confidenceLabel, '92% pas');
    expect(DraftData.fromJson(draftJson(confidence: null)).confidenceLabel,
        '–');
  });

  test('draft kosong/null -> null', () {
    expect(DraftData.fromJson({'draft': null}).transcript, isEmpty);
  });

  test('parseRefInput pecah koma/baris, saring https, maks 3', () {
    expect(
        parseRefInput(
            'https://a.test/1, https://b.test/2\nhttps://c.test/3 https://d.test/4'),
        ['https://a.test/1', 'https://b.test/2', 'https://c.test/3']);
    expect(parseRefInput('http://x, teks'), isEmpty);
    expect(parseRefInput('  '), isEmpty);
  });
}
