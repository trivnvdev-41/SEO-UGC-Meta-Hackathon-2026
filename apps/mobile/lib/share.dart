// Web-style share to all socials: WA/X/FB/TG/copy bottom sheet.
// Opens links via the same openUrl MethodChannel (no new plugin).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'saba_theme.dart';

class ShareTarget {
  const ShareTarget(
      {required this.key, required this.label, required this.href});

  final String key;
  final String label;
  final String href;
}

/// Pure (tested): 5 share targets with encoded URL.
List<ShareTarget> buildShareLinks(String url, String title) {
  final u = Uri.encodeComponent(url);
  final t = Uri.encodeComponent(title);
  return [
    ShareTarget(
        key: 'wa', label: 'WhatsApp', href: 'https://wa.me/?text=$t%20$u'),
    ShareTarget(
        key: 'x',
        label: 'X',
        href: 'https://twitter.com/intent/tweet?text=$t&url=$u'),
    ShareTarget(
        key: 'fb',
        label: 'Facebook',
        href: 'https://www.facebook.com/sharer/sharer.php?u=$u'),
    ShareTarget(
        key: 'tg',
        label: 'Telegram',
        href: 'https://t.me/share/url?url=$u&text=$t'),
    ShareTarget(key: 'copy', label: 'Copy link', href: url),
  ];
}

Future<void> _openExternal(String url) async {
  const ch = MethodChannel('saba/share');
  try {
    await ch.invokeMethod('openUrl', url);
  } catch (_) {
    // Ignore: device has no registered browser.
  }
}

/// Bottom sheet share: WA/X/FB/TG open the browser, copy via clipboard.
Future<void> showShareSheet(BuildContext context,
    {required String url, required String title}) {
  final messenger = ScaffoldMessenger.of(context);
  return showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: SabaColors.borderSoft,
                    borderRadius:
                        BorderRadius.circular(SabaRadius.pill))),
          ),
          for (final t in buildShareLinks(url, title))
            GestureDetector(
              onTap: () async {
                Navigator.of(ctx).pop();
                if (t.key == 'copy') {
                  await Clipboard.setData(
                      ClipboardData(text: t.href));
                    messenger.showSnackBar(const SnackBar(
                        content: Text('Article link copied')));
                } else {
                  await _openExternal(t.href);
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Text(t.label,
                    style: const TextStyle(fontSize: 15)),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
