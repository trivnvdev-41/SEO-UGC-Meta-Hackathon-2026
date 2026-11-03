// Token SABA = handoff: warna primer, bg warm/cool, radius, spacing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saba/saba_theme.dart';

void main() {
  test('primer + bg warm/cool sesuai handoff', () {
    expect(SabaColors.primary, const Color(0xFF0866FF));
    expect(SabaColors.bgWarm, const Color(0xFFFCF8F8));
    expect(SabaColors.bgCool, const Color(0xFFF4F6F9));
    expect(SabaColors.fail, const Color(0xFFE11D48));
  });

  test('radius + spacing sesuai handoff', () {
    expect(SabaRadius.card, 12.0);
    expect(SabaRadius.pill, 9999.0);
    expect(SabaSpacing.headerH, 64.0);
    expect(SabaSpacing.btnH, 44.0);
  });

  test('sabaTheme pakai primary + bgCool', () {
    final t = sabaTheme();
    expect(t.colorScheme.primary, SabaColors.primary);
    expect(t.scaffoldBackgroundColor, SabaColors.bgCool);
    expect(t.appBarTheme.toolbarHeight, SabaSpacing.headerH);
  });
}
