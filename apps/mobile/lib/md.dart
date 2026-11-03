// Markdown minimal cerminan renderMd web: heading, list, quote, bold, link.
// parseMd murni (bisa unit-test); mdBlocks membangun widget-nya.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'saba_theme.dart';

sealed class MdBlock {
  const MdBlock();
}

class MdHeading extends MdBlock {
  const MdHeading(this.level, this.text);
  final int level;
  final String text;
}

class MdBullets extends MdBlock {
  const MdBullets(this.items);
  final List<String> items;
}

class MdOrdered extends MdBlock {
  const MdOrdered(this.items);
  final List<String> items;
}

class MdQuote extends MdBlock {
  const MdQuote(this.text);
  final String text;
}

class MdTableBlock extends MdBlock {
  const MdTableBlock(this.head, this.rows);
  final List<String> head;
  final List<List<String>> rows;
}

class MdPara extends MdBlock {
  const MdPara(this.text);
  final String text;
}

class MdSpan {
  const MdSpan(this.text, {this.bold = false, this.link});
  final String text;
  final bool bold;
  final String? link;
}

final _inlineRe = RegExp(r'\*\*(.+?)\*\*|\[([^\]]+)\]\((https?://[^)\s]+)\)');
final _orderedRe = RegExp(r'^\d+\. ');
final _headingRe = RegExp(r'^(#{1,4})\s+(.*)$|^(#{2,})([^#\s].*)$');
final _hrRe = RegExp(r'^\s*([-*_=])(\s*\1){1,}\s*$');

/// Em dash tulisan tangan (` -- `) jadi — yang benar. URL tak tersentuh.
String emDash(String s) => s.replaceAllMapped(
    RegExp(r'(\s)--(\s)'), (m) => '${m[1]}—${m[2]}');

List<MdSpan> parseInline(String text) {
  final out = <MdSpan>[];
  var last = 0;
  for (final m in _inlineRe.allMatches(text)) {
    if (m.start > last) out.add(MdSpan(emDash(text.substring(last, m.start))));
    if (m[1] != null) {
      out.add(MdSpan(emDash(m[1]!), bold: true));
    } else {
      out.add(MdSpan(m[2]!, link: m[3]));
    }
    last = m.end;
  }
  if (last < text.length) out.add(MdSpan(emDash(text.substring(last))));
  return out;
}

List<String> _cells(String l) => l
    .trim()
    .replaceAll(RegExp(r'^\||\|$'), '')
    .split('|')
    .map((c) => c.trim())
    .toList();

bool _isDelim(String l) {
  final t = l.trim();
  return t.contains('|') && t.contains('-') && RegExp(r'^[\s:|\-]+$').hasMatch(t);
}

