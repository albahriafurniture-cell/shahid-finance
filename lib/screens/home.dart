import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/balance_privacy.dart';
import '../widgets/common.dart';
import '../widgets/transfer_sheet.dart';
import '../widgets/wallet_logo.dart';
import 'add_transaction.dart';
import 'budgets.dart';
import 'loans.dart';
import 'transactions.dart';
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

        // Top clearance is status-bar height (MainShell SafeArea) + 12,
        // so the header never collides with the status bar (v1.1.1 fix).
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          children: [
            // Header
            Row(
              children: [
                ClipOval(
                  // v1.1.2: profile DP is the user's own photo.
                  child: Image.asset(
                    'assets/images/profile_photo.jpg',
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
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
                      Text(Store.userName.isEmpty ? 'SHAHID' : Store.userName,
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
                  // v1.1.4: total balance is masked by default; unlock
                  // (fingerprint / PIN) shows it for 30 seconds only.
                  MaskedAmount(
                    value: Store.totalBalance,
                    style: AppText.displayBalance
                        .copyWith(color: Colors.white, fontSize: 44),
                  ),
                  const SizedBox(height: 8),
                  const UnlockBalanceButton(),
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
            // v1.1.3: income & expense are the main focus — large,
            // unmissable buttons above the fold, right under the hero.
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openAdd(context, income: true),
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius:
                            BorderRadius.circular(AppRadius.md),
                        boxShadow: AppShadows.raised,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.south_west,
                              size: 22, color: AppColors.canvas),
                          const SizedBox(width: 8),
                          Text('Add Income',
                              style: AppText.bodyStrong.copyWith(
                                  fontSize: 16, color: AppColors.canvas)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openAdd(context, income: false),
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius:
                            BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                            color: AppColors.accent, width: 1.5),
                        boxShadow: AppShadows.card,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.north_east,
                              size: 22, color: AppColors.expense),
                          const SizedBox(width: 8),
                          Text('Add Expense',
                              style: AppText.bodyStrong.copyWith(
                                  fontSize: 16, color: AppColors.ink)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // v1.1.3 multi-scroll: wallet cards are a horizontally
            // swipeable carousel (snap via PageView, next card peeks).
            SectionHeader(
              title: 'My Wallets',
              actionLabel: 'Swipe ›',
              onAction: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const WalletsScreen())),
            ),
            const SizedBox(height: 12),
            _WalletCarousel(wallets: wallets),
            const SizedBox(height: 20),
            // v1.1.3 multi-scroll: quick actions scroll horizontally
            // (row is wider than the screen, so the next action peeks).
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
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
                  _quickAction(
                    context,
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Wallets',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const WalletsScreen())),
                  ),
                  // v1.1.5: Loans tracker (taken + given), reachable
                  // from Home — the 4-tab dock is unchanged.
                  _quickAction(
                    context,
                    icon: Icons.handshake_outlined,
                    label: 'Loans',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const LoansScreen())),
                  ),
                ],
              ),
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
            // v1.1.4: daily details on the front screen — Today,
            // Yesterday, and the current week, each with its income /
            // expense totals and entries (first 8; See all → History).
            const SizedBox(height: 28),
            _daySection(context, 'Today',
                Store.allTxnsDesc.where((t) => _isSameDay(t.date, now))),
            const SizedBox(height: 28),
            _daySection(
                context,
                'Yesterday',
                Store.allTxnsDesc.where(
                    (t) => _isSameDay(t.date, now.subtract(const Duration(days: 1))))),
            const SizedBox(height: 28),
            _daySection(
                context,
                'This week',
                Store.allTxnsDesc.where((t) =>
                    !t.date.isBefore(_weekStart(now)) &&
                    t.date.isBefore(
                        _weekStart(now).add(const Duration(days: 7))))),
          ],
        );
      },
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Monday of the current week (local time).
  static DateTime _weekStart(DateTime now) {
    final d = DateTime(now.year, now.month, now.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  /// v1.1.4 daily section: period totals + entries (first 8).
  Widget _daySection(
      BuildContext context, String title, Iterable<MoneyTxn> txns) {
    final list = txns.toList();
    final income = Store.sumIn(list);
    final expense = Store.sumOut(list);
    final shown = list.take(8).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: AppText.h2)),
            Text(
              Store.hideAmounts
                  ? 'In Rs •••••• · Out Rs ••••••'
                  : 'In ${fmtRs(income)} · Out ${fmtRs(expense)}',
              style:
                  AppText.caption.copyWith(color: AppColors.inkSecondary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          Container(
            decoration: cardDecoration(),
            padding: const EdgeInsets.all(16),
            child: Text('No entries',
                style:
                    AppText.label.copyWith(color: AppColors.inkSecondary)),
          )
        else
          GroupCard(
            children: [
              for (final t in shown)
                TxnRow(
                  txn: t,
                  onTap: () => showTxnDetailSheet(context, t),
                ),
              if (list.length > shown.length)
                GestureDetector(
                  onTap: onSeeAllTransactions,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(
                          'See all ${list.length} entries ›',
                          style: AppText.label
                              .copyWith(color: AppColors.accent)),
                    ),
                  ),
                ),
            ],
          ),
      ],
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
        color: AppColors.accent,
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
                        fontSize: 11, color: AppColors.accent)),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: GestureDetector(
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
            child: Icon(icon, size: 22, color: AppColors.accent),
          ),
          const SizedBox(height: 6),
          Text(label, style: AppText.label.copyWith(fontSize: 11)),
        ],
        ),
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

/// v1.1.3: horizontally swipeable wallet carousel. PageView snaps
/// page-to-page; viewportFraction < 1 leaves the next card peeking
/// in, which is the affordance that more cards exist sideways.
class _WalletCarousel extends StatefulWidget {
  final List<Wallet> wallets;
  const _WalletCarousel({required this.wallets});

  @override
  State<_WalletCarousel> createState() => _WalletCarouselState();
}

class _WalletCarouselState extends State<_WalletCarousel> {
  final _controller = PageController(viewportFraction: 0.84);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.wallets.isEmpty) {
      return Container(
        decoration: cardDecoration(),
        padding: const EdgeInsets.all(20),
        child: Text('No wallets yet',
            style: AppText.label.copyWith(color: AppColors.inkSecondary),
            textAlign: TextAlign.center),
      );
    }
    return Column(
      children: [
        SizedBox(
          height: 132,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _page = i),
            itemCount: widget.wallets.length,
            itemBuilder: (context, i) {
              final w = widget.wallets[i];
              final balance = Store.balanceOf(w.id);
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => WalletDetailScreen(walletId: w.id))),
                  child: Container(
                    decoration: cardDecoration(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            WalletAvatar(type: w.type, size: 40),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(w.name,
                                  style: AppText.bodyStrong,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            if (w.isDefault)
                              Text('Default',
                                  style: AppText.caption.copyWith(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.brandDeep)),
                          ],
                        ),
                        const Spacer(),
                        Text('BALANCE',
                            style: AppText.micro.copyWith(
                                color: AppColors.inkTertiary)),
                        const SizedBox(height: 2),
                        MaskedAmount(
                          value: balance,
                          style: AppText.amountRow,
                        ),
                        const SizedBox(height: 2),
                        Text(w.caption,
                            style: AppText.caption.copyWith(
                                color: AppColors.inkTertiary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.wallets.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.wallets.length; i++)
                Container(
                  width: _page == i ? 20 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: _page == i
                        ? AppColors.accent
                        : AppColors.hairline,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class BudgetAlertData {
  final Budget budget;
  final int spent;
  final double pct;
  BudgetAlertData(this.budget, this.spent, this.pct);
}
