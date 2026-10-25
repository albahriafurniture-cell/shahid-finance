import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/wallet_logo.dart';
import 'add_transaction.dart';

/// Transactions (master Screen 5 + transactions spec §1): search, month
/// strip, chips, staged filter sheet, date-grouped list with running
/// balances, swipe edit/delete with Undo, detail sheet.
class TransactionsScreen extends StatefulWidget {
  final String? presetWalletId;
  const TransactionsScreen({super.key, this.presetWalletId});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _searchOpen = false;
  final _searchCtrl = TextEditingController();
  String _query = '';

  // Applied filter state (chips + sheet share it).
  String _type = 'all'; // all | income | expense
  final Set<String> _walletIds = {};
  int? _amountMin;
  int? _amountMax;
  DateTime? _rangeFrom;
  DateTime? _rangeTo;

  @override
  void initState() {
    super.initState();
    if (widget.presetWalletId != null) {
      _walletIds.add(widget.presetWalletId!);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool get _filtersActive =>
      _type != 'all' ||
      _walletIds.isNotEmpty ||
      _amountMin != null ||
      _amountMax != null ||
      _rangeFrom != null ||
      _rangeTo != null;

  void _clearAll() {
    setState(() {
      _type = 'all';
      _walletIds.clear();
      _amountMin = null;
      _amountMax = null;
      _rangeFrom = null;
      _rangeTo = null;
      _query = '';
      _searchCtrl.clear();
    });
  }

  bool _matches(MoneyTxn t) {
    if (_rangeFrom == null && _rangeTo == null) {
      if (t.date.year != _month.year || t.date.month != _month.month) {
        return false;
      }
    } else {
      final day = DateTime(t.date.year, t.date.month, t.date.day);
      if (_rangeFrom != null && day.isBefore(_rangeFrom!)) return false;
      if (_rangeTo != null && day.isAfter(_rangeTo!)) return false;
    }
    if (_type == 'income' && !t.isIncome) return false;
    if (_type == 'expense' && !t.isExpense) return false;
    if (_walletIds.isNotEmpty &&
        !_walletIds.contains(t.walletId) &&
        !_walletIds.contains(t.toWalletId)) {
      return false;
    }
    if (_amountMin != null && t.amount.abs() < _amountMin!) return false;
    if (_amountMax != null && t.amount.abs() > _amountMax!) return false;
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      final cat = Store.categoryById(t.categoryId)?.name ?? '';
      final wallet = Store.walletById(t.walletId)?.name ?? '';
      final toWallet = Store.walletById(t.toWalletId)?.name ?? '';
      final hay = '${t.note} $cat $wallet $toWallet'.toLowerCase();
      if (!hay.contains(q)) return false;
    }
    return true;
  }

  int _dayNet(List<MoneyTxn> txns) {
    var net = 0;
    for (final t in txns) {
      if (t.isIncome) net += t.amount;
      if (t.isExpense) net -= t.amount;
      if (t.isAdjustment) net += t.amount;
    }
    return net;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: Store.changes,
      builder: (context, _, _) {
        final monthTxns = Store.txnsInMonth(_month.year, _month.month);
        final inSum = Store.sumIn(monthTxns);
        final outSum = Store.sumOut(monthTxns);
        final net = inSum - outSum;

        final filtered = Store.allTxnsDesc.where(_matches).toList();
        final groups = <DateTime, List<MoneyTxn>>{};
        for (final t in filtered) {
          final day = DateTime(t.date.year, t.date.month, t.date.day);
          groups.putIfAbsent(day, () => []).add(t);
        }
        final days = groups.keys.toList()..sort((a, b) => b.compareTo(a));
        final running = Store.runningBalances();
        final isCurrentMonth = _month.year == DateTime.now().year &&
            _month.month == DateTime.now().month;

        return Column(
          children: [
            // Top clearance is status-bar height (MainShell SafeArea) + 12,
            // so "Transactions" never collides with the status bar (v1.1.1).
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  Expanded(child: Text('Transactions', style: AppText.h1)),
                  CircleIconButton(
                    icon: Icons.search,
                    onTap: () => setState(() {
                      _searchOpen = !_searchOpen;
                      if (!_searchOpen) {
                        _query = '';
                        _searchCtrl.clear();
                      }
                    }),
                  ),
                  const SizedBox(width: 8),
                  CircleIconButton(
                    icon: Icons.tune,
                    badgeDot: _filtersActive,
                    onTap: _openFilterSheet,
                  ),
                ],
              ),
            ),
            if (_searchOpen)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceInset,
                    borderRadius:
                        BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search,
                          size: 20, color: AppColors.inkTertiary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'Search notes, categories…',
                            hintStyle: AppText.body.copyWith(
                                color: AppColors.inkTertiary),
                            border: InputBorder.none,
                          ),
                          style: AppText.body,
                          onChanged: (v) => setState(() => _query = v.trim()),
                        ),
                      ),
                      if (_query.isNotEmpty)
                        GestureDetector(
                          onTap: () => setState(() {
                            _query = '';
                            _searchCtrl.clear();
                          }),
                          child: const Icon(Icons.close,
                              size: 18, color: AppColors.inkSecondary),
                        ),
                    ],
                  ),
                ),
              ),
            // Month selector
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  CircleIconButton(
                    icon: Icons.chevron_left,
                    size: 36,
                    onTap: () => setState(() => _month =
                        DateTime(_month.year, _month.month - 1)),
                  ),
                  Expanded(
                    child: Text(fmtMonth(_month),
                        style: AppText.bodyStrong.copyWith(fontSize: 15),
                        textAlign: TextAlign.center),
                  ),
                  CircleIconButton(
                    icon: Icons.chevron_right,
                    size: 36,
                    onTap: isCurrentMonth
                        ? null
                        : () => setState(() => _month =
                            DateTime(_month.year, _month.month + 1)),
                  ),
                ],
              ),
            ),
            // Month summary strip
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: insetDecoration(radius: AppRadius.md),
                child: Row(
                  children: [
                    _stripCol('IN', '+${fmtRs(inSum)}', AppColors.brand,
                        dot: AppColors.brand),
                    _stripDivider(),
                    _stripCol('OUT', '−${fmtRs(outSum)}', AppColors.expense,
                        dot: AppColors.expense),
                    _stripDivider(),
                    _stripCol(
                      'NET',
                      net < 0 ? '−${fmtRs(-net)}' : fmtRs(net),
                      net < 0 ? AppColors.expense : AppColors.ink,
                      bold: true,
                    ),
                  ],
                ),
              ),
            ),
            // Filter chips
            SizedBox(
              height: 38 + 12,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                children: [
                  _chip('All', _type == 'all',
                      () => setState(() => _type = 'all')),
                  _chip('Income', _type == 'income',
                      () => setState(() => _type = 'income')),
                  _chip('Expense', _type == 'expense',
                      () => setState(() => _type = 'expense')),
                  const SizedBox(width: 8),
                  for (final w in Store.activeWallets)
                    _chip(w.name, _walletIds.contains(w.id), () {
                      setState(() {
                        if (_walletIds.contains(w.id)) {
                          _walletIds.remove(w.id);
                        } else {
                          _walletIds.add(w.id);
                        }
                      });
                    }),
                ],
              ),
            ),
            if (_filtersActive || _query.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _resultsCaption(filtered.length),
                        style: AppText.label
                            .copyWith(color: AppColors.inkSecondary),
                      ),
                    ),
                    GhostButton(label: 'Clear all', onTap: _clearAll),
                  ],
                ),
              ),
            Expanded(
              child: filtered.isEmpty
                  ? _emptyState(monthTxns.isEmpty)
                  : CustomScrollView(
                      slivers: [
                        for (final day in days) ...[
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: _DayHeaderDelegate(
                              label: dayLabel(day),
                              subLabel: (dayLabel(day) == 'Today' ||
                                      dayLabel(day) == 'Yesterday')
                                  ? fmtDate(day)
                                  : null,
                              net: _dayNet(groups[day]!),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 0, 20, 0),
                              child: GroupCard(
                                children: [
                                  for (final t in groups[day]!)
                                    _swipeableRow(context, t,
                                        runningBalance: running[t.id]),
                                ],
                              ),
                            ),
                          ),
                          const SliverToBoxAdapter(
                              child: SizedBox(height: 16)),
                        ],
                        SliverToBoxAdapter(
                          child: Padding(
                            padding:
                                const EdgeInsets.only(top: 8, bottom: 120),
                            child: Text(
                              "You've reached the start · ${Store.txns.length} transactions",
                              style: AppText.caption
                                  .copyWith(color: AppColors.inkTertiary),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  String _resultsCaption(int count) {
    if (_query.isNotEmpty) return '$count results for "$_query"';
    if (_rangeFrom != null || _rangeTo != null) {
      final from = _rangeFrom != null ? fmtDate(_rangeFrom!) : 'Start';
      final to = _rangeTo != null ? fmtDate(_rangeTo!) : 'Now';
      var base = '$count results · $from – $to';
      if (_amountMin != null || _amountMax != null) {
        base +=
            ' · Rs ${_amountMin != null ? groupPakistani(_amountMin!) : '0'}–${_amountMax != null ? groupPakistani(_amountMax!) : '∞'}';
      }
      return base;
    }
    var base = '$count results · ${fmtMonth(_month)}';
    if (_amountMin != null || _amountMax != null) {
      base +=
          ' · Rs ${_amountMin != null ? groupPakistani(_amountMin!) : '0'}–${_amountMax != null ? groupPakistani(_amountMax!) : '∞'}';
    }
    return base;
  }

  Widget _emptyState(bool monthEmpty) {
    if (_query.isNotEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        title: 'No results for "$_query"',
        body: 'Check the spelling, or search by category or wallet instead.',
        actionLabel: 'Clear search',
        onAction: _clearAll,
      );
    }
    if (_filtersActive) {
      return EmptyState(
        icon: Icons.filter_alt_off_outlined,
        title: 'Nothing matches these filters',
        body: 'Try a different wallet or clear the filters to see everything.',
        actionLabel: 'Clear all filters',
        onAction: _clearAll,
      );
    }
    return EmptyState(
      icon: Icons.account_balance_wallet_outlined,
      title: 'No transactions in ${fmtMonth(_month)}',
      body: 'Your income and expenses for this month will appear here.',
      actionLabel: monthEmpty ? 'Add a transaction' : null,
      onAction: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const AddTransactionScreen())),
    );
  }

  Widget _swipeableRow(BuildContext context, MoneyTxn t,
      {int? runningBalance}) {
    final editable = t.isIncome || t.isExpense;
    return Dismissible(
      key: ValueKey(t.id),
      direction: editable
          ? DismissDirection.horizontal
          : DismissDirection.endToStart,
      background: Container(
        color: AppColors.accentTint,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Row(
          children: [
            Icon(Icons.edit, size: 24, color: AppColors.brandDeep),
            SizedBox(width: 8),
            Text('Edit',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandDeep)),
          ],
        ),
      ),
      secondaryBackground: Container(
        color: AppColors.expense,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Delete',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            SizedBox(width: 8),
            Icon(Icons.delete_outline, size: 24, color: Colors.white),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => AddTransactionScreen(existing: t)));
          return false;
        }
        final ok = await showConfirmDialog(
          context: context,
          title: 'Delete this transaction?',
          body:
              '${t.note.isNotEmpty ? t.note : (Store.categoryById(t.categoryId)?.name ?? 'Transaction')} · ${fmtSigned(t.amount.abs(), income: t.isIncome)}',
          confirmLabel: 'Delete',
          destructive: true,
        );
        if (ok) {
          final deleted = await Store.deleteTxn(t.id);
          if (deleted != null && context.mounted) {
            appSnack(context, 'Transaction deleted',
                onUndo: () => Store.saveTxn(deleted));
          }
        }
        return false; // row removal is driven by the store change
      },
      child: TxnRow(
        txn: t,
        runningBalance: runningBalance,
        showRunningBalance: true,
        onTap: () => showTxnDetailSheet(context, t),
      ),
    );
  }

  Widget _stripCol(String label, String value, Color color,
      {Color? dot, bool bold = false}) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (dot != null) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration:
                      BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
              ],
              Text(label,
                  style: AppText.micro
                      .copyWith(color: AppColors.inkTertiary)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value,
              style: AppText.tab(AppText.bodyStrong.copyWith(
                fontSize: 15,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
                color: Store.hideAmounts ? AppColors.ink : color,
              ))),
        ],
      ),
    );
  }

  Widget _stripDivider() {
    return Container(width: 1, height: 24, color: AppColors.hairline);
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.brandDeep : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: selected
                ? null
                : Border.all(color: AppColors.hairline),
          ),
          child: Text(label,
              style: AppText.label.copyWith(
                color: selected ? Colors.white : AppColors.inkSecondary,
              )),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ filter sheet
  Future<void> _openFilterSheet() async {
    var type = _type;
    final wallets = {..._walletIds};
    final minCtrl = TextEditingController(
        text: _amountMin != null ? groupPakistani(_amountMin!) : '');
    final maxCtrl = TextEditingController(
        text: _amountMax != null ? groupPakistani(_amountMax!) : '');
    var from = _rangeFrom;
    var to = _rangeTo;

    int countFor(String ty, Set<String> ws, int? mn, int? mx,
        DateTime? f, DateTime? tt) {
      final savedType = _type;
      final savedW = {..._walletIds};
      final sMn = _amountMin, sMx = _amountMax;
      final sF = _rangeFrom, sT = _rangeTo;
      _type = ty;
      _walletIds
        ..clear()
        ..addAll(ws);
      _amountMin = mn;
      _amountMax = mx;
      _rangeFrom = f;
      _rangeTo = tt;
      final n = Store.allTxnsDesc.where(_matches).length;
      _type = savedType;
      _walletIds
        ..clear()
        ..addAll(savedW);
      _amountMin = sMn;
      _amountMax = sMx;
      _rangeFrom = sF;
      _rangeTo = sT;
      return n;
    }

    await showAppSheet<void>(
      context: context,
      title: 'Filters',
      child: StatefulBuilder(
        builder: (ctx, setSheet) {
          final mn = minCtrl.text.isEmpty ? null : parseAmount(minCtrl.text);
          final mx = maxCtrl.text.isEmpty ? null : parseAmount(maxCtrl.text);
          final minGtMax = mn != null && mx != null && mn > mx;
          final count = countFor(type, wallets, mn, mx, from, to);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetLabel('TYPE'),
              const SizedBox(height: 8),
              Container(
                height: 44,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceInset,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  children: [
                    for (final (label, val) in [
                      ('All', 'all'),
                      ('Income', 'income'),
                      ('Expense', 'expense'),
                    ])
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setSheet(() => type = val),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: type == val
                                  ? AppColors.surface
                                  : Colors.transparent,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                              boxShadow:
                                  type == val ? AppShadows.card : null,
                            ),
                            child: Text(label,
                                style: AppText.label.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: type == val
                                        ? AppColors.ink
                                        : AppColors.inkSecondary)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _sheetLabel('WALLETS'),
              const SizedBox(height: 8),
              for (final w in Store.activeWallets)
                InkWell(
                  onTap: () => setSheet(() {
                    if (wallets.contains(w.id)) {
                      wallets.remove(w.id);
                    } else {
                      wallets.add(w.id);
                    }
                  }),
                  child: SizedBox(
                    height: 56,
                    child: Row(
                      children: [
                        WalletAvatar(type: w.type, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text(w.name, style: AppText.bodyStrong)),
                        AmountText(
                          value: Store.balanceOf(w.id),
                          style: AppText.label
                              .copyWith(color: AppColors.inkTertiary),
                          neutral: true,
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: wallets.contains(w.id)
                                ? AppColors.brand
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(7),
                            border: wallets.contains(w.id)
                                ? null
                                : Border.all(
                                    color: AppColors.hairline, width: 1.5),
                          ),
                          child: wallets.contains(w.id)
                              ? const Icon(Icons.check,
                                  size: 16, color: Colors.white)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              _sheetLabel('AMOUNT (RS)'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                      child: _amountField('Min', minCtrl,
                          () => setSheet(() {}))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _amountField('Max', maxCtrl,
                          () => setSheet(() {}))),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                minGtMax
                    ? "Min can't be more than Max"
                    : 'Leave empty for no limit.',
                style: AppText.caption.copyWith(
                    color: minGtMax
                        ? AppColors.expense
                        : AppColors.inkTertiary),
              ),
              const SizedBox(height: 24),
              _sheetLabel('DATE RANGE'),
              const SizedBox(height: 8),
              _dateRow('From', from, () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: from ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setSheet(() => from = picked);
              }, clear: from == null
                  ? null
                  : () => setSheet(() => from = null)),
              _dateRow('To', to, () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: to ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setSheet(() => to = picked);
              }, clear: to == null
                  ? null
                  : () => setSheet(() => to = null)),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Show $count results',
                onTap: minGtMax
                    ? null
                    : () {
                        setState(() {
                          _type = type;
                          _walletIds
                            ..clear()
                            ..addAll(wallets);
                          _amountMin = mn;
                          _amountMax = mx;
                          _rangeFrom = from;
                          _rangeTo = to;
                        });
                        Navigator.of(ctx).pop();
                      },
              ),
              Center(
                child: GhostButton(
                  label: 'Cancel',
                  onTap: () => Navigator.of(ctx).pop(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sheetLabel(String text) {
    return Text(text,
        style: AppText.micro.copyWith(
            fontWeight: FontWeight.w700, color: AppColors.inkTertiary));
  }

  Widget _amountField(
      String label, TextEditingController ctrl, VoidCallback onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppText.label.copyWith(color: AppColors.inkSecondary)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          onChanged: (_) => onChanged(),
          decoration: InputDecoration(
            prefixText: 'Rs ',
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
        ),
      ],
    );
  }

  Widget _dateRow(String label, DateTime? value, VoidCallback onTap,
      {VoidCallback? clear}) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            SizedBox(
                width: 52,
                child: Text(label,
                    style: AppText.label
                        .copyWith(color: AppColors.inkSecondary))),
            Expanded(
              child: Text(value != null ? fmtDate(value) : 'Any date',
                  style: AppText.bodyStrong),
            ),
            if (clear != null)
              GestureDetector(
                onTap: clear,
                child: const Icon(Icons.close,
                    size: 18, color: AppColors.inkTertiary),
              )
            else
              const Icon(Icons.chevron_right,
                  size: 18, color: AppColors.inkTertiary),
          ],
        ),
      ),
    );
  }
}

