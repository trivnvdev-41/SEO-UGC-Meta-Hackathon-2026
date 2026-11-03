// Shell standar SABA (dari saba-handoff): header 64, kartu, tombol, ikon SVG.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'saba_theme.dart';

/// Header standar semua layar: h=64, bg putih, border bawah, judul tengah.
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

/// Kartu standar: putih, radius 12, border #EBEBEB.
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

/// Tombol primer: h=44, pill, biru.
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

/// Ikon SVG handoff (check, check-lg, play, search).
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

/// Stepper 3 langkah upload ala mockup: 1 Sumber • 2 Frame • 3 Sukses.
class SabaStepper extends StatelessWidget {
  const SabaStepper({super.key, required this.current});

  final int current; // 1..3

  @override
  Widget build(BuildContext context) {
    const labels = ['Sumber', 'Frame', 'Sukses'];
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
