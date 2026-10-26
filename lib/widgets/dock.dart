import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme.dart';

/// v1.1.9: floating bottom navigation as a plain scrollable tab row.
///
/// The centre + (FAB) button and its Income/Expense fan were REMOVED
/// at the user's explicit order (2026-10-26): no income/expense
/// entry path is lost, because Home already has big Add Income /
/// Add Expense buttons (lib/screens/home.dart). The dock is now one
/// horizontally scrollable row of 6 tabs, so no tab can overlap
/// another — the v1.1.1 overlap bug cannot return. Selecting a tab
/// scrolls the row until the tab is fully visible
/// (scroll-to-selected).
///
/// Tab order: 0 Home, 1 History, 2 Password Manager, 3 Diary,
/// 4 Reports, 5 Profile.
class FloatingDock extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTab;

  const FloatingDock({
    super.key,
    required this.currentIndex,
    required this.onTab,
  });

  @override
  State<FloatingDock> createState() => _FloatingDockState();
}

/// Width of one dock tab item (fixed, so scrolling is predictable).
const double dockTabWidth = 64;

/// Pure scroll target: smallest offset that makes [itemIndex] fully
/// visible in a viewport of [viewportWidth], given [currentOffset]
/// and the per-tab [itemWidths]. Unit-tested; the widget only
/// animates to what this returns.
double dockScrollOffsetForItem({
  required int itemIndex,
  required List<double> itemWidths,
  required double viewportWidth,
  required double currentOffset,
}) {
  final totalWidth = itemWidths.fold(0.0, (a, w) => a + w);
  final maxOffset = (totalWidth - viewportWidth).clamp(0.0, totalWidth);
  final itemStart =
      itemWidths.sublist(0, itemIndex).fold(0.0, (a, w) => a + w);
  final itemEnd = itemStart + itemWidths[itemIndex];
  double target = currentOffset;
  if (itemStart < currentOffset) {
    target = itemStart;
  } else if (itemEnd > currentOffset + viewportWidth) {
    target = itemEnd - viewportWidth;
  }
  return target.clamp(0.0, maxOffset);
}

class _DockTab {
  final int index;
  final IconData icon;
  final IconData iconFilled;
  final String label;
  final double width;
  const _DockTab(this.index, this.icon, this.iconFilled, this.label,
      [this.width = dockTabWidth]);
}

const _allTabs = [
  _DockTab(0, Icons.home_outlined, Icons.home, 'Home'),
  _DockTab(1, Icons.receipt_long_outlined, Icons.receipt_long, 'History'),
  // Wider tab so the full "Password Manager" label fits on one line.
  _DockTab(2, Icons.lock_outlined, Icons.lock, 'Password Manager', 108),
  _DockTab(3, Icons.book_outlined, Icons.book, 'Diary'),
  _DockTab(4, Icons.bar_chart_outlined, Icons.bar_chart, 'Reports'),
  _DockTab(5, Icons.person_outline, Icons.person, 'Profile'),
];

class _FloatingDockState extends State<FloatingDock> {
  final _controller = ScrollController();
  double _viewport = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrent(animate: false);
    });
  }

  @override
  void didUpdateWidget(FloatingDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _scrollToCurrent(animate: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scrollToCurrent({required bool animate}) {
    if (!_controller.hasClients || _viewport <= 0) return;
    final target = dockScrollOffsetForItem(
      itemIndex: widget.currentIndex,
      itemWidths: _allTabs.map((t) => t.width).toList(),
      viewportWidth: _viewport,
      currentOffset: _controller.offset,
    );
    if ((target - _controller.offset).abs() < 0.5) return;
    if (animate) {
      _controller.animateTo(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _controller.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              _viewport = constraints.maxWidth;
              return SingleChildScrollView(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final t in _allTabs) _tab(t),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _tab(_DockTab tab) {
    final selected = widget.currentIndex == tab.index;
    return SizedBox(
      width: tab.width,
      child: GestureDetector(
        onTap: () => widget.onTab(tab.index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 30,
              decoration: BoxDecoration(
                color: selected ? AppColors.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Icon(
                selected ? tab.iconFilled : tab.icon,
                size: 24,
                color: selected
                    ? AppColors.canvas
                    : AppColors.inkTertiary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              tab.label,
              textAlign: TextAlign.center,
              style: AppText.caption.copyWith(
                fontSize: tab.width > dockTabWidth ? 10 : 11,
                fontWeight: FontWeight.w600,
                color: selected
                    ? AppColors.accent
                    : AppColors.inkTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
