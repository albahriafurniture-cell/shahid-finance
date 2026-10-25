import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../services/receipt_service.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../utils/icons.dart';
import '../widgets/common.dart';
import '../widgets/transfer_sheet.dart';

/// Add / Edit Transaction (master Screen 4). One screen, mode-driven:
/// the Income/Expense segment flips title, CTA and amount colour.
class AddTransactionScreen extends StatefulWidget {
  final bool initialIncome;
  final MoneyTxn? existing;
  final String? presetCategoryId;
  final String? presetWalletId;

  const AddTransactionScreen({
    super.key,
    this.initialIncome = false,
    this.existing,
    this.presetCategoryId,
    this.presetWalletId,
  });

  bool get isEdit => existing != null;

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  late bool _income;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;
  AppCategory? _category;
  Wallet? _wallet;
  late DateTime _date;
  // v1.1.4 receipt: id is fixed up front so the photo file name can
  // be derived before saving; preview file for a newly picked photo.
  late final String _txnId;
  String _receiptFileName = '';
  File? _receiptPreview;
  Future<File?>? _receiptExistingFuture;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _txnId = ex?.id ?? newId();
    _receiptFileName = ex?.receiptPath ?? '';
    if (_receiptFileName.isNotEmpty) {
      _receiptExistingFuture = ReceiptService.fileFor(_receiptFileName);
    }
    _income = ex != null ? ex.isIncome : widget.initialIncome;
    _amountCtrl = TextEditingController(
        text: ex != null ? groupPakistani(ex.amount.abs()) : '');
    _noteCtrl = TextEditingController(text: ex?.note ?? '');
    _date = ex?.date ?? DateTime.now();
    if (ex != null) {
      _category = Store.categoryById(ex.categoryId);
      _wallet = Store.walletById(ex.walletId);
    } else {
      if (widget.presetWalletId != null) {
        _wallet = Store.walletById(widget.presetWalletId!);
      }
      _wallet ??= Store.defaultWallet;
      if (widget.presetCategoryId != null) {
        _category = Store.categoryById(widget.presetCategoryId!);
        if (_category != null) _income = _category!.kind == 'income';
      }
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  int get _amount => parseAmount(_amountCtrl.text);
  bool get _valid => _amount > 0 && _category != null && _wallet != null;

  void _switchKind(bool income) {
    setState(() {
      _income = income;
      if (_category != null && _category!.kind != (income ? 'income' : 'expense')) {
        _category = null;
      }
    });
  }

  Future<void> _pickReceipt(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      // Cancelled picker/camera: expense still saves fine, no receipt.
      if (picked == null) return;
      setState(() => _receiptPreview = File(picked.path));
      // Copy into app storage now (keyed by txn id); the file name is
      // stored on save. A copy failure leaves receipt empty, never
      // blocks the save.
      final saved = await ReceiptService.savePicked(picked.path, _txnId);
      if (mounted) setState(() => _receiptFileName = saved);
    } catch (_) {
      if (mounted) {
        appSnack(context,
            'Could not attach the receipt — the expense can still be saved.');
      }
    }
  }

  Future<void> _save() async {
    if (!_valid) return;
    final now = DateTime.now();
    final ex = widget.existing;
    final wasTransferOrAdjustment = ex != null && !ex.isIncome && !ex.isExpense;
    if (wasTransferOrAdjustment) return; // transfers/adjustments aren't edited here
    final dateTime = DateTime(_date.year, _date.month, _date.day,
        ex?.date.hour ?? now.hour, ex?.date.minute ?? now.minute);
    final txn = MoneyTxn(
      id: _txnId,
      type: _income ? 'income' : 'expense',
      amount: _amount,
      walletId: _wallet!.id,
      categoryId: _category!.id,
      note: _noteCtrl.text.trim(),
      dateMs: dateTime.millisecondsSinceEpoch,
      createdAtMs: ex?.createdAtMs ?? now.millisecondsSinceEpoch,
      receiptPath: _income ? '' : _receiptFileName,
    );
    await Store.saveTxn(txn);
    if (!mounted) return;
    final label =
        '${_income ? 'Income' : 'Expense'} ${widget.isEdit ? 'updated' : 'added'} · ${fmtRs(_amount)}';
    Navigator.of(context).pop();
    appSnack(context, label, onUndo: () async {
      if (widget.isEdit && ex != null) {
        await Store.saveTxn(ex);
      } else {
        await Store.deleteTxn(txn.id);
      }
    });
  }

