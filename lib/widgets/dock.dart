import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme.dart';

/// v1.1.7: floating bottom navigation with a scrollable tab row.
///
/// Six tabs no longer fit a 360dp screen without cramping, so each
/// side of the centre FAB is its own horizontal scroll group:
/// left = Home, History, Vault (Password Manager); right = Diary,
/// Reports, Profile. The FAB stays fixed dead-centre over its 64dp
/// slot, so a tab can NEVER slide under it — the v1.1.1 overlap bug
/// cannot return. Selecting a tab scrolls its side group until the
/// tab is fully visible (scroll-to-selected).
///
/// Tab order: 0 Home, 1 History, 2 Vault, 3 Diary, 4 Reports,
/// 5 Profile. The centre + FAB fan behaviour is unchanged.
class FloatingDock extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTab;
  final VoidCallback onAddIncome;
  final VoidCallback onAddExpense;

  const FloatingDock({
    super.key,
    required this.currentIndex,
    required this.onTab,
    required this.onAddIncome,
    required this.onAddExpense,
  });

  @override
  State<FloatingDock> createState() => _FloatingDockState();
}

/// Width of one dock tab item (fixed, so scrolling is predictable).
const double dockTabWidth = 64;

/// Pure scroll target: smallest offset that makes [itemIndex] fully
/// visible in a viewport of [viewportWidth], given [currentOffset].
/// Unit-tested; the widget only animates to what this returns.
double dockScrollOffsetForItem({
  required int itemIndex,
  required int itemCount,
  required double itemWidth,
  required double viewportWidth,
  required double currentOffset,
}) {
  final totalWidth = itemCount * itemWidth;
  final maxOffset = (totalWidth - viewportWidth).clamp(0.0, totalWidth);
  final itemStart = itemIndex * itemWidth;
  final itemEnd = itemStart + itemWidth;
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
  const _DockTab(this.index, this.icon, this.iconFilled, this.label);
}

const _leftTabs = [
  _DockTab(0, Icons.home_outlined, Icons.home, 'Home'),
  _DockTab(1, Icons.receipt_long_outlined, Icons.receipt_long, 'History'),
  _DockTab(2, Icons.lock_outlined, Icons.lock, 'Vault'),
];

const _rightTabs = [
  _DockTab(3, Icons.book_outlined, Icons.book, 'Diary'),
  _DockTab(4, Icons.bar_chart_outlined, Icons.bar_chart, 'Reports'),
  _DockTab(5, Icons.person_outline, Icons.person, 'Profile'),
];

class _FloatingDockState extends State<FloatingDock> {
  bool _fanOpen = false;
  final _leftController = ScrollController();
  final _rightController = ScrollController();
  double _leftViewport = 0;
  double _rightViewport = 0;

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
    _leftController.dispose();
    _rightController.dispose();
    super.dispose();
  }

  void _scrollToCurrent({required bool animate}) {
    final index = widget.currentIndex;
    ScrollController? controller;
    List<_DockTab> tabs;
    double viewport;
    int localIndex;
    if (index < _leftTabs.length) {
      controller = _leftController;
      tabs = _leftTabs;
      viewport = _leftViewport;
      localIndex = index;
    } else {
      controller = _rightController;
      tabs = _rightTabs;
      viewport = _rightViewport;
      localIndex = index - _leftTabs.length;
    }
    if (!controller.hasClients || viewport <= 0) return;
    final target = dockScrollOffsetForItem(
      itemIndex: localIndex,
      itemCount: tabs.length,
      itemWidth: dockTabWidth,
      viewportWidth: viewport,
      currentOffset: controller.offset,
    );
    if ((target - controller.offset).abs() < 0.5) return;
    if (animate) {
      controller.animateTo(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      controller.jumpTo(target);
    }
  }

  void _closeFan() {
    if (_fanOpen) setState(() => _fanOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        if (_fanOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeFan,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
        // Fan mini-actions (v1.1.3: labelled header so the
        // Income/Expense choice is unmistakable at a glance).
        Positioned(
          bottom: 92,
          child: AnimatedOpacity(
            opacity: _fanOpen ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: IgnorePointer(
              ignoring: !_fanOpen,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius:
                          BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: AppColors.hairline),
                      boxShadow: AppShadows.card,
                    ),
                    child: Text('Income or expense?',
                        style: AppText.label.copyWith(
                            fontSize: 12, color: AppColors.ink)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _fanAction(
                        icon: Icons.south_west,
                        label: 'Add Income',
                        tint: AppColors.accentTint,
                        color: AppColors.brandDeep,
                        onTap: () {
                          _closeFan();
                          widget.onAddIncome();
                        },
                      ),
                      const SizedBox(width: 16),
                      _fanAction(
                        icon: Icons.north_east,
                        label: 'Add Expense',
                        tint: AppColors.expenseTint,
                        color: AppColors.expense,
                        onTap: () {
                          _closeFan();
                          widget.onAddExpense();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        ClipRRect(
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
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        _leftViewport = constraints.maxWidth;
                        return SingleChildScrollView(
                          controller: _leftController,
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final t in _leftTabs) _tab(t),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 64), // FAB slot — centred
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        _rightViewport = constraints.maxWidth;
                        return SingleChildScrollView(
                          controller: _rightController,
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final t in _rightTabs) _tab(t),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 38,
          child: GestureDetector(
            onTap: () => setState(() => _fanOpen = !_fanOpen),
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
                boxShadow: AppShadows.fab,
              ),
              child: AnimatedRotation(
                turns: _fanOpen ? 0.125 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.add, color: AppColors.canvas, size: 28),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _fanAction({
    required IconData icon,
    required String label,
    required Color tint,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: tint,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.hairline),
              boxShadow: AppShadows.card,
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Text(label,
                style: AppText.label.copyWith(fontSize: 11, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _tab(_DockTab tab) {
    final selected = widget.currentIndex == tab.index;
    return SizedBox(
      width: dockTabWidth,
      child: GestureDetector(
        onTap: () {
          _closeFan();
          widget.onTab(tab.index);
        },
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
              style: AppText.caption.copyWith(
                fontSize: 11,
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
