import 'package:flutter/material.dart';

/// Design tokens — v1.1 "Liquid Glass" (Dribbble crypto-wallet language,
/// Shahid Finance content only: PKR, no crypto assets, no copied copy).
/// Base: near-black purple #0F0B16, deep purple #30244B, muted
/// grey-purple #575361, light grey #A4A2AD, off-white #F2F2F4.
/// Accent: lime/chartreuse #C6D549 for active states and key highlights.
/// Dark burgundy #552329 + warm orange/pink/violet glows bleed in from
/// the edges behind the glass. Buttons are pill-shaped: white primary,
/// lime active accent, dark glass circles for secondary actions.
class AppColors {
  static const canvas = Color(0xFF0F0B16);
  static const deepPurple = Color(0xFF30244B);
  static const burgundy = Color(0xFF552329);
  static const mutedPurple = Color(0xFF575361);
  static const lightGrey = Color(0xFFA4A2AD);
  static const offWhite = Color(0xFFF2F2F4);
  static const lime = Color(0xFFC6D549);

  // Legacy token names, remapped onto the dark palette so every existing
  // screen adopts the theme without a feature change.
  static const surface = Color(0x1AFFFFFF); // white ~10% (glass fill)
  static const surfaceInset = Color(0x14FFFFFF); // white ~8% (dark rows)
  static const hairline = Color(0x2EFFFFFF); // white ~18%
  static const hairlineDark = Color(0x40FFFFFF); // white ~25%
  static const brand = lime;
  static const brandDeep = lime;
  static const brandDark = canvas;
  static const mint = lime;
  static const mintTint = Color(0x26C6D549); // lime ~15%
  static const ink = offWhite;
  static const inkSecondary = lightGrey;
  static const inkTertiary = Color(0xFF8B8796);
  static const expense = Color(0xFFFF6B6B); // readable red on dark
  static const expenseTint = Color(0x1FFF6B6B);
  static const expenseChart = Color(0xFFFF8A8A);
  static const warning = Color(0xFFFFB25E);
  static const warningTint = Color(0x1FFFB25E);
  static const warningText = Color(0xFFFFD9A8);
  static const info = Color(0xFFA78BFA);
  static const switchOff = mutedPurple;
  static const overBarLight = Color(0xFFFF8A8A);
  static const overTextLight = Color(0xFFFFD9DA);
  static const scrim = Color(0x730F0B16);

  /// Gradient mesh for hero cards: deep purple → burgundy → near-black.
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF30244B), Color(0xFF552329), Color(0xFF0F0B16)],
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
    BoxShadow(color: Color(0x40000000), blurRadius: 18, offset: Offset(0, 6)),
  ];
  static const raised = [
    BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 10)),
  ];
  static const hero = [
    BoxShadow(color: Color(0x66000000), blurRadius: 28, offset: Offset(0, 14)),
  ];
  static const fab = [
    BoxShadow(color: Color(0x8030244B), blurRadius: 16, offset: Offset(0, 8)),
  ];
}

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
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.canvas,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.lime,
      surface: AppColors.deepPurple,
      onSurface: AppColors.offWhite,
    ),
    fontFamily: _j().fontFamily,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: 'Plus Jakarta Sans'),
    splashFactory: InkRipple.splashFactory,
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? AppColors.canvas
              : AppColors.offWhite),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? AppColors.lime
              : AppColors.switchOff),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
  );
}

/// Frosted liquid-glass card decoration: translucent white fill, thin
/// light border, soft shadow. True blur comes from wrapping widgets
/// (GroupCard / HeroCard / GlassScaffold) in a BackdropFilter.
BoxDecoration cardDecoration({double radius = AppRadius.lg}) {
  return BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.hairline),
    boxShadow: AppShadows.card,
  );
}

BoxDecoration glassDecoration({double radius = AppRadius.lg}) =>
    cardDecoration(radius: radius);

BoxDecoration insetDecoration({double radius = AppRadius.md}) {
  return BoxDecoration(
    color: AppColors.surfaceInset,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.hairline),
  );
}

/// Aurora backdrop: deep near-black purple canvas with soft gradient
/// blobs — violet top-right, burgundy left, warm orange/pink bottom —
/// bleeding in from the edges behind the glass.
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        children: [
          Container(color: AppColors.canvas),
          Positioned(
            top: -140,
            right: -90,
            child: Container(
              width: 360,
              height: 360,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  Color(0x807C5CFF),
                  Color(0x0030244B),
                ]),
              ),
            ),
          ),
          Positioned(
            top: 120,
            left: -130,
            child: Container(
              width: 320,
              height: 320,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  Color(0x66552329),
                  Color(0x00552329),
                ]),
              ),
            ),
          ),
          Positioned(
            bottom: -160,
            right: -60,
            child: Container(
              width: 340,
              height: 340,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  Color(0x4DFF8A5C),
                  Color(0x00FF8A5C),
                ]),
              ),
            ),
          ),
          Positioned(
            bottom: 180,
            left: -110,
            child: Container(
              width: 280,
              height: 280,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  Color(0x40FF6FA5),
                  Color(0x00FF6FA5),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Scaffold with the aurora backdrop + frosted blur behind its body.
/// Drop-in replacement for `Scaffold` on full screens (same `body`
/// parameter); the blur is applied to the backdrop, not the content.
class GlassScaffold extends StatelessWidget {
  final Widget? body;
  final Widget? floatingActionButton;
  const GlassScaffold({super.key, this.body, this.floatingActionButton});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      floatingActionButton: floatingActionButton,
      body: Stack(
        children: [
          const AuroraBackground(),
          body ?? const SizedBox.shrink(),
        ],
      ),
    );
  }
}