class _DayHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String label;
  final String? subLabel;
  final int net;
  _DayHeaderDelegate({required this.label, this.subLabel, required this.net});

  @override
  double get minExtent => 32;
  @override
  double get maxExtent => 32;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.canvas,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: Alignment.center,
      child: Row(
        children: [
          Text(label, style: AppText.label.copyWith(fontSize: 13)),
          if (subLabel != null) ...[
            const SizedBox(width: 8),
            Text(subLabel!,
                style:
                    AppText.caption.copyWith(color: AppColors.inkTertiary)),
          ],
          const Spacer(),
          Text(
            net == 0
                ? 'Rs 0'
                : (net < 0 ? '−${fmtRs(-net)}' : '+${fmtRs(net)}'),
            style: AppText.tab(AppText.label.copyWith(
              fontSize: 13,
              color: net == 0
                  ? AppColors.inkTertiary
                  : net < 0
                      ? AppColors.expense
                      : AppColors.brand,
            )),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _DayHeaderDelegate oldDelegate) =>
      oldDelegate.label != label || oldDelegate.net != net;
}

/// Transaction detail bottom sheet (spec §1.9): all fields, Edit + Delete.
Future<void> showTxnDetailSheet(BuildContext context, MoneyTxn t) async {
  final cat = Store.categoryById(t.categoryId);
  final wallet = Store.walletById(t.walletId);
  final running = Store.runningBalances()[t.id];
  final editable = t.isIncome || t.isExpense;
  await showAppSheet<void>(
    context: context,
    title: '',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (cat != null) CategoryTile(category: cat, size: 56),
        const SizedBox(height: 12),
        Text(
          t.note.isNotEmpty ? t.note : (cat?.name ?? 'Transaction'),
          style: AppText.h2.copyWith(fontSize: 17),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          Store.hideAmounts
              ? 'Rs ••••••'
              : (t.isTransfer || t.isAdjustment
                  ? fmtRs(t.amount.abs())
                  : fmtSigned(t.amount, income: t.isIncome)),
          style: AppText.amountXL.copyWith(
            color: t.isIncome
                ? AppColors.brand
                : t.isExpense
                    ? AppColors.expense
                    : AppColors.ink,
          ),
        ),
        const SizedBox(height: 16),
        const Divider(height: 1, color: AppColors.hairline),
        _detailField('Wallet', wallet?.name ?? '—'),
        if (t.isTransfer)
          _detailField('To wallet',
              Store.walletById(t.toWalletId)?.name ?? '—'),
        _detailField('Date', '${fmtDate(t.date)} · ${fmtTime(t.date)}'),
        if (cat != null) _detailField('Category', cat.name),
        _detailField('Note', t.note.isEmpty ? '—' : t.note),
        if (running != null)
          _detailField(
              'Balance after', Store.hideAmounts ? '••••••' : fmtRs(running)),
        const SizedBox(height: 16),
        if (editable)
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => AddTransactionScreen(existing: t)));
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    side: const BorderSide(color: AppColors.hairline),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.md)),
                  ),
                  child: Text('Edit',
                      style: AppText.body
                          .copyWith(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextButton(
                  onPressed: () async {
                    final ok = await showConfirmDialog(
                      context: context,
                      title: 'Delete this transaction?',
                      body:
                          '${t.note.isNotEmpty ? t.note : (cat?.name ?? 'Transaction')} · ${fmtSigned(t.amount.abs(), income: t.isIncome)}',
                      confirmLabel: 'Delete',
                      destructive: true,
                    );
                    if (!ok) return;
                    final deleted = await Store.deleteTxn(t.id);
                    if (deleted != null && context.mounted) {
                      Navigator.of(context).pop();
                      appSnack(context, 'Transaction deleted',
                          onUndo: () => Store.saveTxn(deleted));
                    }
                  },
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: AppColors.expenseTint,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.md)),
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
  );
}

Widget _detailField(String label, String value) {
  return SizedBox(
    height: 52,
    child: Row(
      children: [
        Text(label,
            style: AppText.label.copyWith(color: AppColors.inkSecondary)),
        const Spacer(),
        Text(value, style: AppText.bodyStrong),
      ],
    ),
  );
}
