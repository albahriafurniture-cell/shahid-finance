import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/transfer_sheet.dart' show amountGroupingFormatter;

/// v1.1.5: Loans — a SEPARATE tracker, not wallet money.
/// Two directions: loans the user TOOK from people, and loans the
/// user GAVE to people. Creating a loan or a payment never touches
/// wallet balances, income totals, or expense totals.
class LoansScreen extends StatefulWidget {
  const LoansScreen({super.key});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

enum _LoansView { taken, given, people }

class _LoansScreenState extends State<LoansScreen> {
  _LoansView _view = _LoansView.taken;
  String? _personFilter;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: Store.changes,
      builder: (context, _, _) {
        final takenOut = Store.outstandingFor('taken');
        final givenOut = Store.outstandingFor('given');
        final people = Store.peopleSummaries();
        return GlassScaffold(
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: SubScreenHeader(title: 'Loans'),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    children: [
                      // Outstanding totals, both directions.
                      Container(
                        decoration: cardDecoration(),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: _totalCol(
                                'I OWE (TAKEN)',
                                takenOut,
                                AppColors.expense,
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 44,
                              color: AppColors.hairline,
                            ),
                            Expanded(
                              child: _totalCol(
                                'OWED TO ME (GIVEN)',
                                givenOut,
                                AppColors.brand,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _segmented(),
                      const SizedBox(height: 16),
                      if (_view == _LoansView.people)
                        _peopleBody(context, people)
                      else
                        _directionBody(context),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: PrimaryButton(
                    label: 'Add Loan',
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

  /// Taken / Given tab body: due-date sorted list, or a single
  /// person's loans when drilled in from the People view.
  Widget _directionBody(BuildContext context) {
    final direction = _view == _LoansView.taken ? 'taken' : 'given';
    final list = _personFilter != null
        ? Store.loansForPerson(_personFilter!)
            .where((l) => l.direction == direction)
            .toList()
        : Store.loansSortedByDue(direction);
    final emptyTitle = _personFilter != null
        ? 'No ${direction == 'taken' ? 'taken' : 'given'} loans'
        : (direction == 'taken' ? 'No loans taken' : 'No loans given');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_personFilter != null) ...[
          InkWell(
            onTap: () => setState(() => _personFilter = null),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.accentTint,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_back,
                      size: 16, color: AppColors.brand),
                  const SizedBox(width: 6),
                  Text('All people · $_personFilter',
                      style: AppText.label
                          .copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  const Icon(Icons.close,
                      size: 16, color: AppColors.inkSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (list.isEmpty)
          Container(
            decoration: cardDecoration(),
            child: EmptyState(
              icon: Icons.handshake_outlined,
              title: emptyTitle,
              body: _personFilter != null
                  ? '$_personFilter has no $direction loans yet.'
                  : (direction == 'taken'
                      ? 'People you borrowed from will appear here, with what is still left to repay.'
                      : 'People you lent to will appear here, with what they still owe you.'),
              actionLabel: 'Add a loan',
              onAction: () => _openForm(context),
            ),
          )
        else
          GroupCard(
            children: [
              for (final loan in list) _loanRow(context, loan),
            ],
          ),
      ],
    );
  }

  /// People view: one row per person, both directions summed.
  Widget _peopleBody(BuildContext context, List<PersonSummary> people) {
    if (people.isEmpty) {
      return Container(
        decoration: cardDecoration(),
        child: EmptyState(
          icon: Icons.group_outlined,
          title: 'No people yet',
          body:
              'Everyone you have udhar with will appear here, with what you owe and what is owed to you.',
          actionLabel: 'Add a loan',
          onAction: () => _openForm(context),
        ),
      );
    }
    return GroupCard(
      children: [
        for (final p in people) _personRow(context, p),
      ],
    );
  }

  Widget _personRow(BuildContext context, PersonSummary p) {
    return InkWell(
      onTap: () => setState(() {
        _personFilter = p.displayName;
        _view = p.takenOutstanding > 0 || p.takenTotal > 0
            ? _LoansView.taken
            : _LoansView.given;
      }),
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accentTint,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Center(
                child: Text(
                  p.displayName.isEmpty
                      ? '?'
                      : p.displayName[0].toUpperCase(),
                  style: AppText.bodyStrong.copyWith(
                      fontSize: 18, color: AppColors.brand),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(p.displayName,
                      style: AppText.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    '${p.loanCount} loan${p.loanCount == 1 ? '' : 's'}',
                    style: AppText.caption
                        .copyWith(color: AppColors.inkTertiary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (p.takenOutstanding > 0)
                  Text(
                    Store.hideAmounts
                        ? 'You owe ••••••'
                        : 'You owe ${fmtRs(p.takenOutstanding)}',
                    style: AppText.bodyStrong.copyWith(
                        fontSize: 13, color: AppColors.expense),
                  ),
                if (p.givenOutstanding > 0)
                  Text(
                    Store.hideAmounts
                        ? 'Owed ••••••'
                        : 'Owed ${fmtRs(p.givenOutstanding)}',
                    style: AppText.bodyStrong.copyWith(
                        fontSize: 13, color: AppColors.brand),
                  ),
                if (p.totalOutstanding == 0)
                  Text('Settled',
                      style: AppText.bodyStrong.copyWith(
                          fontSize: 13, color: AppColors.brand)),
              ],
            ),
          ],
        ),
      ),
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

  Widget _segmented() {
    Widget seg(String label, _LoansView view) {
      final selected = _view == view;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() {
            _view = view;
            _personFilter = null;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(label,
                style: AppText.label.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.inkSecondary,
                )),
          ),
        ),
      );
    }

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceInset,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(children: [
        seg('Taken', _LoansView.taken),
        seg('Given', _LoansView.given),
        seg('People', _LoansView.people),
      ]),
    );
  }

  Widget _loanRow(BuildContext context, Loan loan) {
    final remaining = Store.remainingFor(loan);
    final paid = Store.paidFor(loan.id);
    final settled = remaining <= 0;
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => LoanDetailScreen(loanId: loan.id))),
      child: Container(
        constraints: const BoxConstraints(minHeight: 68),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: loan.isTaken
                    ? AppColors.expenseTint
                    : AppColors.accentTint,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                loan.isTaken
                    ? Icons.south_west
                    : Icons.north_east,
                size: 22,
                color: loan.isTaken ? AppColors.expense : AppColors.brand,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(loan.personName,
                      style: AppText.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    '${fmtDate(DateTime.fromMillisecondsSinceEpoch(loan.dateMs))} · Paid ${Store.hideAmounts ? '••••••' : fmtRs(paid)} of ${Store.hideAmounts ? '••••••' : fmtRs(loan.principal)}',
                    style: AppText.caption
                        .copyWith(color: AppColors.inkTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (loan.dueDateMs > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Due ${fmtDate(DateTime.fromMillisecondsSinceEpoch(loan.dueDateMs))}',
                        style: AppText.caption.copyWith(
                            color: Store.isOverdue(loan)
                                ? AppColors.expense
                                : AppColors.inkTertiary,
                            fontWeight: Store.isOverdue(loan)
                                ? FontWeight.w700
                                : FontWeight.w400),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!settled && Store.isOverdue(loan))
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.expenseTint,
                      borderRadius:
                          BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text('OVERDUE',
                        style: AppText.label.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.expense)),
                  ),
                Text(
                  settled
                      ? 'Settled'
                      : (Store.hideAmounts
                          ? 'Rs •••••• left'
                          : '${fmtRs(remaining)} left'),
                  style: AppText.bodyStrong.copyWith(
                    fontSize: 14,
                    color: settled ? AppColors.brand : AppColors.expense,
                  ),
                ),
                if (!settled)
                  Text(loan.isTaken ? 'to repay' : 'to receive',
                      style: AppText.caption
                          .copyWith(color: AppColors.inkTertiary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openForm(BuildContext context, {Loan? existing}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LoanFormScreen(
        existing: existing,
        presetDirection: _view == _LoansView.given ? 'given' : 'taken',
      ),
    ));
  }
}

/// Loan detail: totals, payment history, add/edit/delete.
class LoanDetailScreen extends StatelessWidget {
  final String loanId;
  const LoanDetailScreen({super.key, required this.loanId});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: Store.changes,
      builder: (context, _, _) {
        final loan = Store.loans.get(loanId);
        if (loan == null) {
          return GlassScaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  children: [
                    const SubScreenHeader(title: 'Loan'),
                    const SizedBox(height: 40),
                    Text('This loan no longer exists.',
                        style: AppText.body
                            .copyWith(color: AppColors.inkSecondary)),
                  ],
                ),
              ),
            ),
          );
        }
        final paid = Store.paidFor(loan.id);
        final remaining = Store.remainingFor(loan);
        final settled = remaining <= 0;
        final payments = Store.paymentsFor(loan.id);
        return GlassScaffold(
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: SubScreenHeader(title: loan.personName),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    children: [
                      Container(
                        decoration: cardDecoration(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    loan.isTaken
                                        ? 'Borrowed from ${loan.personName}'
                                        : 'Lent to ${loan.personName}',
                                    style: AppText.bodyStrong,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: settled
                                        ? AppColors.accentTint
                                        : AppColors.expenseTint,
                                    borderRadius: BorderRadius.circular(
                                        AppRadius.pill),
                                  ),
                                  child: Text(
                                    settled ? 'Settled' : 'Open',
                                    style: AppText.label.copyWith(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: settled
                                          ? AppColors.brand
                                          : AppColors.expense,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _statRow(
                                'Total ${loan.isTaken ? 'taken' : 'given'}',
                                loan.principal),
                            const SizedBox(height: 8),
                            _statRow('Paid so far', paid),
                            const SizedBox(height: 8),
                            _statRow('Remaining', remaining,
                                highlight: !settled),
                            const Divider(
                                height: 24, color: AppColors.hairline),
                            _field('Date',
                                fmtDate(DateTime.fromMillisecondsSinceEpoch(
                                    loan.dateMs))),
                            if (loan.dueDateMs > 0)
                              _field(
                                  'Expected date',
                                  fmtDate(DateTime.fromMillisecondsSinceEpoch(
                                      loan.dueDateMs))),
                            if (loan.phone.isNotEmpty)
                              _field('Phone', loan.phone),
                            if (loan.note.isNotEmpty)
                              _field('Note', loan.note),
                            if (loan.witness.isNotEmpty)
                              _field('Witness', loan.witness),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text('Payment history',
                          style: AppText.label.copyWith(
                              color: AppColors.inkSecondary)),
                      const SizedBox(height: 4),
                      Text(
                        'Oldest first — remaining shown after each payment.',
                        style: AppText.caption
                            .copyWith(color: AppColors.inkTertiary),
                      ),
                      const SizedBox(height: 12),
                      if (payments.isEmpty)
                        Container(
                          decoration: cardDecoration(),
                          padding: const EdgeInsets.all(16),
                          child: Text('No payments yet',
                              style: AppText.label.copyWith(
                                  color: AppColors.inkSecondary)),
                        )
                      else
                        GroupCard(
                          children: [
                            for (final row
                                in Store.paymentTimeline(loan.id))
                              _timelineRow(context, row),
                          ],
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Column(
                    children: [
                      PrimaryButton(
                        label: settled
                            ? 'Settled — add payment anyway'
                            : 'Add Payment',
                        height: 58,
                        onTap: () => _addPayment(context, loan),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  Navigator.of(context).push(MaterialPageRoute(
                                      builder: (_) =>
                                          LoanFormScreen(existing: loan))),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                                side: const BorderSide(
                                    color: AppColors.hairline),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppRadius.md)),
                              ),
                              child: Text('Edit loan',
                                  style: AppText.body.copyWith(
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextButton(
                              onPressed: () async {
                                final ok = await showConfirmDialog(
                                  context: context,
                                  title: 'Delete this loan?',
                                  body:
                                      '${loan.personName} · ${fmtRs(loan.principal)}. Its payment history will be deleted too.',
                                  confirmLabel: 'Delete',
                                  destructive: true,
                                );
                                if (!ok || !context.mounted) return;
                                await Store.deleteLoan(loan.id);
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                              style: TextButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                                backgroundColor: AppColors.expenseTint,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppRadius.md)),
                              ),
                              child: Text('Delete',
                                  style: AppText.body.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.expense)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statRow(String label, int value, {bool highlight = false}) {
    return Row(
      children: [
        Text(label,
            style: AppText.label.copyWith(color: AppColors.inkSecondary)),
        const Spacer(),
        Text(
          Store.hideAmounts ? 'Rs ••••••' : fmtRs(value),
          style: AppText.bodyStrong.copyWith(
            color: highlight ? AppColors.expense : AppColors.ink,
          ),
        ),
      ],
    );
  }

  Widget _field(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label,
              style: AppText.label.copyWith(color: AppColors.inkSecondary)),
          const Spacer(),
          Flexible(
            child: Text(value,
                style: AppText.bodyStrong, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _timelineRow(BuildContext context, PaymentTimelineRow row) {
    final p = row.payment;
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(fmtRs(p.amount), style: AppText.bodyStrong),
                const SizedBox(height: 2),
                Text(
                  '${fmtDate(DateTime.fromMillisecondsSinceEpoch(p.dateMs))}${p.note.isNotEmpty ? ' · ${p.note}' : ''}',
                  style: AppText.caption
                      .copyWith(color: AppColors.inkTertiary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  Store.hideAmounts
                      ? 'Remaining after: ••••••'
                      : 'Remaining after: ${fmtRs(row.remainingAfter)}',
                  style: AppText.caption.copyWith(
                      color: AppColors.brand, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              final ok = await showConfirmDialog(
                context: context,
                title: 'Delete this payment?',
                body:
                    '${fmtRs(p.amount)} will be added back to the remaining balance.',
                confirmLabel: 'Delete',
                destructive: true,
              );
              if (ok) await Store.deletePayment(p.id);
            },
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.delete_outline,
                  size: 20, color: AppColors.expense),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addPayment(BuildContext context, Loan loan) async {
    final remaining = Store.remainingFor(loan);
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    var date = DateTime.now();
    await showAppSheet<void>(
      context: context,
      title: 'Add Payment',
      child: StatefulBuilder(
        builder: (ctx, setSheet) {
          final amount = parseAmount(amountCtrl.text);
          final over = amount > remaining;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Remaining: ${Store.hideAmounts ? '••••••' : fmtRs(remaining)}',
                style: AppText.label
                    .copyWith(color: AppColors.inkSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixText: 'Rs ',
                  filled: true,
                  fillColor: AppColors.surfaceInset,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: AppText.body,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  amountGroupingFormatter,
                ],
                onChanged: (_) => setSheet(() {}),
              ),
              if (over) ...[
                const SizedBox(height: 8),
                Text('Payment cannot be more than the remaining balance.',
                    style: AppText.caption
                        .copyWith(color: AppColors.expense)),
              ],
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setSheet(() => date = picked);
                },
                child: SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined,
                          size: 22, color: AppColors.inkTertiary),
                      const SizedBox(width: 12),
                      Text('Date', style: AppText.body),
                      const Spacer(),
                      Text(fmtDate(date), style: AppText.bodyStrong),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right,
                          size: 18, color: AppColors.inkTertiary),
                    ],
                  ),
                ),
              ),
              TextField(
                controller: noteCtrl,
                maxLength: 80,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'Note (optional)',
                  hintStyle: AppText.body
                      .copyWith(color: AppColors.inkTertiary),
                  border: InputBorder.none,
                ),
                style: AppText.body,
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Save Payment',
                onTap: (amount <= 0 || over)
                    ? null
                    : () async {
                        final now = DateTime.now();
                        await Store.savePayment(LoanPayment(
                          id: newId(),
                          loanId: loan.id,
                          amount: amount,
                          dateMs: DateTime(date.year, date.month, date.day,
                                  now.hour, now.minute)
                              .millisecondsSinceEpoch,
                          note: noteCtrl.text.trim(),
                          createdAtMs: now.millisecondsSinceEpoch,
                        ));
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Add / edit loan form.
class LoanFormScreen extends StatefulWidget {
  final Loan? existing;
  final String presetDirection;
  const LoanFormScreen({super.key, this.existing, this.presetDirection = 'taken'});

  @override
  State<LoanFormScreen> createState() => _LoanFormScreenState();
}

class _LoanFormScreenState extends State<LoanFormScreen> {
  late final TextEditingController _personCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _noteCtrl;
  late final TextEditingController _witnessCtrl;
  late String _direction;
  late DateTime _date;
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _personCtrl = TextEditingController(text: ex?.personName ?? '');
    _amountCtrl = TextEditingController(
        text: ex != null ? groupPakistani(ex.principal) : '');
    _phoneCtrl = TextEditingController(text: ex?.phone ?? '');
    _noteCtrl = TextEditingController(text: ex?.note ?? '');
    _witnessCtrl = TextEditingController(text: ex?.witness ?? '');
    _direction = ex?.direction ?? widget.presetDirection;
    _date = ex != null
        ? DateTime.fromMillisecondsSinceEpoch(ex.dateMs)
        : DateTime.now();
    _dueDate = ex != null && ex.dueDateMs > 0
        ? DateTime.fromMillisecondsSinceEpoch(ex.dueDateMs)
        : null;
  }

  @override
  void dispose() {
    _personCtrl.dispose();
    _amountCtrl.dispose();
    _phoneCtrl.dispose();
    _noteCtrl.dispose();
    _witnessCtrl.dispose();
    super.dispose();
  }

  bool get _valid =>
      _personCtrl.text.trim().isNotEmpty && parseAmount(_amountCtrl.text) > 0;

  Future<void> _save() async {
    if (!_valid) return;
    final now = DateTime.now();
    final ex = widget.existing;
    final loan = Loan(
      id: ex?.id ?? newId(),
      personName: _personCtrl.text.trim(),
      direction: _direction,
      principal: parseAmount(_amountCtrl.text),
      dateMs: DateTime(_date.year, _date.month, _date.day, now.hour,
              now.minute)
          .millisecondsSinceEpoch,
      phone: _phoneCtrl.text.trim(),
      note: _noteCtrl.text.trim(),
      dueDateMs: _dueDate == null
          ? 0
          : DateTime(_dueDate!.year, _dueDate!.month, _dueDate!.day)
              .millisecondsSinceEpoch,
      witness: _witnessCtrl.text.trim(),
      createdAtMs: ex?.createdAtMs ?? now.millisecondsSinceEpoch,
    );
    await Store.saveLoan(loan);
    if (!mounted) return;
    Navigator.of(context).pop();
    appSnack(context,
        ex == null ? 'Loan added' : 'Loan updated');
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: SubScreenHeader(
                  title: widget.existing == null ? 'Add Loan' : 'Edit Loan'),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                children: [
                  _segmented(),
                  const SizedBox(height: 24),
                  Text('Person',
                      style: AppText.label
                          .copyWith(color: AppColors.inkSecondary)),
                  const SizedBox(height: 8),
                  _field(_personCtrl, 'Name', TextInputType.name),
                  const SizedBox(height: 20),
                  Text('Amount',
                      style: AppText.label
                          .copyWith(color: AppColors.inkSecondary)),
                  const SizedBox(height: 8),
                  _field(_amountCtrl, 'Rs 0', TextInputType.number,
                      amount: true, onChanged: () => setState(() {})),
                  const SizedBox(height: 20),
                  Text('Date',
                      style: AppText.label
                          .copyWith(color: AppColors.inkSecondary)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                    child: Container(
                      height: 56,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceInset,
                        borderRadius:
                            BorderRadius.circular(AppRadius.md),
                      ),
                      child: Text(fmtDate(_date), style: AppText.body),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Expected date (optional)',
                      style: AppText.label
                          .copyWith(color: AppColors.inkSecondary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _dueDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setState(() => _dueDate = picked);
                            }
                          },
                          child: Container(
                            height: 56,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16),
                            alignment: Alignment.centerLeft,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceInset,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                            ),
                            child: Text(
                              _dueDate == null
                                  ? 'When should it be repaid?'
                                  : fmtDate(_dueDate!),
                              style: AppText.body.copyWith(
                                  color: _dueDate == null
                                      ? AppColors.inkTertiary
                                      : AppColors.ink),
                            ),
                          ),
                        ),
                      ),
                      if (_dueDate != null) ...[
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => setState(() => _dueDate = null),
                          borderRadius:
                              BorderRadius.circular(AppRadius.md),
                          child: Container(
                            height: 56,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceInset,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                            ),
                            child: Text('Clear',
                                style: AppText.body.copyWith(
                                    color: AppColors.expense)),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('Phone (optional)',
                      style: AppText.label
                          .copyWith(color: AppColors.inkSecondary)),
                  const SizedBox(height: 8),
                  _field(_phoneCtrl, '03xx xxxxxxx', TextInputType.phone),
                  const SizedBox(height: 20),
                  Text('Note (optional)',
                      style: AppText.label
                          .copyWith(color: AppColors.inkSecondary)),
                  const SizedBox(height: 8),
                  _field(_noteCtrl, 'Add a note', TextInputType.text),
                  const SizedBox(height: 20),
                  Text('Witness (optional)',
                      style: AppText.label
                          .copyWith(color: AppColors.inkSecondary)),
                  const SizedBox(height: 8),
                  _field(_witnessCtrl, 'Gawah ka naam',
                      TextInputType.name),
                  const SizedBox(height: 8),
                  Text(
                    'Loans never change your wallet balances or income / expense totals.',
                    style: AppText.caption
                        .copyWith(color: AppColors.inkTertiary),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: PrimaryButton(
                label: widget.existing == null ? 'Save Loan' : 'Save Changes',
                height: 58,
                onTap: _valid ? _save : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _segmented() {
    Widget seg(String label, String direction) {
      final selected = _direction == direction;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _direction = direction),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(label,
                style: AppText.label.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.inkSecondary,
                )),
          ),
        ),
      );
    }

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceInset,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(children: [
        seg('I took a loan', 'taken'),
        seg('I gave a loan', 'given'),
      ]),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, TextInputType type,
      {bool amount = false, VoidCallback? onChanged}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      maxLength: amount ? null : 80,
      decoration: InputDecoration(
        counterText: '',
        prefixText: amount ? 'Rs ' : null,
        hintText: hint,
        hintStyle: AppText.body.copyWith(color: AppColors.inkTertiary),
        filled: true,
        fillColor: AppColors.surfaceInset,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
      ),
      style: AppText.body,
      inputFormatters: amount
          ? [
              FilteringTextInputFormatter.digitsOnly,
              amountGroupingFormatter,
            ]
          : null,
      onChanged: (_) => onChanged?.call(),
    );
  }
}
