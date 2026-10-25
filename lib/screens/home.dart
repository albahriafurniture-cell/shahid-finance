import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/transfer_sheet.dart';
import 'add_transaction.dart';
import 'budgets.dart';
import 'transactions.dart';
import 'password_manager.dart';
import 'wallets.dart';

/// Home dashboard (master Screen 3).
class HomeScreen extends StatelessWidget {
  final VoidCallback onSeeAllTransactions;
  const HomeScreen({super.key, required this.onSeeAllTransactions});

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String? _vsCaption(int current, int previous, {required bool isExpense}) {
    if (previous <= 0) return null;
    final diff = ((current - previous) / previous * 100).round();
    if (diff == 0) return 'Same as last month';
    final sign = diff > 0 ? '+' : '−';
    return '$sign${diff.abs()}% vs last month';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: Store.changes,
      builder: (context, _, _) {
        final now = DateTime.now();
        final monthTxns = Store.txnsInMonth(now.year, now.month);
        final income = Store.sumIn(monthTxns);
        final expense = Store.sumOut(monthTxns);
        final prev = DateTime(now.year, now.month - 1);
        final prevTxns = Store.txnsInMonth(prev.year, prev.month);
        final prevIncome = Store.sumIn(prevTxns);
        final prevExpense = Store.sumOut(prevTxns);
        final wallets = Store.activeWallets;
        final recent = Store.allTxnsDesc.take(5).toList();

        // Budget snapshot: the budget closest to (or past) its limit in
        // the current cycle, shown only at ≥70% used.
        final cycle = cycleFor(Store.cycleStartDay, now);
        BudgetAlertData? alert;
        for (final b in Store.allBudgets) {
          final spent = Store.spentForCategoryInCycle(b.categoryId, cycle);
          if (b.limitAmount <= 0) continue;
          final pct = spent / b.limitAmount;
          if (pct >= 0.7 && (alert == null || pct > alert.pct)) {
            alert = BudgetAlertData(b, spent, pct);
          }
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.mintTint,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    Store.userName.isEmpty
                        ? 'S'
                        : Store.userName[0].toUpperCase(),
                    style: AppText.bodyStrong
                        .copyWith(color: AppColors.brandDeep, fontSize: 17),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_greeting,
                          style: AppText.caption
                              .copyWith(color: AppColors.inkSecondary)),
                      Text(Store.userName.isEmpty ? 'Shahid' : Store.userName,
                          style: AppText.bodyStrong.copyWith(fontSize: 16)),
                    ],
                  ),
                ),
                const CircleIconButton(icon: Icons.notifications_outlined),
              ],
            ),
            const SizedBox(height: 12),
            // Hero balance card
            HeroCard(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const WalletsScreen())),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Text('TOTAL BALANCE',
                          style: AppText.micro.copyWith(
                              color: Colors.white.withValues(alpha: 0.7))),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Store.setSetting(
                            'hideAmounts', !Store.hideAmounts),
                        child: Icon(
                          Store.hideAmounts
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  AmountText(
                    value: Store.totalBalance,
                    style: AppText.displayBalance
                        .copyWith(color: Colors.white, fontSize: 44),
                    neutral: true,
                  ),
                  const SizedBox(height: 8),
                  _balancePill(income, expense, prevIncome, prevExpense),
                  const SizedBox(height: 4),
                  Text(
                    'Across ${wallets.length} wallet${wallets.length == 1 ? '' : 's'}',
                    style: AppText.caption
                        .copyWith(color: Colors.white.withValues(alpha: 0.7)),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(height: 1, color: Color(0x26FFFFFF)),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _heroStat(
                          icon: Icons.south_west,
                          label: 'Income',
                          value: income,
                          caption:
                              _vsCaption(income, prevIncome, isExpense: false),
                        ),
                      ),
                      Expanded(
                        child: _heroStat(
                          icon: Icons.north_east,
                          label: 'Expense',
                          value: expense,
                          caption: _vsCaption(expense, prevExpense,
                              isExpense: true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Quick actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _quickAction(
                  context,
                  icon: Icons.north_east,
                  label: 'Add Expense',
                  onTap: () => _openAdd(context, income: false),
                ),
                _quickAction(
                  context,
                  icon: Icons.south_west,
                  label: 'Add Income',
                  onTap: () => _openAdd(context, income: true),
                ),
                _quickAction(
                  context,
                  icon: Icons.key_outlined,
                  label: 'Passwords',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const PasswordManagerScreen())),
                ),
                _quickAction(
                  context,
                  icon: Icons.track_changes,
                  label: 'Budgets',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const BudgetsScreen())),
                ),
                _quickAction(
                  context,
                  icon: Icons.swap_horiz,
                  label: 'Transfer',
                  onTap: () => showTransferSheet(context),
                ),
              ],
            ),
            // Budget snapshot strip
            if (alert != null) ...[
              const SizedBox(height: 20),
              _budgetStrip(context, alert, cycle),
            ],
            const SizedBox(height: 28),
            SectionHeader(
              title: 'Recent Transactions',
              actionLabel: recent.isEmpty ? null : 'See all',
              onAction: onSeeAllTransactions,
            ),
            const SizedBox(height: 12),
            if (recent.isEmpty)
              Container(
                decoration: cardDecoration(),
                child: EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No transactions yet',
                  body:
                      'Add your first income or expense and it will appear here.',
                  actionLabel: 'Add your first one',
                  onAction: () => _openAdd(context, income: false),
                ),
              )
            else
              GroupCard(
                children: [
                  for (final t in recent)
                    TxnRow(
                      txn: t,
                      onTap: () => showTxnDetailSheet(context, t),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }

  void _openAdd(BuildContext context, {required bool income}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AddTransactionScreen(initialIncome: income),
    ));
  }

  Widget _balancePill(int income, int expense, int prevIncome, int prevExpense) {
    final net = income - expense;
    final prevNet = prevIncome - prevExpense;
    String label;
    if (prevNet == 0) {
      label = net >= 0 ? 'Saving this month' : 'Spending this month';
    } else {
      final pct = ((net - prevNet) / prevNet.abs() * 100).round();
      label = '${pct >= 0 ? '+' : '−'}${pct.abs()}% vs last month';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.lime,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(label,
          style: AppText.label
              .copyWith(fontSize: 12, color: AppColors.canvas)),
    );
  }

  Widget _heroStat({
    required IconData icon,
    required String label,
    required int value,
    String? caption,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: AppText.caption
                      .copyWith(color: Colors.white.withValues(alpha: 0.7))),
              AmountText(
                value: value,
                style: AppText.bodyStrong.copyWith(
                    color: Colors.white, fontSize: 15),
                neutral: true,
              ),
              if (caption != null)
                Text(caption,
                    style: AppText.caption.copyWith(
                        fontSize: 11, color: AppColors.mint)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.hairline),
              boxShadow: AppShadows.card,
            ),
            child: Icon(icon, size: 22, color: AppColors.lime),
          ),
          const SizedBox(height: 6),
          Text(label, style: AppText.label.copyWith(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _budgetStrip(BuildContext context, BudgetAlertData alert, Cycle cycle) {
    final cat = Store.categoryById(alert.budget.categoryId);
    final left = alert.budget.limitAmount - alert.spent;
    final days = cycle.daysRemaining();
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const BudgetsScreen())),
      child: Container(
        decoration: cardDecoration(),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.warningTint,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.track_changes,
                  size: 22, color: AppColors.warning),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    left < 0
                        ? '${cat?.name ?? 'Budget'} over budget'
                        : '${cat?.name ?? 'Budget'} budget almost full',
                    style: AppText.bodyStrong.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    left < 0
                        ? '${fmtRs(-left)} over of ${fmtRs(alert.budget.limitAmount)}'
                        : '${fmtRs(left)} left of ${fmtRs(alert.budget.limitAmount)} · $days day${days == 1 ? '' : 's'} to go',
                    style: AppText.caption
                        .copyWith(color: AppColors.inkSecondary),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                value: alert.pct.clamp(0.0, 1.0),
                strokeWidth: 5,
                backgroundColor: AppColors.surfaceInset,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.warning),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BudgetAlertData {
  final Budget budget;
  final int spent;
  final double pct;
  BudgetAlertData(this.budget, this.spent, this.pct);
}
