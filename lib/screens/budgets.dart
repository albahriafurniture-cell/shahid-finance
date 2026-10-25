import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/transfer_sheet.dart' show amountGroupingFormatter;
import 'settings.dart' show showCycleSheet;

/// Budgets (budgets/settings spec §1): cycle card with % + pacing,
/// per-category budget cards with on-track/near/over states.
///
/// Data note: budgets in the shipped data layer are STANDING per-category
/// monthly limits (Budget{categoryId, limitAmount}); the "overall" card
/// aggregates them against total cycle spending.
class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  Cycle? _cycle;

  Cycle get _currentCycle => cycleFor(Store.cycleStartDay, DateTime.now());

  String _cycleRange(Cycle c) {
    if (c.start.year == c.end.year && c.start.month == c.end.month) {
      return '${c.start.day} – ${c.end.day} ${DateFormat('MMM').format(c.end)}';
    }
    return '${fmtDate(c.start)} – ${fmtDate(c.end)}';
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      body: SafeArea(
        child: ValueListenableBuilder<int>(
          valueListenable: Store.changes,
          builder: (context, _, _) {
            final cycle = _cycle ??= _currentCycle;
            final realCurrent = _currentCycle;
            final isCurrent = cycle.start == realCurrent.start;
            final canNext = cycle.end.isBefore(realCurrent.end);

            final budgets = Store.allBudgets;
            final totalLimit =
                budgets.fold(0, (s, b) => s + b.limitAmount);
            final totalSpent = Store.txnsInCycle(cycle)
                .where((t) => t.isExpense)
                .fold(0, (s, t) => s + t.amount);
            final budgetedCats = budgets.map((b) => b.categoryId).toSet();
            final noBudgetCats = Store.categoriesFor('expense')
                .where((c) =>
                    !budgetedCats.contains(c.id) &&
                    Store.spentForCategoryInCycle(c.id, cycle) > 0)
                .toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                const SubScreenHeader(title: 'Budgets'),
                const SizedBox(height: 16),
                // Cycle selector
                Row(
                  children: [
                    CircleIconButton(
                      icon: Icons.chevron_left,
                      size: 36,
                      onTap: () => setState(() => _cycle = cycleFor(
                          Store.cycleStartDay,
                          cycle.start.subtract(const Duration(days: 1)))),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(fmtMonth(cycle.start), style: AppText.h2),
                          const SizedBox(height: 2),
                          Text(_cycleRange(cycle),
                              style: AppText.caption.copyWith(
                                  color: AppColors.inkTertiary)),
                        ],
                      ),
                    ),
                    CircleIconButton(
                      icon: Icons.chevron_right,
                      size: 36,
                      onTap: canNext
                          ? () => setState(() => _cycle = cycleFor(
                              Store.cycleStartDay,
                              cycle.end.add(const Duration(days: 1))))
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Cycle note strip
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    boxShadow: AppShadows.card,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Budget starts on the ${cycleDayLabel(Store.cycleStartDay)}',
                          style: AppText.label
                              .copyWith(color: AppColors.inkSecondary),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => showCycleSheet(context),
                        child: Text('Change',
                            style: AppText.label.copyWith(
                                color: AppColors.brandDeep,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _overallCard(context, cycle, totalLimit, totalSpent,
                    hasBudgets: budgets.isNotEmpty, isCurrent: isCurrent),
                const SizedBox(height: 24),
                if (budgets.isNotEmpty) ...[
                  Text('CATEGORY BUDGETS',
                      style: AppText.micro
                          .copyWith(color: AppColors.inkTertiary)),
                  const SizedBox(height: 12),
                  for (final b in budgets) ...[
                    _categoryBudgetCard(context, cycle, b,
                        readOnly: !isCurrent),
                    const SizedBox(height: 12),
                  ],
                ],
                if (isCurrent)
                  GestureDetector(
                    onTap: () => showBudgetSheet(context),
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        boxShadow: AppShadows.card,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add,
                              size: 20, color: AppColors.brandDeep),
                          const SizedBox(width: 8),
                          Text('Add a budget',
                              style: AppText.body.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.brandDeep)),
                        ],
                      ),
                    ),
                  ),
                if (noBudgetCats.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    decoration: insetDecoration(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 4),
                          child: Text('NO BUDGET SET',
                              style: AppText.micro.copyWith(
                                  color: AppColors.inkTertiary)),
                        ),
                        for (final c in noBudgetCats)
                          SizedBox(
                            height: 52,
                            child: Row(
                              children: [
                                CategoryTile(category: c, size: 36),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Text(c.name, style: AppText.body)),
                                Text(
                                    fmtRs(Store.spentForCategoryInCycle(
                                        c.id, cycle)),
                                    style: AppText.label),
                                const SizedBox(width: 8),
                                Text('spent', style: AppText.caption),
                                const SizedBox(width: 12),
                                if (isCurrent)
                                  GestureDetector(
                                    onTap: () => showBudgetSheet(context,
                                        presetCategory: c),
                                    child: Text('+ Set',
                                        style: AppText.body.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.brandDeep)),
                                  ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _overallCard(BuildContext context, Cycle cycle, int limit,
      int spent, {required bool hasBudgets, required bool isCurrent}) {
    if (!hasBudgets) {
      return Container(
        decoration: cardDecoration(),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.track_changes_outlined,
                size: 40, color: AppColors.inkTertiary),
            const SizedBox(height: 12),
            Text('No budgets set for ${fmtMonth(cycle.start)} yet',
                style: AppText.title, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(
              'Set a monthly limit per category and Shahid Finance will pace your spending.',
              style: AppText.caption.copyWith(color: AppColors.inkTertiary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (isCurrent)
              PrimaryButton(
                label: 'Set a budget',
                onTap: () => showBudgetSheet(context),
              ),
          ],
        ),
      );
    }
    final pct = percentOf(spent, limit);
    final over = spent > limit;
    final left = limit - spent;
    final days = cycle.daysRemaining();
    return Container(
      decoration: over
          ? BoxDecoration(
              color: AppColors.expenseTint,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border:
                  Border.all(color: AppColors.expense.withValues(alpha: 0.3)),
            )
          : BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppShadows.hero,
            ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text('$pct% of ${fmtRs(limit)} used',
                    style: AppText.h2.copyWith(
                        color: over ? AppColors.expense : Colors.white)),
              ),
              Text(
                over
                    ? '${fmtRs(-left)} over'
                    : '${fmtRs(left)} left · ${days == 0 ? 'last day' : '$days days to go'}',
                style: AppText.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: over
                        ? AppColors.expense
                        : Colors.white.withValues(alpha: 0.85)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${fmtRs(spent)} of ${fmtRs(limit)} spent',
            style: AppText.caption.copyWith(
                color: over
                    ? AppColors.inkSecondary
                    : Colors.white.withValues(alpha: 0.75)),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: limit == 0 ? 0 : (spent / limit).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor:
                  over ? Colors.white : Colors.white.withValues(alpha: 0.22),
              valueColor: AlwaysStoppedAnimation<Color>(
                  over ? AppColors.expense : Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          if (over)
            Text(
              'You are over your combined category budgets for ${fmtMonth(cycle.start)}.',
              style: AppText.caption.copyWith(color: AppColors.inkSecondary),
            )
          else
            Text(
              '≈ ${fmtRs(pacePerDay(left, days))}/day for the rest of ${DateFormat('MMMM').format(cycle.start)}',
              style: AppText.caption.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.9)),
            ),
        ],
      ),
    );
  }

  Widget _categoryBudgetCard(BuildContext context, Cycle cycle, Budget b,
      {required bool readOnly}) {
    final cat = Store.categoryById(b.categoryId);
    if (cat == null) return const SizedBox.shrink();
    final spent = Store.spentForCategoryInCycle(cat.id, cycle);
    final pct = percentOf(spent, b.limitAmount);
    final over = spent > b.limitAmount;
    final near = !over && pct >= 80;
    final left = b.limitAmount - spent;
    final days = cycle.daysRemaining();
    final (chipLabel, chipBg, chipFg) = over
        ? ('Over budget', AppColors.expenseTint, AppColors.expense)
        : near
            ? ('Near limit', AppColors.warningTint, AppColors.warningText)
            : ('On track', AppColors.mintTint, AppColors.brandDeep);
    final barColor =
        over ? AppColors.expense : (near ? AppColors.warning : AppColors.brand);
    return GestureDetector(
      onTap: readOnly ? null : () => showBudgetSheet(context, existing: b),
      child: Container(
        decoration: cardDecoration(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CategoryTile(category: cat, size: 36),
                const SizedBox(width: 12),
                Expanded(child: Text(cat.name, style: AppText.bodyStrong)),
                Container(
                  height: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(chipLabel,
                      style: AppText.caption.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: chipFg)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('${fmtRs(spent)} of ${fmtRs(b.limitAmount)}',
                    style: AppText.label),
                const Spacer(),
                Text(over ? '${fmtRs(-left)} over' : '${fmtRs(left)} left',
                    style: AppText.label.copyWith(
                        fontWeight: FontWeight.w700,
                        color: over ? AppColors.expense : AppColors.brandDeep)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: b.limitAmount == 0
                    ? 0
                    : (spent / b.limitAmount).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: AppColors.hairline,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              over
                  ? 'Over by ${fmtRs(-left)} — try to pause ${cat.name.toLowerCase()} spending this cycle.'
                  : '≈ ${fmtRs(pacePerDay(left, days))}/day left for ${cat.name.toLowerCase()}',
              style: AppText.caption.copyWith(color: AppColors.inkTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Add/edit budget sheet (budgets spec §1.5).
Future<void> showBudgetSheet(BuildContext context,
    {AppCategory? presetCategory, Budget? existing}) async {
  var selectedCat = existing != null
      ? Store.categoryById(existing.categoryId)
      : presetCategory;
  final amountCtrl = TextEditingController(
      text: existing == null ? '' : groupPakistani(existing.limitAmount));
  final budgetedCats = Store.allBudgets.map((b) => b.categoryId).toSet();
  final expenseCats = Store.categoriesFor('expense');

  await showAppSheet<void>(
    context: context,
    title: existing == null ? 'Add a budget' : 'Edit budget',
    child: StatefulBuilder(
      builder: (ctx, setSheet) {
        final valid =
            parseAmount(amountCtrl.text) > 0 && selectedCat != null;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Category',
                style: AppText.label.copyWith(color: AppColors.inkSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in expenseCats)
                  ChoiceChip(
                    label: Text(c.name),
                    selected: selectedCat?.id == c.id,
                    onSelected: existing != null ||
                            (budgetedCats.contains(c.id) &&
                                presetCategory?.id != c.id)
                        ? null
                        : (_) => setSheet(() => selectedCat = c),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Monthly limit',
                style: AppText.label.copyWith(color: AppColors.inkSecondary)),
            const SizedBox(height: 8),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [amountGroupingFormatter],
              onChanged: (_) => setSheet(() {}),
              decoration: InputDecoration(
                prefixText: 'Rs ',
                hintText: '0',
                filled: true,
                fillColor: AppColors.surfaceInset,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none,
                ),
              ),
              style: AppText.bodyStrong,
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: existing == null ? 'Save budget' : 'Save changes',
              onTap: !valid
                  ? null
                  : () async {
                      final limit = parseAmount(amountCtrl.text);
                      if (existing != null) {
                        existing.limitAmount = limit;
                        await Store.saveBudget(existing);
                      } else {
                        final prior =
                            Store.budgetForCategory(selectedCat!.id);
                        await Store.saveBudget(Budget(
                          id: prior?.id ?? newId(),
                          categoryId: selectedCat!.id,
                          limitAmount: limit,
                        ));
                      }
                      if (ctx.mounted) {
                        Navigator.of(ctx).pop();
                        appSnack(context, 'Budget saved');
                      }
                    },
            ),
            if (existing != null) ...[
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () async {
                    final removed = existing;
                    await Store.deleteBudget(removed.id);
                    if (ctx.mounted) {
                      Navigator.of(ctx).pop();
                      appSnack(context, 'Budget removed',
                          onUndo: () => Store.saveBudget(removed));
                    }
                  },
                  child: Text('Delete budget',
                      style: AppText.body.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.expense)),
                ),
              ),
            ],
          ],
        );
      },
    ),
  );
}