/// Parser tahan banting: heading tanpa baris kosong tetap heading,
/// garis pemisah (--, ---) dibuang, tabel tanpa pipe tepi tetap tabel.
List<MdBlock> parseMd(String md) {
  final lines = md.split('\n');
  final blocks = <MdBlock>[];
  var i = 0;
  bool bullet(String l) => l.startsWith('- ') || l.startsWith('* ');

  while (i < lines.length) {
    final line = lines[i];
    // Lewati baris kosong dan garis pemisah (---, --, ***, ===).
    if (line.trim().isEmpty || _hrRe.hasMatch(line)) {
      i++;
      continue;
    }
    final hm = _headingRe.firstMatch(line);
    if (hm != null) {
      final hashes = hm[1] ?? hm[3]!;
      final text = (hm[2] ?? hm[4] ?? '').trim();
      blocks.add(MdHeading(hashes.length >= 3 ? 3 : 2, text));
      i++;
      continue;
    }
    // Tabel: baris berisi | + baris delimiter dalam 2 baris berikut.
    if (line.contains('|')) {
      var di = -1;
      for (var k = 1; k <= 2 && i + k < lines.length; k++) {
        if (_isDelim(lines[i + k])) {
          di = k;
          break;
        }
      }
      if (di >= 0 && _cells(line).length > 1) {
        final head = _cells(line);
        final rows = <List<String>>[];
        var j = i + di + 1;
        while (j < lines.length &&
            lines[j].contains('|') &&
            !_isDelim(lines[j])) {
          rows.add(_cells(lines[j]));
          j++;
        }
        blocks.add(MdTableBlock(head, rows));
        i = j;
        continue;
      }
    }
    if (bullet(line)) {
      final items = <String>[];
      while (i < lines.length && bullet(lines[i])) {
        items.add(lines[i].substring(2));
        i++;
      }
      blocks.add(MdBullets(items));
      continue;
    }
    if (_orderedRe.hasMatch(line)) {
      final items = <String>[];
      while (i < lines.length && _orderedRe.hasMatch(lines[i])) {
        items.add(lines[i].replaceFirst(_orderedRe, ''));
        i++;
      }
      blocks.add(MdOrdered(items));
      continue;
    }
    if (line.startsWith('> ')) {
      final quotes = <String>[];
      while (i < lines.length && lines[i].startsWith('> ')) {
        quotes.add(lines[i].substring(2));
        i++;
      }
      blocks.add(MdQuote(quotes.join('\n')));
      continue;
    }
    // Paragraf: gabung baris biasa berurutan.
    final para = <String>[];
    while (i < lines.length &&
        lines[i].trim().isNotEmpty &&
        !_hrRe.hasMatch(lines[i]) &&
        _headingRe.firstMatch(lines[i]) == null &&
        !lines[i].contains('|') &&
        !bullet(lines[i]) &&
        !_orderedRe.hasMatch(lines[i]) &&
        !lines[i].startsWith('> ')) {
      para.add(lines[i]);
      i++;
    }
    if (para.isNotEmpty) {
      blocks.add(MdPara(para.join('\n')));
      continue;
    }
    // Pengaman: baris pipa yatim dirender sebagai teks tanpa karakter |.
    blocks.add(MdPara(
        lines[i].replaceAll('|', ' ').replaceAll(RegExp(r'\s+'), ' ').trim()));
    i++;
  }
  return blocks;
}

List<Widget> mdBlocks(BuildContext context, String md,
    {void Function(String url)? onLink}) {
  final theme = Theme.of(context);
  InlineSpan rich(String text) => TextSpan(
        children: [
          for (final s in parseInline(text))
            TextSpan(
              text: s.text,
              style: s.bold
                  ? const TextStyle(fontWeight: FontWeight.bold)
                  : null,
              recognizer: s.link != null && onLink != null
                  ? (TapGestureRecognizer()
                    ..onTap = () => onLink(s.link!))
                  : null,
            ),
        ],
      );
  return [
    for (final b in parseMd(md))
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: switch (b) {
          MdHeading(level: 3, text: final t) => Text(t,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          MdHeading(text: final t) => Text(t,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          MdBullets(items: final items) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final it in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  '),
                        Expanded(child: Text.rich(rich(it))),
                      ],
                    ),
                  ),
              ],
            ),
          MdOrdered(items: final items) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < items.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${i + 1}.  '),
                        Expanded(child: Text.rich(rich(items[i]))),
                      ],
                    ),
                  ),
              ],
            ),
          // Quote tanpa garis vertikal: kartu lembut, bukan border kiri.
          MdQuote(text: final t) => Container(
              decoration: BoxDecoration(
                color: SabaColors.greyFill,
                borderRadius:
                    BorderRadius.circular(SabaRadius.card),
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              child: Text.rich(
                rich(t),
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
          MdTableBlock(head: final head, rows: final rows) =>
              Container(
            decoration: BoxDecoration(
              border: Border.all(color: SabaColors.borderSoft),
              borderRadius:
                  BorderRadius.circular(SabaRadius.card),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: SabaColors.greyFill,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      for (var j = 0; j < head.length; j++)
                        Expanded(
                          child: Text.rich(
                            rich(head[j]),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
                for (var r = 0; r < rows.length; r++)
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(
                          top: BorderSide(
                              color: SabaColors.borderSoft)),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        for (var j = 0; j < rows[r].length; j++)
                          Expanded(
                            child: Text.rich(rich(rows[r][j])),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          MdPara(text: final t) => Text.rich(
              rich(t), style: SabaTextStyles.articleBody),
        },
      ),
  ];
}
