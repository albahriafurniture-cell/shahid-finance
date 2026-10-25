import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../utils/icons.dart';
import '../widgets/common.dart';
import '../widgets/transfer_sheet.dart';
import 'transactions.dart';

/// Wallets (transactions/wallets spec §2): total hero, transfer entry,
/// wallet cards (default first, then balance desc), add wallet, detail.
class WalletsScreen extends StatelessWidget {
  const WalletsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      body: SafeArea(
        child: ValueListenableBuilder<int>(
          valueListenable: Store.changes,
          builder: (context, _, _) {
            final wallets = Store.activeWallets;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                SubScreenHeader(
                  title: 'Wallets',
                  trailing: CircleIconButton(
                    icon: Icons.add,
                    onTap: () => showAddWalletSheet(context),
                  ),
                ),
                const SizedBox(height: 16),
                HeroCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('TOTAL BALANCE',
                              style: AppText.micro.copyWith(
                                  color:
                                      Colors.white.withValues(alpha: 0.7))),
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
                            .copyWith(color: Colors.white),
                        neutral: true,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Across ${wallets.length} wallet${wallets.length == 1 ? '' : 's'}',
                        style: AppText.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Transfer entry card
                GestureDetector(
                  onTap: () => showTransferSheet(context),
                  child: Container(
                    height: 64,
                    decoration: cardDecoration(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.accentTint,
                            borderRadius:
                                BorderRadius.circular(AppRadius.sm),
                          ),
                          child: const Icon(Icons.swap_horiz,
                              size: 22, color: AppColors.brandDeep),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Transfer between wallets',
                                  style: AppText.title),
                              const SizedBox(height: 2),
                              Text('Move money without changing your total',
                                  style: AppText.caption.copyWith(
                                      color: AppColors.inkTertiary)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            size: 18, color: AppColors.inkTertiary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('MY WALLETS',
                    style: AppText.micro
                        .copyWith(color: AppColors.inkTertiary)),
                const SizedBox(height: 12),
                for (final w in wallets) ...[
                  _walletCard(context, w),
                  const SizedBox(height: 12),
                ],
                // Add wallet dashed row
                GestureDetector(
                  onTap: () => showAddWalletSheet(context),
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      color:
                          AppColors.surfaceInset.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                          color: AppColors.hairlineDark, width: 1.5),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: AppColors.hairline),
                          ),
                          child: const Icon(Icons.add,
                              size: 22, color: AppColors.brandDeep),
                        ),
                        const SizedBox(width: 12),
                        Text('Add wallet',
                            style: AppText.body.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.brandDeep)),
                        const Spacer(),
                        Text('Cash, bank or mobile',
                            style: AppText.caption
                                .copyWith(color: AppColors.inkTertiary)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _walletCard(BuildContext context, Wallet w) {
    final style = walletStyleFor(w.type);
    final balance = Store.balanceOf(w.id);
    final count = Store.txnCountForWallet(w.id);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => WalletDetailScreen(walletId: w.id))),
      child: Container(
        height: 76,
        decoration: cardDecoration(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Color(style.tint),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(iconFor(style.iconKey),
                  size: 22, color: Color(style.strong)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(w.name,
                            style: AppText.bodyStrong,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (w.isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          height: 20,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.accentTint,
                            borderRadius:
                                BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text('Default',
                              style: AppText.caption.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.brandDeep)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(w.caption,
                      style: AppText.caption
                          .copyWith(color: AppColors.inkTertiary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AmountText(
                  value: balance,
                  style: AppText.amountRow.copyWith(
                    color: balance < 0
                        ? AppColors.expense
                        : (balance == 0
                            ? AppColors.inkTertiary
                            : AppColors.ink),
                  ),
                  neutral: true,
                ),
                const SizedBox(height: 2),
                Text(
                  count == 0
                      ? 'No transactions yet'
                      : '$count transaction${count == 1 ? '' : 's'}',
                  style: AppText.caption.copyWith(
                      fontSize: 11, color: AppColors.inkTertiary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Add-wallet sheet (spec §2.6).
Future<void> showAddWalletSheet(BuildContext context) async {
  var type = 'cash';
  final nameCtrl = TextEditingController(text: 'Cash');
  final balanceCtrl = TextEditingController();
  final last4Ctrl = TextEditingController();
  var setDefault = false;

  const typeLabels = {
    'cash': 'Cash',
    'easypaisa': 'Easypaisa',
    'jazzcash': 'JazzCash',
    'bank': 'Bank account',
  };

  await showAppSheet<void>(
    context: context,
    title: 'Add wallet',
    child: StatefulBuilder(
      builder: (ctx, setSheet) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final e in typeLabels.entries)
              InkWell(
                onTap: () => setSheet(() {
                  type = e.key;
                  if (nameCtrl.text.isEmpty ||
                      typeLabels.values.contains(nameCtrl.text)) {
                    nameCtrl.text = e.value;
                  }
                }),
                child: SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Color(walletStyleFor(e.key).tint),
                          borderRadius:
                              BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Icon(
                            iconFor(walletStyleFor(e.key).iconKey),
                            size: 22,
                            color: Color(walletStyleFor(e.key).strong)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(e.value, style: AppText.body)),
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: type == e.key
                                ? AppColors.brand
                                : AppColors.hairline,
                            width: 1.5,
                          ),
                        ),
                        child: type == e.key
                            ? Center(
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: AppColors.brand,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            _sheetField('Wallet name', nameCtrl, 'Wallet name'),
            const SizedBox(height: 16),
            _sheetField('Opening balance', balanceCtrl, '0',
                prefix: 'Rs ', numeric: true),
            const SizedBox(height: 16),
            _sheetField(
                'Account number (optional)', last4Ctrl, 'Last 4 digits',
                numeric: true, maxLength: 4),
            Text('Only the last 4 digits are shown',
                style:
                    AppText.caption.copyWith(color: AppColors.inkTertiary)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: Text('Set as default wallet',
                        style: AppText.bodyStrong)),
                Switch(
                  value: setDefault,
                  onChanged: (v) => setSheet(() => setDefault = v),
                ),
              ],
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Add Wallet',
              onTap: nameCtrl.text.trim().isEmpty
                  ? null
                  : () async {
                      final opening = parseAmount(balanceCtrl.text);
                      final w = Wallet(
                        id: newId(),
                        name: nameCtrl.text.trim(),
                        type: type,
                        last4: last4Ctrl.text.trim(),
                        isDefault: setDefault,
                        openingBalance: opening,
                        createdAtMs:
                            DateTime.now().millisecondsSinceEpoch,
                      );
                      if (setDefault) {
                        for (final other in Store.allWallets) {
                          if (other.isDefault) {
                            other.isDefault = false;
                            await Store.saveWallet(other);
                          }
                        }
                      }
                      await Store.saveWallet(w);
                      if (ctx.mounted) {
                        Navigator.of(ctx).pop();
                        appSnack(context, 'Wallet added');
                      }
                    },
            ),
          ],
        );
      },
    ),
  );
}

Widget _sheetField(String label, TextEditingController ctrl, String hint,
    {String? prefix, bool numeric = false, int? maxLength}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: AppText.label.copyWith(color: AppColors.inkSecondary)),
      const SizedBox(height: 8),
      TextField(
        controller: ctrl,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        maxLength: maxLength,
        inputFormatters:
            numeric ? [FilteringTextInputFormatter.digitsOnly] : null,
        decoration: InputDecoration(
          counterText: '',
          hintText: hint,
          prefixText: prefix,
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
      ),
    ],
  );
}

/// Wallet detail summary (spec §2.7).
class WalletDetailScreen extends StatelessWidget {
  final String walletId;
  const WalletDetailScreen({super.key, required this.walletId});

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      body: SafeArea(
        child: ValueListenableBuilder<int>(
          valueListenable: Store.changes,
          builder: (context, _, _) {
            final w = Store.walletById(walletId);
            if (w == null) {
              return const Center(child: Text('Wallet not found'));
            }
            final style = walletStyleFor(w.type);
            final balance = Store.balanceOf(w.id);
            final now = DateTime.now();
            final monthTxns = Store.txnsInMonth(now.year, now.month)
                .where((t) => t.walletId == w.id || t.toWalletId == w.id)
                .toList();
            final inSum = monthTxns
                .where((t) => t.effectOn(w.id) > 0 && !t.isAdjustment)
                .fold(0, (s, t) => s + t.effectOn(w.id));
            final outSum = monthTxns
                .where((t) => t.effectOn(w.id) < 0 && !t.isAdjustment)
                .fold(0, (s, t) => s - t.effectOn(w.id));
            final recent = Store.allTxnsDesc
                .where((t) => t.walletId == w.id || t.toWalletId == w.id)
                .take(5)
                .toList();
            final running = Store.runningBalances();

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                SubScreenHeader(
                  title: w.name,
                  trailing: CircleIconButton(
                    icon: Icons.more_horiz,
                    onTap: () => _showActions(context, w),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: cardDecoration(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Color(style.tint),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Icon(iconFor(style.iconKey),
                                size: 28, color: Color(style.strong)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(w.name,
                                          style: AppText.h2,
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis),
                                    ),
                                    if (w.isDefault) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        height: 20,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: AppColors.accentTint,
                                          borderRadius:
                                              BorderRadius.circular(
                                                  AppRadius.pill),
                                        ),
                                        child: Text('Default',
                                            style: AppText.caption.copyWith(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.brandDeep)),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(w.caption,
                                    style: AppText.caption.copyWith(
                                        color: AppColors.inkTertiary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(height: 1, color: AppColors.hairline),
                      ),
                      Text('CURRENT BALANCE',
                          style: AppText.micro
                              .copyWith(color: AppColors.inkTertiary)),
                      const SizedBox(height: 4),
                      AmountText(
                        value: balance,
                        style: AppText.displayBalanceLite,
                        neutral: true,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _stat('IN · ${fmtMonth(now).split(' ').first.toUpperCase()}',
                              '+${fmtRs(inSum)}', AppColors.brand),
                          _stat('OUT · ${fmtMonth(now).split(' ').first.toUpperCase()}',
                              '−${fmtRs(outSum)}', AppColors.expense),
                          _stat('TRANSACTIONS',
                              '${Store.txnCountForWallet(w.id)}', AppColors.ink),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _actionButton(
                        context,
                        icon: Icons.swap_horiz,
                        label: 'Transfer',
                        onTap: () =>
                            showTransferSheet(context, presetFrom: w),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _actionButton(
                        context,
                        icon: Icons.edit_outlined,
                        label: 'Adjust balance',
                        onTap: () => _showAdjustSheet(context, w),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SectionHeader(
                  title: 'Recent activity',
                  actionLabel: 'See all',
                  onAction: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          TransactionsScreen(presetWalletId: w.id),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (recent.isEmpty)
                  Container(
                    decoration: cardDecoration(),
                    padding: const EdgeInsets.all(20),
                    child: Text('No transactions in this wallet yet',
                        style: AppText.label
                            .copyWith(color: AppColors.inkSecondary),
                        textAlign: TextAlign.center),
                  )
                else
                  GroupCard(
                    children: [
                      for (final t in recent)
                        TxnRow(
                          txn: t,
                          runningBalance: running[t.id],
                          showRunningBalance: true,
                          onTap: () => showTxnDetailSheet(context, t),
                        ),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppText.micro
                  .copyWith(fontSize: 10, color: AppColors.inkTertiary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(
            Store.hideAmounts ? '••••••' : value,
            style: AppText.tab(AppText.bodyStrong.copyWith(
                fontSize: 15, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(BuildContext context,
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.hairline),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: AppColors.ink),
            const SizedBox(width: 8),
            Text(label,
                style:
                    AppText.body.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Future<void> _showActions(BuildContext context, Wallet w) async {
    await showAppSheet<void>(
      context: context,
      title: w.name,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text('Rename wallet', style: AppText.body),
            onTap: () async {
              Navigator.of(context).pop();
              await _showRenameSheet(context, w);
            },
          ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: Text('Adjust balance', style: AppText.body),
            onTap: () {
              Navigator.of(context).pop();
              _showAdjustSheet(context, w);
            },
          ),
          if (!w.isDefault)
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: Text('Set as default', style: AppText.body),
              onTap: () async {
                Navigator.of(context).pop();
                await Store.setDefaultWallet(w.id);
                if (context.mounted) {
                  appSnack(context, '${w.name} is now your default wallet');
                }
              },
            ),
          ListTile(
            leading: const Icon(Icons.archive_outlined,
                color: AppColors.expense),
            title: Text('Archive wallet',
                style: AppText.body.copyWith(color: AppColors.expense)),
            onTap: () async {
              Navigator.of(context).pop();
              final balance = Store.balanceOf(w.id);
              final ok = await showConfirmDialog(
                context: context,
                title: 'Archive ${w.name}?',
                body:
                    'Its ${fmtRs(balance)} balance stays in your history but the wallet leaves your totals. You can restore it from Settings.',
                confirmLabel: 'Archive',
                destructive: true,
              );
              if (ok) {
                w.archived = true;
                if (w.isDefault) {
                  w.isDefault = false;
                  await Store.saveWallet(w);
                  final others = Store.activeWallets;
                  if (others.isNotEmpty) {
                    await Store.setDefaultWallet(others.first.id);
                  }
                } else {
                  await Store.saveWallet(w);
                }
                if (context.mounted) Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showRenameSheet(BuildContext context, Wallet w) async {
    final ctrl = TextEditingController(text: w.name);
    await showAppSheet<void>(
      context: context,
      title: 'Rename wallet',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetField('Wallet name', ctrl, 'Wallet name'),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Save',
            onTap: () async {
              if (ctrl.text.trim().isEmpty) return;
              w.name = ctrl.text.trim();
              await Store.saveWallet(w);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showAdjustSheet(BuildContext context, Wallet w) async {
    final balanceCtrl =
        TextEditingController(text: groupPakistani(Store.balanceOf(w.id)));
    final reasonCtrl = TextEditingController();
    await showAppSheet<void>(
      context: context,
      title: 'Adjust balance',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetField('Correct balance', balanceCtrl, '0',
              prefix: 'Rs ', numeric: true),
          const SizedBox(height: 16),
          _sheetField('Reason', reasonCtrl, 'Why is this being corrected?'),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Save adjustment',
            onTap: () async {
              await Store.adjustBalance(
                wallet: w,
                newBalance: parseAmount(balanceCtrl.text),
                reason: reasonCtrl.text.trim(),
              );
              if (context.mounted) {
                Navigator.of(context).pop();
                appSnack(context, 'Balance adjusted');
              }
            },
          ),
        ],
      ),
    );
  }
}
