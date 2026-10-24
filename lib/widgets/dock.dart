import 'package:flutter/material.dart';

import '../theme.dart';

/// Floating bottom navigation with the signature centre FAB fan
/// (master §3.5): tap + → Add Income / Add Expense mini-actions.
class FloatingDock extends StatefulWidget {
  final int currentIndex; // 0 Home, 1 Transactions, 2 Reports, 3 Profile
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

class _FloatingDockState extends State<FloatingDock> {
  bool _fanOpen = false;

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
        // Fan mini-actions
        Positioned(
          bottom: 92,
          child: AnimatedOpacity(
            opacity: _fanOpen ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: IgnorePointer(
              ignoring: !_fanOpen,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _fanAction(
                    icon: Icons.south_west,
                    label: 'Add Income',
                    tint: AppColors.mintTint,
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
            ),
          ),
        ),
        Container(
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
              _tab(0, Icons.home_outlined, Icons.home, 'Home'),
              _tab(1, Icons.receipt_long_outlined, Icons.receipt_long,
                  'History'),
              const SizedBox(width: 64), // FAB slot
              _tab(2, Icons.bar_chart_outlined, Icons.bar_chart, 'Reports'),
              _tab(3, Icons.person_outline, Icons.person, 'Profile'),
            ],
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
                gradient: AppColors.heroGradient,
                shape: BoxShape.circle,
                boxShadow: AppShadows.fab,
              ),
              child: AnimatedRotation(
                turns: _fanOpen ? 0.125 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.add, color: Colors.white, size: 28),
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

  Widget _tab(int index, IconData icon, IconData iconFilled, String label) {
    final selected = widget.currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _closeFan();
          widget.onTab(index);
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 30,
              decoration: BoxDecoration(
                color: selected ? AppColors.mintTint : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Icon(
                selected ? iconFilled : icon,
                size: 24,
                color: selected
                    ? AppColors.brandDeep
                    : AppColors.inkTertiary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppText.caption.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected
                    ? AppColors.brandDeep
                    : AppColors.inkTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