  Future<void> _delete() async {
    final ex = widget.existing;
    if (ex == null) return;
    final ok = await showConfirmDialog(
      context: context,
      title: 'Delete this transaction?',
      body:
          '${ex.note.isNotEmpty ? ex.note : (Store.categoryById(ex.categoryId)?.name ?? 'Transaction')} · ${fmtSigned(ex.amount, income: ex.isIncome)}',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    await Store.deleteTxn(ex.id);
    if (!mounted) return;
    Navigator.of(context).pop();
    appSnack(context, 'Transaction deleted',
        onUndo: () => Store.saveTxn(ex));
  }

  @override
  Widget build(BuildContext context) {
    final kind = _income ? 'income' : 'expense';
    final cats = Store.categoriesFor(kind);
    final title = widget.isEdit
        ? 'Edit Transaction'
        : (_income ? 'Add Income' : 'Add Expense');
    return GlassScaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: SubScreenHeader(title: title),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                children: [
                  _segmented(),
                  const SizedBox(height: 28),
                  // Amount block
                  Center(
                    child: IntrinsicWidth(
                      child: TextField(
                        controller: _amountCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: AppText.amountXL.copyWith(
                          color: _income
                              ? AppColors.brand
                              : AppColors.expense,
                        ),
                        decoration: InputDecoration(
                          prefixText: 'Rs ',
                          prefixStyle: AppText.body.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.inkSecondary),
                          border: InputBorder.none,
                          hintText: '0',
                          hintStyle: AppText.amountXL
                              .copyWith(color: AppColors.inkTertiary),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          amountGroupingFormatter,
                        ],
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final q in [500, 1000, 5000, 10000])
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          child: GestureDetector(
                            onTap: () {
                              _amountCtrl.text =
                                  groupPakistani(_amount + q);
                              setState(() {});
                            },
                            child: Container(
                              height: 34,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.accentTint,
                                borderRadius: BorderRadius.circular(
                                    AppRadius.pill),
                              ),
                              child: Text('+${groupPakistani(q)}',
                                  style: AppText.label.copyWith(
                                      color: AppColors.brandDeep)),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text('Category',
                      style: AppText.label
                          .copyWith(color: AppColors.inkSecondary)),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1 / 1.05,
                    children: [
                      for (final c in cats) _categoryTile(c),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Details card
                  Container(
                    decoration: cardDecoration(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 4),
                    child: Column(
                      children: [
                        _detailRow(
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'Wallet',
                          value: _wallet?.name ?? 'Choose wallet',
                          onTap: () async {
                            final picked = await showWalletPicker(context);
                            if (picked != null) {
                              setState(() => _wallet = picked);
                            }
                          },
                        ),
                        const Divider(
                            height: 1, color: AppColors.surfaceInset),
                        _detailRow(
                          icon: Icons.calendar_month_outlined,
                          label: 'Date',
                          value: _isToday(_date)
                              ? 'Today, ${fmtDate(_date)}'
                              : fmtDate(_date),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _date,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() => _date = picked);
                            }
                          },
                        ),
                        const Divider(
                            height: 1, color: AppColors.surfaceInset),
                        SizedBox(
                          height: 56,
                          child: Row(
                            children: [
                              const Icon(Icons.notes,
                                  size: 22, color: AppColors.inkTertiary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _noteCtrl,
                                  maxLength: 80,
                                  decoration: InputDecoration(
                                    counterText: '',
                                    hintText: 'Add a note (optional)',
                                    hintStyle: AppText.body.copyWith(
                                        color: AppColors.inkTertiary),
                                    border: InputBorder.none,
                                  ),
                                  style: AppText.body,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // v1.1.4: optional receipt, expense only. Two options:
                  // gallery upload or direct camera photo. Cancelling
                  // either picker leaves the expense saveable as-is.
                  if (!_income) ...[
                    const SizedBox(height: 24),
                    _receiptSection(),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                children: [
                  PrimaryButton(
                    label: widget.isEdit
                        ? 'Save Changes'
                        : (_income ? 'Save Income' : 'Save Expense'),
                    height: 58,
                    onTap: _valid ? _save : null,
                  ),
                  if (widget.isEdit)
                    TextButton(
                      onPressed: _delete,
                      child: Text('Delete Transaction',
                          style: AppText.body.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.expense)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _receiptSection() {
    final hasReceipt =
        _receiptPreview != null || _receiptFileName.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Receipt (optional)',
            style: AppText.label.copyWith(color: AppColors.inkSecondary)),
        const SizedBox(height: 12),
        Container(
          decoration: cardDecoration(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (hasReceipt) ...[
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(AppRadius.md),
                      child: _receiptPreview != null
                          ? Image.file(_receiptPreview!,
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover)
                          : FutureBuilder<File?>(
                              future: _receiptExistingFuture,
                              builder: (ctx, snap) {
                                if (snap.data == null) {
                                  return Container(
                                    height: 180,
                                    alignment: Alignment.center,
                                    child: Text('Receipt not on this device',
                                        style: AppText.caption.copyWith(
                                            color: AppColors.inkTertiary)),
                                  );
                                }
                                return Image.file(snap.data!,
                                    height: 180,
                                    width: double.infinity,
                                    fit: BoxFit.cover);
                              },
                            ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _receiptPreview = null;
                          _receiptFileName = '';
                          _receiptExistingFuture = null;
                        }),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: Color(0xCC0F0B16),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              size: 18, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickReceipt(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined,
                          size: 20),
                      label: Text('Upload',
                          style: AppText.bodyStrong.copyWith(fontSize: 14)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        side:
                            const BorderSide(color: AppColors.hairline),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.md)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickReceipt(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined,
                          size: 20),
                      label: Text('Take photo',
                          style: AppText.bodyStrong.copyWith(fontSize: 14)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        side:
                            const BorderSide(color: AppColors.hairline),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.md)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Receipts stay on this device only.',
                  style: AppText.caption
                      .copyWith(color: AppColors.inkTertiary)),
            ],
          ),
        ),
      ],
    );
  }

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  Widget _segmented() {
    Widget seg(String label, bool income) {
      final selected = _income == income;
      return Expanded(
        child: GestureDetector(
          onTap: () => _switchKind(income),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? (income ? AppColors.brand : AppColors.expense)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              boxShadow: selected ? AppShadows.card : null,
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
      child: Row(children: [seg('Income', true), seg('Expense', false)]),
    );
  }

  Widget _categoryTile(AppCategory c) {
    final selected = _category?.id == c.id;
    return GestureDetector(
      onTap: () => setState(() => _category = c),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? Color(c.tintColor) : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? Color(c.strongColor) : AppColors.hairline,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Color(c.tintColor),
                shape: BoxShape.circle,
              ),
              child: Icon(iconFor(c.iconKey),
                  size: 20, color: Color(c.strongColor)),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                c.name,
                style: AppText.caption.copyWith(
                  fontSize: 12,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w600,
                  color: AppColors.ink,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.inkTertiary),
            const SizedBox(width: 12),
            Text(label, style: AppText.body),
            const Spacer(),
            Text(value, style: AppText.bodyStrong),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                size: 18, color: AppColors.inkTertiary),
          ],
        ),
      ),
    );
  }
}
