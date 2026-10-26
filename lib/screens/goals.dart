import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/transfer_sheet.dart' show amountGroupingFormatter;

/// v1.1.6: Savings Goals — a SEPARATE tracker, like loans. Creating a
/// goal or adding saved money to it never touches wallet balances,
/// income totals, or expense totals; amounts live only in the goals
/// box (and ride in the cloud snapshot).
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: Store.changes,
      builder: (context, _, _) {
        final list = Store.allGoals;
        final totalSaved =
            list.fold(0, (s, g) => s + g.savedAmount);
        final totalTarget =
            list.fold(0, (s, g) => s + g.targetAmount);
        return GlassScaffold(
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: SubScreenHeader(title: 'Goals'),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    children: [
                      Container(
                        decoration: cardDecoration(),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: _totalCol(
                                  'SAVED', totalSaved, AppColors.brand),
                            ),
                            Container(
                              width: 1,
                              height: 44,
                              color: AppColors.hairline,
                            ),
                            Expanded(
                              child: _totalCol('TARGET', totalTarget,
                                  AppColors.ink),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (list.isEmpty)
                        Container(
                          decoration: cardDecoration(),
                          child: EmptyState(
                            icon: Icons.flag_outlined,
                            title: 'No goals yet',
                            body:
                                'Set a savings target — a new phone, a trip, anything — and watch it fill up.',
                            actionLabel: 'Add a goal',
                            onAction: () => _openForm(context),
                          ),
                        )
                      else
                        for (final goal in list) ...[
                          _goalCard(context, goal),
                          const SizedBox(height: 12),
                        ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: PrimaryButton(
                    label: 'Add Goal',
                    height: 58,
                    onTap: () => _openForm(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _totalCol(String label, int value, Color color) {
    return Column(
      children: [
        Text(label,
            style: AppText.micro.copyWith(color: AppColors.inkTertiary)),
        const SizedBox(height: 4),
        Text(Store.hideAmounts ? 'Rs ••••••' : fmtRs(value),
            style: AppText.bodyStrong.copyWith(fontSize: 17, color: color)),
      ],
    );
  }

  Widget _goalCard(BuildContext context, SavingsGoal goal) {
    return Container(
      decoration: cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(goal.name,
                    style: AppText.bodyStrong.copyWith(fontSize: 16)),
              ),
              if (goal.isComplete)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text('Done',
                      style: AppText.label.copyWith(
                          fontSize: 11, color: AppColors.canvas)),
                ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _confirmDelete(context, goal),
                child: const Icon(Icons.delete_outline,
                    size: 20, color: AppColors.inkSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: goal.progress,
              minHeight: 10,
              backgroundColor: AppColors.surfaceInset,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.accent),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  Store.hideAmounts
                      ? 'Saved Rs •••••• of Rs ••••••'
                      : 'Saved ${fmtRs(goal.savedAmount)} of ${fmtRs(goal.targetAmount)}',
                  style:
                      AppText.caption.copyWith(color: AppColors.inkSecondary),
                ),
              ),
              Text(
                goal.isComplete
                    ? 'Complete'
                    : '${fmtRs(goal.remaining)} left',
                style: AppText.label.copyWith(color: AppColors.accent),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: GhostButton(
              label: 'Add money',
              onTap: () => _openAddMoney(context, goal),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openForm(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.deepPurple,
        title: const Text('New goal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Goal name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: targetCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                amountGroupingFormatter,
              ],
              decoration:
                  const InputDecoration(labelText: 'Target amount (Rs)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final name = nameCtrl.text.trim();
    final target = parseAmount(targetCtrl.text);
    if (name.isEmpty || target <= 0) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await Store.saveGoal(SavingsGoal(
      id: newId(),
      name: name,
      targetAmount: target,
      createdAtMs: now,
    ));
  }

  Future<void> _openAddMoney(BuildContext context, SavingsGoal goal) async {
    final amountCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.deepPurple,
        title: Text('Add money to ${goal.name}'),
        content: TextField(
          controller: amountCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            amountGroupingFormatter,
          ],
          decoration: const InputDecoration(labelText: 'Amount (Rs)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final amount = parseAmount(amountCtrl.text);
    if (amount <= 0) return;
    await Store.addToGoal(goal.id, amount);
  }

  Future<void> _confirmDelete(BuildContext context, SavingsGoal goal) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.deepPurple,
        title: Text('Delete ${goal.name}?'),
        content: const Text('This goal and its saved progress will be gone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await Store.deleteGoal(goal.id);
  }
}
