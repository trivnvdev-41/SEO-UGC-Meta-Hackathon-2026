// Markdown minimal cerminan renderMd web: heading, list, quote, bold, link.
// parseMd murni (bisa unit-test); mdBlocks membangun widget-nya.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

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

List<MdSpan> parseInline(String text) {
  final out = <MdSpan>[];
  var last = 0;
  for (final m in _inlineRe.allMatches(text)) {
    if (m.start > last) out.add(MdSpan(text.substring(last, m.start)));
    if (m[1] != null) {
      out.add(MdSpan(m[1]!, bold: true));
    } else {
      out.add(MdSpan(m[2]!, link: m[3]));
    }
    last = m.end;
  }
  if (last < text.length) out.add(MdSpan(text.substring(last)));
  return out;
}

List<MdBlock> parseMd(String md) {
  final blocks = <MdBlock>[];
  for (final block in md.split('\n\n')) {
    final lines = block.split('\n');
    final heading = RegExp(r'^(#{1,3}) (.*)$').firstMatch(block);
    if (heading != null) {
      blocks.add(MdHeading(
          heading[1]!.length >= 3 ? 3 : 2, heading[2]!));
      continue;
    }
    if (lines.every((l) => l.startsWith('- ') || l.startsWith('* '))) {
      blocks.add(MdBullets([for (final l in lines) l.substring(2)]));
      continue;
    }
    if (lines.every(_orderedRe.hasMatch)) {
      blocks.add(MdOrdered(
          [for (final l in lines) l.replaceFirst(_orderedRe, '')]));
      continue;
    }
    if (lines.every((l) => l.startsWith('> '))) {
      blocks.add(MdQuote(
          [for (final l in lines) l.substring(2)].join('\n')));
      continue;
    }
    blocks.add(MdPara(block));
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
          MdQuote(text: final t) => Container(
              decoration: BoxDecoration(
                border: Border(
                    left: BorderSide(
                        color: theme.colorScheme.primary, width: 4)),
              ),
              padding: const EdgeInsets.only(left: 12),
              child: Text.rich(
                rich(t),
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
          MdPara(text: final t) => Text.rich(
              rich(t), style: const TextStyle(height: 1.5)),
        },
      ),
  ];
}
