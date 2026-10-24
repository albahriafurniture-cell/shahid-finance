import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../utils/icons.dart';
import 'common.dart';

/// Wallet picker sheet: radio list of active wallets with balances.
/// Returns the chosen wallet, or null when dismissed.
Future<Wallet?> showWalletPicker(BuildContext context,
    {String title = 'Choose wallet', String? excludeId}) {
  final wallets =
      Store.activeWallets.where((w) => w.id != excludeId).toList();
  return showAppSheet<Wallet>(
    context: context,
    title: title,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final w in wallets)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Color(walletStyleFor(w.type).tint),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(iconFor(walletStyleFor(w.type).iconKey),
                  size: 22, color: Color(walletStyleFor(w.type).strong)),
            ),
            title: Text(w.name, style: AppText.bodyStrong),
            subtitle: Text(w.caption,
                style:
                    AppText.caption.copyWith(color: AppColors.inkTertiary)),
            trailing: AmountText(
              value: Store.balanceOf(w.id),
              style: AppText.bodyStrong,
              neutral: true,
            ),
            onTap: () => Navigator.of(context).pop(w),
          ),
      ],
    ),
  );
}

/// Transfer sheet (transactions/wallets spec §2.4): From/To pickers,
/// centred amount, quick chips, balance validation, live CTA label.
Future<void> showTransferSheet(BuildContext context,
    {Wallet? presetFrom}) async {
  final active = Store.activeWallets;
  if (active.length < 2) {
    appSnack(context, 'Add another wallet to transfer money.');
    return;
  }
  var from = presetFrom ?? Store.defaultWallet ?? active.first;
  Wallet? to =
      active.firstWhere((w) => w.id != from.id, orElse: () => active.last);
  final amountCtrl = TextEditingController();

  await showAppSheet<void>(
    context: context,
    title: 'Transfer',
    child: StatefulBuilder(
      builder: (ctx, setSheetState) {
        final amount = parseAmount(amountCtrl.text);
        final fromBalance = Store.balanceOf(from.id);
        final overBalance = amount > fromBalance;
        final valid = amount > 0 && !overBalance && to != null;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _pickerRow(
              label: 'From',
              wallet: from,
              onTap: () async {
                final picked =
                    await showWalletPicker(ctx, title: 'From wallet');
                if (picked != null) {
                  setSheetState(() {
                    from = picked;
                    if (to?.id == from.id) {
                      to = Store.activeWallets.firstWhere(
                          (w) => w.id != from.id,
                          orElse: () => to!);
                    }
                  });
                }
              },
            ),
            const Divider(height: 1, color: AppColors.surfaceInset),
            _pickerRow(
              label: 'To',
              wallet: to,
              onTap: () async {
                final picked = await showWalletPicker(ctx,
                    title: 'To wallet', excludeId: from.id);
                if (picked != null) setSheetState(() => to = picked);
              },
            ),
            const SizedBox(height: 20),
            Center(
              child: IntrinsicWidth(
                child: TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: AppText.amountXL,
                  decoration: InputDecoration(
                    prefixText: 'Rs ',
                    prefixStyle: AppText.body
                        .copyWith(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.inkSecondary),
                    border: InputBorder.none,
                    hintText: '0',
                    hintStyle: AppText.amountXL
                        .copyWith(color: AppColors.inkTertiary),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    GroupingFormatter(),
                  ],
                  onChanged: (_) => setSheetState(() {}),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final q in [500, 1000, 5000, 10000])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () {
                        amountCtrl.text =
                            groupPakistani(parseAmount(amountCtrl.text) + q);
                        setSheetState(() {});
                      },
                      child: Container(
                        height: 34,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.mintTint,
                          borderRadius:
                              BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text('+${groupPakistani(q)}',
                            style: AppText.label
                                .copyWith(color: AppColors.brandDeep)),
                      ),
                    ),
                  ),
              ],
            ),
            if (overBalance) ...[
              const SizedBox(height: 12),
              Text("Amount is more than this wallet's balance",
                  style: AppText.caption.copyWith(color: AppColors.expense)),
            ],
            const SizedBox(height: 20),
            PrimaryButton(
              label: amount > 0
                  ? 'Transfer ${fmtRs(amount)}'
                  : 'Transfer',
              onTap: valid
                  ? () async {
                      await Store.transfer(
                          from: from, to: to!, amount: amount);
                      if (ctx.mounted) {
                        Navigator.of(ctx).pop();
                        appSnack(context,
                            'Transferred ${fmtRs(amount)} from ${from.name} to ${to!.name}');
                      }
                    }
                  : null,
            ),
          ],
        );
      },
    ),
  );
}

Widget _pickerRow({
  required String label,
  required Wallet? wallet,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    child: SizedBox(
      height: 56,
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(label,
                style:
                    AppText.label.copyWith(color: AppColors.inkSecondary)),
          ),
          Expanded(
            child: Text(wallet?.name ?? 'Choose wallet',
                style: AppText.bodyStrong),
          ),
          if (wallet != null)
            AmountText(
              value: Store.balanceOf(wallet.id),
              style:
                  AppText.caption.copyWith(color: AppColors.inkTertiary),
              neutral: true,
            ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right,
              size: 18, color: AppColors.inkTertiary),
        ],
      ),
    ),
  );
}

/// Auto-inserts Pakistani grouping while typing an amount.
class GroupingFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    final grouped = groupPakistani(int.parse(digits));
    return TextEditingValue(
      text: grouped,
      selection: TextSelection.collapsed(offset: grouped.length),
    );
  }
}

/// Shared grouping formatter instance for amount fields app-wide.
final amountGroupingFormatter = GroupingFormatter();
