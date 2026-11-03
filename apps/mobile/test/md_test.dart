import 'package:flutter_test/flutter_test.dart';
import 'package:saba/md.dart';

void main() {
  test('inline: bold dan link', () {
    final spans = parseInline('A **tebal** dan [situs](https://x.test/a)');
    expect(spans.map((s) => s.text), ['A ', 'tebal', ' dan ', 'situs']);
    expect(spans[1].bold, isTrue);
    expect(spans[3].link, 'https://x.test/a');
  });

  test('blok: heading, list, quote', () {
    final blocks = parseMd('## Judul\n\n- a\n- b\n\n> catatan');
    expect(blocks[0], isA<MdHeading>());
    expect((blocks[0] as MdHeading).level, 2);
    expect(blocks[1], isA<MdBullets>());
    expect(blocks[2], isA<MdQuote>());
    expect(parseMd('### Sub')[0], isA<MdHeading>());
    expect(parseMd('1. a\n2. b')[0], isA<MdOrdered>());
    expect(parseMd('* a\n* b')[0], isA<MdBullets>());
  });

  test('paragraf biasa dan teks mentah aman', () {
    final blocks = parseMd('<img src=x>');
    expect(blocks.single, isA<MdPara>());
    expect(parseInline('a*b').single.bold, isFalse);
  });

  test('heading tanpa baris kosong + tanpa spasi', () {
    final blocks = parseMd('### Kelebihan\nIsi langsung.');
    expect(blocks[0], isA<MdHeading>());
    expect(blocks[1], isA<MdPara>());
    expect(parseMd('##Sub')[0], isA<MdHeading>());
    expect(parseMd('#tagar')[0], isA<MdPara>());
  });

  test('garis pemisah dibuang', () {
    expect(parseMd('a\n\n---\n\nb').whereType<MdPara>().length, 2);
    expect(parseMd('a\n\n--\n\nb').length, 2);
  });

  test('tabel tanpa pipe tepi tetap tabel', () {
    final blocks = parseMd('A | B\n--- | ---\n1 | 2');
    expect(blocks.single, isA<MdTableBlock>());
    final t = blocks.single as MdTableBlock;
    expect(t.head, ['A', 'B']);
    expect(t.rows, [
      ['1', '2']
    ]);
  });

  test('em dash tulisan tangan jadi —', () {
    expect(parseInline('murah -- tapi').map((s) => s.text).join(), 'murah — tapi');
    expect(parseInline('[x](https://t.test/a--b)')[0].link, 'https://t.test/a--b');
  });
}

