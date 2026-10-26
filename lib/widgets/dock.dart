import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme.dart';

/// v1.2.0: floating bottom navigation as 6 EQUAL flex tabs.
///
/// v1.1.9 regression fix (user's phone screenshot, 2026-10-26):
/// after the centre + FAB was removed, the dock became ONE
/// horizontally scrollable row of 6 tabs totalling 428dp, but a
/// phone viewport is only ~328dp wide (360dp screen minus the
/// 32dp dock margins). On a real phone Reports was half-clipped
/// at the right edge and Profile was completely off-screen, with
/// no visible hint that the row scrolled — and scroll-to-selected
/// did not help on the Home tab, where the row sits at offset 0.
/// Scrolling is therefore GONE: all 6 tabs share the dock width
/// equally and are fully visible at once, on 360dp and on 320dp
/// screens. No SingleChildScrollView, no scroll controller, no
/// + button, no fan.
///
/// The "Password Manager" label stays in FULL (user's explicit
/// v1.1.7 order — never abbreviated to "Vault"): it renders on
/// two tight lines ("Password" / "Manager", height 1.15) with a
/// slightly smaller icon pill, so it fits the 68dp dock height
/// without the v1.1.7-era 18px overflow (that overflow came from
/// the old default line height). Each tab is >=48dp wide even at
/// 320dp, so every tab stays clearly tappable.
///
/// Tab order: 0 Home, 1 History, 2 Password Manager, 3 Diary,
/// 4 Reports, 5 Profile.
class FloatingDock extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTab;

  const FloatingDock({
    super.key,
    required this.currentIndex,
    required this.onTab,
  });

  @override
  Widget build(BuildContext context) {
    // v1.2.0 bottom-pinning fix: MainShell places this widget in
    // a Positioned.fill, which hands it FULL-SCREEN tight
    // constraints. A bare ClipRRect under tight constraints fills
    // the screen, so the BackdropFilter blurred the whole screen
    // and the tab Row (centred vertically) landed mid-screen —
    // the user's "poori screen pe centre me" screenshot. Align
    // hands the bar LOOSE constraints and pins it to the bottom,
    // so the blur is confined to the 68dp bar itself no matter
    // where the dock is placed.
    return Align(
      alignment: Alignment.bottomCenter,
      child: ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          height: 68,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.hairline),
            boxShadow: AppShadows.raised,
          ),
          child: Row(
            children: [
              for (final t in _allTabs) Expanded(child: _tab(t)),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _tab(_DockTab tab) {
    final selected = currentIndex == tab.index;
    final twoLine = tab.label.contains('\n');
    return GestureDetector(
      onTap: () => onTab(tab.index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 26,
            decoration: BoxDecoration(
              color: selected ? AppColors.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Icon(
              selected ? tab.iconFilled : tab.icon,
              size: 22,
              color: selected ? AppColors.canvas : AppColors.inkTertiary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            tab.label,
            textAlign: TextAlign.center,
            maxLines: twoLine ? 2 : 1,
            style: AppText.caption.copyWith(
              fontSize: 10,
              height: twoLine ? 1.15 : null,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.accent : AppColors.inkTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DockTab {
  final int index;
  final IconData icon;
  final IconData iconFilled;
  final String label;
  const _DockTab(this.index, this.icon, this.iconFilled, this.label);
}

const _allTabs = [
  _DockTab(0, Icons.home_outlined, Icons.home, 'Home'),
  _DockTab(1, Icons.receipt_long_outlined, Icons.receipt_long, 'History'),
  // Full label, two lines — never abbreviated (user's v1.1.7 order).
  _DockTab(2, Icons.lock_outlined, Icons.lock, 'Password\nManager'),
  _DockTab(3, Icons.book_outlined, Icons.book, 'Diary'),
  _DockTab(4, Icons.bar_chart_outlined, Icons.bar_chart, 'Reports'),
  _DockTab(5, Icons.person_outline, Icons.person, 'Profile'),
];
