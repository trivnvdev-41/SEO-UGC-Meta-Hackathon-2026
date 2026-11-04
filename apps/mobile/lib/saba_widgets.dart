// Standard SABA shell (from saba-handoff): 64 header, card, buttons, SVG icons.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'saba_theme.dart';

/// 07b Upload Progress Transcript card: big % + staged status lines + bar.
/// Shared by every upload phase (bytes, transcript, publish) so they all
/// look the same. pct null = indeterminate (server phase, no measurable
/// progress yet).
class SabaStageCard extends StatelessWidget {
  const SabaStageCard({
    super.key,
    required this.pct,
    required this.line1,
    required this.line2,
    required this.line3,
    required this.footer,
  });

  /// 0..100, or null for indeterminate.
  final int? pct;
  final String line1;
  final String line2;
  final String line3;
  final String footer;

  @override
  Widget build(BuildContext context) {
    return SabaCard(
      child: Column(
        children: [
          Text(pct == null ? '…' : '$pct%',
              style: const TextStyle(
                  fontSize: 32, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(line1,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(line2,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(line3,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: SabaColors.primary)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(SabaRadius.pill),
            child: LinearProgressIndicator(
              value: pct == null ? null : pct! / 100,
              minHeight: 8,
              backgroundColor: SabaColors.greyFill,
              valueColor: const AlwaysStoppedAnimation<Color>(
                  SabaColors.primary),
            ),
          ),
          const SizedBox(height: 8),
          Text(footer,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

/// Standard header for all screens: h=64, white bg, bottom border, centered title.
class SabaHeader extends StatelessWidget implements PreferredSizeWidget {
  const SabaHeader({super.key, required this.title, this.actions});

  final String title;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(SabaSpacing.headerH);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title, style: SabaTextStyles.headerTitle),
      actions: actions,
    );
  }
}

/// Standard card: white, radius 12, #EBEBEB border.
class SabaCard extends StatelessWidget {
  const SabaCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(SabaSpacing.cardPad),
      decoration: BoxDecoration(
        color: SabaColors.card,
        borderRadius: BorderRadius.circular(SabaRadius.card),
        border: Border.all(color: SabaColors.borderCard),
        boxShadow: const [
          BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: child,
    );
  }
}

/// Primary button: h=44, pill, blue.
class SabaPrimaryButton extends StatelessWidget {
  const SabaPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: SabaSpacing.btnH,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: icon ?? const SizedBox.shrink(),
        label: Text(label),
      ),
    );
  }
}

/// Handoff SVG icons (check, check-lg, play, search).
class SabaIcons {
  static Widget check({double size = 56}) => SvgPicture.asset(
        'assets/icons/check.svg',
        width: size,
        height: size,
      );
  static Widget checkLg({double size = 96}) => SvgPicture.asset(
        'assets/icons/check-lg.svg',
        width: size,
        height: size,
      );
  static Widget play({double size = 56}) => SvgPicture.asset(
        'assets/icons/play.svg',
        width: size,
        height: size,
      );
  static Widget search({double size = 36}) => SvgPicture.asset(
        'assets/icons/search.svg',
        width: size,
        height: size,
      );
}

/// Mockup-style 3-step upload stepper: 1 Source • 2 Frame • 3 Done.
class SabaStepper extends StatelessWidget {
  const SabaStepper({super.key, required this.current});

  final int current; // 1..3

  @override
  Widget build(BuildContext context) {
    const labels = ['Source', 'Frame', 'Done'];
    return Row(
      children: [
        for (var i = 1; i <= 3; i++) ...[
          _dot(i, labels[i - 1]),
          if (i < 3)
            const Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Divider(color: SabaColors.borderSoft),
              ),
            ),
        ],
      ],
    );
  }

  Widget _dot(int i, String label) {
    final done = i < current;
    final active = i == current;
    final bg = done || active ? SabaColors.primary : SabaColors.greyFill;
    final fg = done || active ? Colors.white : SabaColors.muted2;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: done
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : Text('$i',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold, color: fg)),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
                color: active ? SabaColors.primary : SabaColors.muted2)),
      ],
    );
  }
}
