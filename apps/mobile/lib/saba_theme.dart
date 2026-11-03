import 'package:flutter/material.dart';

/// SABA design tokens — diekstrak dari mockup FigCraft (14 layar, terverifikasi).
/// Font: daftarkan Inter + Merriweather di pubspec.yaml (keduanya OFL).
/// Angka Insight: pakai fontFeature tabular (lihat [SabaTextStyles]).
abstract final class SabaColors {
  static const primary = Color(0xFF0866FF);
  static const primaryDark = Color(0xFF0050CD);
  static const onPrimary = Colors.white;

  static const bgWarm = Color(0xFFFCF8F8); // profil, settings, upload, login
  static const bgCool = Color(0xFFF4F6F9); // feed, inbox, jelajah
  static const card = Colors.white;

  static const borderCard = Color(0xFFEBEBEB);
  static const borderHeader = Color(0xFFF1EDEC);
  static const borderSoft = Color(0xFFE5E8EC);

  static const ink = Color(0xFF121212);
  static const ink2 = Color(0xFF1C1B1B);
  static const body = Color(0xFF424656);
  static const muted = Color(0xFF8590A6);
  static const muted2 = Color(0xFF727687);

  static const okBg = Color(0xFFEFF6FF);
  static const failBg = Color(0xFFFDE8E8);
  static const fail = Color(0xFFE11D48);
  static const successGreenBg = Color(0xFFECFDF5);
  static const successGreen = Color(0xFF10B981);
  static const successLineGreen = Color(0xFF16A34A);
  static const star = Color(0xFFF59E0B);

  static const chipBlueBg = Color(0xFFE7F3FF);
  static const chipPurpleBg = Color(0xFFFAF5FF);
  static const chipPurple = Color(0xFFA855F7);

  static const greyFill = Color(0xFFF0F2F5);
  static const track = Color(0xFFE9EDF2);
}

abstract final class SabaRadius {
  static const card = 12.0;
  static const pill = 9999.0;
  static const img = 8.0;
}

abstract final class SabaSpacing {
  static const screen = 12.0; // 16.0 untuk konten padat
  static const cardPad = 14.0;
  static const gapCard = 12.0;
  static const headerH = 64.0;
  static const btnH = 44.0;
}

abstract final class SabaTextStyles {
  static const ui = TextStyle(fontFamily: 'Inter');
  static const body = TextStyle(fontFamily: 'Merriweather', color: SabaColors.body);

  static const headerTitle = TextStyle(
    fontFamily: 'Inter', fontSize: 17, color: Colors.black,
  );
  static const cardTitle = TextStyle(
    fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold,
    color: SabaColors.ink,
  );
  static const sectionTitle = TextStyle(
    fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.w600,
    color: SabaColors.ink,
  );
  static const articleBody = TextStyle(
    fontFamily: 'Merriweather', fontSize: 16, height: 26 / 16,
    color: SabaColors.body,
  );
  static const excerpt = TextStyle(
    fontFamily: 'Merriweather', fontSize: 12, height: 19.5 / 12,
    color: Color(0xFF444444),
  );
  static const button = TextStyle(
    fontFamily: 'Inter', fontSize: 14, color: Colors.white,
  );
  static const badge = TextStyle(fontFamily: 'Inter', fontSize: 12);
  static const meta = TextStyle(
    fontFamily: 'Inter', fontSize: 11, color: SabaColors.muted,
  );

  /// Angka tabular ala Insight (Views 2.264 / Viewers 1.702).
  static const tabularNumber = TextStyle(
    fontFamily: 'Inter',
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

ThemeData sabaTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: SabaColors.primary,
    surface: SabaColors.card,
  ).copyWith(primary: SabaColors.primary);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: SabaColors.bgCool,
    fontFamily: 'Inter',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      toolbarHeight: SabaSpacing.headerH,
      centerTitle: true,
      titleTextStyle: SabaTextStyles.headerTitle,
      shape: Border(
        bottom: BorderSide(color: SabaColors.borderHeader, width: 1),
      ),
    ),
    cardTheme: CardThemeData(
      color: SabaColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SabaRadius.card),
        side: const BorderSide(color: SabaColors.borderCard),
      ),
      elevation: 1,
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: SabaColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(SabaSpacing.btnH),
        shape: const StadiumBorder(),
        textStyle: SabaTextStyles.button,
      ),
    ),
  );
}
