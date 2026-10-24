import 'package:flutter/material.dart';

/// Design tokens — Direction B "Mint Light Premium" (master spec §2).
/// Single source of truth for colour, type, radius, spacing and shadows.
class AppColors {
  static const canvas = Color(0xFFF1F7EE);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceInset = Color(0xFFEDF5E9);
  static const hairline = Color(0xFFDFEDD8);
  static const hairlineDark = Color(0xFFCBDFC2);
  static const brand = Color(0xFF0E9F5A);
  static const brandDeep = Color(0xFF076B3A);
  static const brandDark = Color(0xFF043D21);
  static const mint = Color(0xFF7FE3A8);
  static const mintTint = Color(0xFFDFF7E8);
  static const ink = Color(0xFF10241A);
  static const inkSecondary = Color(0xFF5A6E61);
  static const inkTertiary = Color(0xFF93A698);
  static const expense = Color(0xFFE5484D);
  static const expenseTint = Color(0xFFFDECEC);
  static const expenseChart = Color(0xFFF0908F);
  static const warning = Color(0xFFE8930C);
  static const warningTint = Color(0xFFFDF3E0);
  static const warningText = Color(0xFF7A5410);
  static const info = Color(0xFF2F7DE1);
  static const switchOff = Color(0xFFD8E8D2);
  static const overBarLight = Color(0xFFFFB3B5);
  static const overTextLight = Color(0xFFFFD9DA);
  static const scrim = Color(0x7310241A); // ink at 45%

  /// The one gradient in the app: hero cards, onboarding CTA, FAB,
  /// primary CTAs (master §2.2 discipline — nowhere else).
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF12B76A), Color(0xFF076B3A), Color(0xFF043D21)],
    stops: [0.0, 0.55, 1.0],
  );
}

class AppRadius {
  static const xs = 10.0;
  static const sm = 14.0;
  static const md = 18.0;
  static const lg = 24.0;
  static const xl = 28.0;
  static const pill = 999.0;
}

class AppShadows {
  static const card = [
    BoxShadow(color: Color(0x0F0B3D24), blurRadius: 18, offset: Offset(0, 6)),
  ];
  static const raised = [
    BoxShadow(color: Color(0x1A0B3D24), blurRadius: 24, offset: Offset(0, 10)),
  ];
  static const hero = [
    BoxShadow(color: Color(0x47043D21), blurRadius: 28, offset: Offset(0, 14)),
  ];
  static const fab = [
    BoxShadow(color: Color(0x59076B3A), blurRadius: 16, offset: Offset(0, 8)),
  ];
}

/// Typography — Plus Jakarta Sans only (master §2.3). Amounts always carry
/// tabular figures so digit columns never jitter.

/// The single font family for the whole app (bundled Plus Jakarta Sans).
TextStyle _j({
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
  double? height,
  double? letterSpacing,
}) =>
    TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );

class AppText {
  static TextStyle _s(double size, FontWeight w,
      {double? height, double? spacing, Color? color}) {
    return _j(
      fontSize: size,
      fontWeight: w,
      height: height,
      letterSpacing: spacing,
      color: color ?? AppColors.ink,
    );
  }

  static TextStyle get displayBalance =>
      _s(40, FontWeight.w800, height: 44 / 40, spacing: -0.5)
          .copyWith(fontFeatures: _tab);
  static TextStyle get displayBalanceLite =>
      _s(32, FontWeight.w800, height: 36 / 32, spacing: -0.5)
          .copyWith(fontFeatures: _tab);
  static TextStyle get amountXL =>
      _s(34, FontWeight.w800, height: 38 / 34, spacing: -0.5)
          .copyWith(fontFeatures: _tab);
  static TextStyle get h1 =>
      _s(24, FontWeight.w800, height: 30 / 24, spacing: -0.3);
  static TextStyle get headline =>
      _s(26, FontWeight.w800, height: 32 / 26, spacing: -0.3);
  static TextStyle get h2 =>
      _s(17, FontWeight.w700, height: 22 / 17, spacing: -0.2);
  static TextStyle get title =>
      _s(15, FontWeight.w700, height: 20 / 15);
  static TextStyle get body => _s(15, FontWeight.w500, height: 21 / 15);
  static TextStyle get bodyStrong => _s(15, FontWeight.w600, height: 21 / 15);
  static TextStyle get label =>
      _s(13, FontWeight.w600, height: 17 / 13, spacing: 0.1);
  static TextStyle get caption =>
      _s(12, FontWeight.w500, height: 16 / 12, spacing: 0.1);
  static TextStyle get amountRow =>
      _s(16, FontWeight.w700, height: 20 / 16).copyWith(fontFeatures: _tab);
  static TextStyle get micro =>
      _s(11, FontWeight.w600, height: 14 / 11, spacing: 0.4);

  static const _tab = [FontFeature.tabularFigures()];

  static TextStyle tab(TextStyle s) => s.copyWith(fontFeatures: _tab);
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.canvas,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      surface: AppColors.surface,
    ),
    fontFamily: _j().fontFamily,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: 'Plus Jakarta Sans'),
    splashFactory: InkRipple.splashFactory,
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : Colors.white),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? AppColors.brand
              : AppColors.switchOff),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
  );
}

/// The decorated white-card shell used across the app (master §3.2):
/// surface fill, 1dp hairline border, green-tinted shadow, elevation 0.
BoxDecoration cardDecoration({double radius = AppRadius.lg}) {
  return BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.hairline),
    boxShadow: AppShadows.card,
  );
}

BoxDecoration insetDecoration({double radius = AppRadius.md}) {
  return BoxDecoration(
    color: AppColors.surfaceInset,
    borderRadius: BorderRadius.circular(radius),
  );
}
