import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../services/auth_gate.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/balance_privacy.dart';
import '../widgets/common.dart';
import '../widgets/transfer_sheet.dart';
import '../widgets/wallet_logo.dart';
import 'add_transaction.dart';
import 'budgets.dart';
import 'goals.dart';
import 'loans.dart';
import 'transactions.dart';
import 'wallets.dart';

/// Home dashboard (master Screen 3).
///
/// v1.1.6: layout rebuilt to match the user's reference screenshot —
/// header (photo, greeting, name, bell) → large TOTAL BALANCE glass
/// card (masked amount, Tap to unlock, month Income/Expense, This
/// month pill) → big Add Income / Add Expense buttons → FOUR fixed
/// circular quick actions (Budgets, Transfer, Goals, Loans) → My
/// Wallets carousel → Recent Transactions with Today / Yesterday /
/// This week segmented tabs. Real user data throughout; the
/// screenshot's literal figures are mockup samples, never app data.
class HomeScreen extends StatefulWidget {
  final VoidCallback onSeeAllTransactions;
  const HomeScreen({super.key, required this.onSeeAllTransactions});

  /// Monday of the current week (local time).
  static DateTime weekStart(DateTime now) {
    final d = DateTime(now.year, now.month, now.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Period filter for the Recent Transactions tabs. Pure function so
  /// it is unit-testable without pumping the screen.
  /// period: 0 = Today, 1 = Yesterday, 2 = This week (Mon–Sun).
  static List<MoneyTxn> txnsForPeriod(
      List<MoneyTxn> txns, int period, DateTime now) {
    switch (period) {
      case 1:
        final y = now.subtract(const Duration(days: 1));
        return txns.where((t) => isSameDay(t.date, y)).toList();
      case 2:
        final start = weekStart(now);
        final end = start.add(const Duration(days: 7));
        return txns
            .where((t) =>
                !t.date.isBefore(start) && t.date.isBefore(end))
            .toList();
      case 0:
      default:
        return txns.where((t) => isSameDay(t.date, now)).toList();
    }
  }

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Recent Transactions tab: 0 Today, 1 Yesterday, 2 This week.
  int _period = 0;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
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
        final wallets = Store.activeWallets;
        final allDesc = Store.allTxnsDesc;

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

        final periodTxns =
            HomeScreen.txnsForPeriod(allDesc, _period, now);
        final periodIn = Store.sumIn(periodTxns);
        final periodOut = Store.sumOut(periodTxns);

        // Top clearance is status-bar height (MainShell SafeArea) + 12,
        // so the header never collides with the status bar (v1.1.1 fix).
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          children: [
            // Header: photo, greeting + name, bell — as in the
            // screenshot. Avatar is the user's own photo (v1.1.2);
            // name is the stored profile name (SHAHID, v1.1.2).
            Row(
              children: [
                ClipOval(
                  child: Image.asset(
                    'assets/images/profile_photo.jpg',
                    width: 48,
                    height: 48,
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
                          style: AppText.bodyStrong.copyWith(fontSize: 22)),
                    ],
                  ),
                ),
                const CircleIconButton(icon: Icons.notifications_outlined),
              ],
            ),
            const SizedBox(height: 16),
            // Hero balance card — screenshot layout: label + eye,
            // huge masked amount + Tap to unlock pill, divider, month
            // Income / Expense row + This month pill.
            HeroCard(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const WalletsScreen())),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                            'TOTAL BALANCE · ${wallets.length} WALLET${wallets.length == 1 ? '' : 'S'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.micro.copyWith(
                                color:
                                    Colors.white.withValues(alpha: 0.7))),
                      ),
                      // Eye unlocks like the pill below (v1.1.4
                      // balance lock: fingerprint / PIN, 30s auto-lock).
                      GestureDetector(
                        onTap: () => BalanceLock.unlock(context),
                        child: const Icon(
                          Icons.visibility_outlined,
                          size: 22,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        // v1.1.4: total balance masked by default;
                        // unlock shows it for 30 seconds only.
                        // FittedBox: a long real balance must shrink,
                        // never push the unlock pill off-screen.
                        child: FittedBox(
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.scaleDown,
                          child: MaskedAmount(
                            value: Store.totalBalance,
                            style: AppText.displayBalance
                                .copyWith(color: Colors.white),
                          ),
                        ),
                      ),
                      const UnlockBalanceButton(),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Divider(height: 1, color: Color(0x26FFFFFF)),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _monthStat(
                          icon: Icons.south_west,
                          iconColor: AppColors.accent,
                          tileColor: AppColors.accentTint,
                          label: 'Income',
                          value: income,
                        ),
                      ),
                      Expanded(
                        child: _monthStat(
                          icon: Icons.north_east,
                          iconColor: AppColors.expense,
                          tileColor: AppColors.expenseTint,
                          label: 'Expense',
                          value: expense,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius:
                              BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text('This month',
                            style: AppText.label.copyWith(fontSize: 12)),
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
                      // FittedBox: on narrow phones the label must
                      // shrink, never overflow the button.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
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
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
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
                ),
              ],
            ),
            const SizedBox(height: 24),
            // v1.1.6: FOUR fixed circular quick actions, all visible
            // at once (no scrolling) — exactly as in the screenshot.
            // Add Income/Expense live in the big buttons above;
            // Wallets live in the carousel below.
            Row(
              children: [
                _quickFixed(
                  context,
                  icon: Icons.track_changes,
                  label: 'Budgets',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const BudgetsScreen())),
                ),
                _quickFixed(
                  context,
                  icon: Icons.swap_horiz,
                  label: 'Transfer',
                  onTap: () => showTransferSheet(context),
                ),
                _quickFixed(
                  context,
                  icon: Icons.flag_outlined,
                  label: 'Goals',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const GoalsScreen())),
                ),
                _quickFixed(
                  context,
                  icon: Icons.handshake_outlined,
                  label: 'Loans',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const LoansScreen())),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // My Wallets carousel (v1.1.3: snap + peek + Swipe hint).
            SectionHeader(
              title: 'My Wallets',
              actionLabel: 'Swipe ›',
              onAction: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const WalletsScreen())),
            ),
            const SizedBox(height: 12),
            _WalletCarousel(wallets: wallets),
            const SizedBox(height: 28),
            // Recent Transactions with segmented period tabs
            // (v1.1.6: replaces the v1.1.4 stacked day sections).
            SectionHeader(
              title: 'Recent Transactions',
              actionLabel: 'See all',
              onAction: widget.onSeeAllTransactions,
            ),
            const SizedBox(height: 12),
            _periodTabs(),
            const SizedBox(height: 12),
            if (periodTxns.isEmpty)
              _emptyPeriod(periodIn, periodOut)
            else ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  Store.hideAmounts
                      ? 'In Rs •••••• · Out Rs ••••••'
                      : 'In ${fmtRs(periodIn)} · Out ${fmtRs(periodOut)}',
                  style:
                      AppText.caption.copyWith(color: AppColors.inkSecondary),
                ),
              ),
              GroupCard(
                children: [
                  for (final t in periodTxns)
                    TxnRow(
                      txn: t,
                      onTap: () => showTxnDetailSheet(context, t),
                    ),
                ],
              ),
            ],
            // Budget alert strip — kept, but moved below Recent
            // Transactions so the screenshot's order stays intact.
            if (alert != null) ...[
              const SizedBox(height: 20),
              _budgetStrip(context, alert, cycle),
            ],
          ],
        );
      },
    );
  }

  /// Segmented Today / Yesterday / This week control, as in the
  /// screenshot: one dark pill container, selected tab tinted neon.
  Widget _periodTabs() {
    const labels = ['Today', 'Yesterday', 'This week'];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _period = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _period == i
                        ? AppColors.accentTint
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    labels[i],
                    style: AppText.label.copyWith(
                      fontSize: 13,
                      color: _period == i
                          ? AppColors.accent
                          : AppColors.inkSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Dashed-border empty state, exactly as in the screenshot:
  /// receipt icon tile, "No transactions yet", In/Out totals,
  /// "Add first" action.
  Widget _emptyPeriod(int periodIn, int periodOut) {
    return CustomPaint(
      painter: _DashedBorderPainter(),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.accentTint,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.receipt_long_outlined,
                  size: 26, color: AppColors.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No transactions yet',
                      style: AppText.bodyStrong.copyWith(fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(
                    Store.hideAmounts
                        ? 'In Rs •••••• · Out Rs ••••••'
                        : 'In ${fmtRs(periodIn)} · Out ${fmtRs(periodOut)}',
                    style: AppText.caption
                        .copyWith(color: AppColors.inkSecondary),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _openAdd(context, income: false),
              child: Text('Add first',
                  style: AppText.label.copyWith(color: AppColors.accent)),
            ),
          ],
        ),
      ),
    );
  }

  void _openAdd(BuildContext context, {required bool income}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AddTransactionScreen(initialIncome: income),
    ));
  }

  Widget _monthStat({
    required IconData icon,
    required Color iconColor,
    required Color tileColor,
    required String label,
    required int value,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: tileColor,
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          child: Icon(icon, size: 18, color: iconColor),
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
            ],
          ),
        ),
      ],
    );
  }

  Widget _quickFixed(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.hairline),
                boxShadow: AppShadows.card,
              ),
              child: Icon(icon, size: 24, color: AppColors.accent),
            ),
            const SizedBox(height: 6),
            Text(label, style: AppText.label.copyWith(fontSize: 12)),
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

/// Dashed rounded-rectangle border for the empty-period state.
class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(24));
    final path = Path()..addRRect(rrect);
    const dashWidth = 6.0;
    const dashSpace = 5.0;
    final paint = Paint()
      ..color = const Color(0x66FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final segment =
            metric.extractPath(distance, distance + dashWidth);
        canvas.drawPath(segment, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
          // v1.1.6: 140, not 132 — the restructured card (logo row +
          // caption + Balance row) overflowed by 2px at 132 in tests.
          height: 140,
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
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(w.caption,
                            style: AppText.caption.copyWith(
                                color: AppColors.inkTertiary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Balance',
                                      style: AppText.caption.copyWith(
                                          color: AppColors.inkTertiary)),
                                  const SizedBox(height: 2),
                                  MaskedAmount(
                                    value: balance,
                                    style: AppText.amountRow,
                                  ),
                                ],
                              ),
                            ),
                            if (w.isDefault)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.circular(
                                      AppRadius.pill),
                                ),
                                child: Text('Default',
                                    style: AppText.label.copyWith(
                                        fontSize: 11,
                                        color: AppColors.canvas)),
                              ),
                          ],
                        ),
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
