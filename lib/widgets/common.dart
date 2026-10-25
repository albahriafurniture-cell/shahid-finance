import 'dart:ui';

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../utils/icons.dart';

/// Session-level unlock flag: PIN is asked once per app launch.
class Session {
  static bool unlocked = false;
}

/// 44×44 white circular icon button (master §3.1).
class CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool badgeDot;
  final double size;
  const CircleIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.badgeDot = false,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.hairline),
          boxShadow: AppShadows.card,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: size * 0.5, color: AppColors.ink),
            if (badgeDot)
              Positioned(
                top: size * 0.16,
                right: size * 0.16,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.canvas, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Primary CTA — solid brand (master §3.1). Gradient only where the spec
/// allows it (onboarding), via [gradient] = true.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool gradient;
  final double height;
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.gradient = false,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled
              ? (gradient ? AppColors.accent : AppColors.offWhite)
              : AppColors.surfaceInset,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.hairline),
          boxShadow: enabled ? AppShadows.hero : null,
        ),
        child: Text(
          label,
          style: AppText.body.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: enabled ? AppColors.canvas : AppColors.inkTertiary,
          ),
        ),
      ),
    );
  }
}

class GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color color;
  const GhostButton({
    super.key,
    required this.label,
    this.onTap,
    this.color = AppColors.accent,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Text(
          label,
          style: AppText.body.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: onTap == null ? AppColors.inkTertiary : color,
          ),
        ),
      ),
    );
  }
}

/// h2 section header with an optional right-side ghost action.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: AppText.h2)),
        if (actionLabel != null)
          GhostButton(label: actionLabel!, onTap: onAction),
      ],
    );
  }
}

/// Amount text that respects the app-wide hide-amounts eye toggle.
class AmountText extends StatelessWidget {
  final int value;
  final TextStyle style;
  final bool signed; // render with + / − by sign of value
  final bool neutral; // no sign, Rs only
  const AmountText({
    super.key,
    required this.value,
    required this.style,
    this.signed = false,
    this.neutral = false,
  });

  @override
  Widget build(BuildContext context) {
    if (Store.hideAmounts) {
      return Text('Rs ••••••', style: style);
    }
    String text;
    if (neutral) {
      text = fmtRs(value);
    } else if (signed) {
      text = value < 0 ? '−${fmtRs(-value)}' : '+${fmtRs(value)}';
    } else {
      text = value < 0 ? '−${fmtRs(-value)}' : fmtRs(value);
    }
    return Text(text, style: AppText.tab(style));
  }
}

/// The gradient hero shell: heroGradient + mint glow + the two white
/// circle overlays (master §2.2). Children render in white.
class HeroCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  const HeroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: AppColors.hairlineDark),
              boxShadow: AppShadows.hero,
            ),
            child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Stack(
            children: [
              Positioned(
                top: -70,
                right: -50,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Positioned(
                bottom: -60,
                left: -40,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.04),
                  ),
                ),
              ),
              Positioned(
                top: -90,
                right: -30,
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      AppColors.accent.withValues(alpha: 0.35),
                      AppColors.accent.withValues(alpha: 0),
                    ]),
                  ),
                ),
              ),
              Padding(padding: padding, child: child),
            ],
          ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Category icon tile (44dp, tint fill + strong glyph).
class CategoryTile extends StatelessWidget {
  final AppCategory category;
  final double size;
  const CategoryTile({super.key, required this.category, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Color(category.tintColor),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Icon(iconFor(category.iconKey),
          size: size * 0.5, color: Color(category.strongColor)),
    );
  }
}

/// Transaction row (master §3.6 / transactions spec §1.7) — the same row
/// on Home, Transactions and Wallet detail.
class TxnRow extends StatelessWidget {
  final MoneyTxn txn;
  final int? runningBalance;
  final bool showRunningBalance;
  final VoidCallback? onTap;
  const TxnRow({
    super.key,
    required this.txn,
    this.runningBalance,
    this.showRunningBalance = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hidden = Store.hideAmounts;
    if (txn.isTransfer) {
      final to = Store.walletById(txn.toWalletId);
      final from = Store.walletById(txn.walletId);
      return _rowShell(
        tile: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.accentTint,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: const Icon(Icons.swap_horiz,
              size: 22, color: AppColors.brandDeep),
        ),
        title: 'Transfer to ${to?.name ?? 'wallet'}',
        caption: 'From ${from?.name ?? ''} · ${fmtTime(txn.date)}',
        amountText: hidden ? 'Rs ••••••' : fmtRs(txn.amount),
        amountColor: AppColors.ink,
        onTap: onTap,
      );
    }
    if (txn.isAdjustment) {
      return _rowShell(
        tile: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.surfaceInset,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: const Icon(Icons.tune, size: 22, color: AppColors.inkSecondary),
        ),
        title: txn.note.isEmpty ? 'Balance adjustment' : txn.note,
        caption:
            '${Store.walletById(txn.walletId)?.name ?? ''} · ${fmtTime(txn.date)}',
        amountText: hidden
            ? 'Rs ••••••'
            : (txn.amount < 0 ? '−${fmtRs(-txn.amount)}' : '+${fmtRs(txn.amount)}'),
        amountColor: AppColors.ink,
        onTap: onTap,
      );
    }
    final cat = Store.categoryById(txn.categoryId);
    final wallet = Store.walletById(txn.walletId);
    final title = txn.note.isNotEmpty
        ? txn.note
        : (cat?.name ?? 'Transaction');
    return _rowShell(
      tile: cat != null
          ? CategoryTile(category: cat)
          : Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surfaceInset,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.more_horiz,
                  size: 22, color: AppColors.inkTertiary),
            ),
      title: title,
      caption: '${wallet?.name ?? ''} · ${fmtTime(txn.date)}',
      amountText: hidden
          ? 'Rs ••••••'
          : fmtSigned(txn.amount, income: txn.isIncome),
      amountColor: txn.isIncome ? AppColors.brand : AppColors.expense,
      runningBalance: showRunningBalance ? runningBalance : null,
      onTap: onTap,
    );
  }

  Widget _rowShell({
    required Widget tile,
    required String title,
    required String caption,
    required String amountText,
    required Color amountColor,
    int? runningBalance,
    VoidCallback? onTap,
  }) {
    final hidden = Store.hideAmounts;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 68),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            tile,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title,
                      style: AppText.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(caption,
                      style: AppText.caption
                          .copyWith(color: AppColors.inkTertiary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(amountText,
                    style: AppText.amountRow.copyWith(color: amountColor)),
                if (runningBalance != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    hidden ? 'Bal ••••••' : 'Bal ${fmtRs(runningBalance)}',
                    style: AppText.caption.copyWith(
                      fontSize: 11,
                      color: AppColors.inkTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// White list-group card wrapping rows with hairline dividers inset 56dp.
class GroupCard extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsets padding;
  const GroupCard({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    final separated = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      separated.add(children[i]);
      if (i < children.length - 1) {
        separated.add(const Divider(
          height: 1,
          thickness: 1,
          indent: 56,
          color: AppColors.surfaceInset,
        ));
      }
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: cardDecoration(),
          padding: padding,
          child: Column(children: separated),
        ),
      ),
    );
  }
}

/// Empty state (master §6 line version): blob + icon + title + body.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Column(
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: const BoxDecoration(
              color: AppColors.accentTint,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(36),
                topRight: Radius.circular(28),
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(36),
              ),
            ),
            child: Icon(icon, size: 52, color: AppColors.brandDeep),
          ),
          const SizedBox(height: 16),
          Text(title, style: AppText.h2, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(body,
                style: AppText.body.copyWith(color: AppColors.inkSecondary),
                textAlign: TextAlign.center),
          ),
          if (actionLabel != null)
            GhostButton(label: actionLabel!, onTap: onAction),
        ],
      ),
    );
  }
}

/// Standard bottom sheet shell (master §3.8).
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required String title,
  required Widget child,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.scrim,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xF21E1630),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl)),
            border: Border.all(color: AppColors.hairline),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.hairlineDark,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Text(title, style: AppText.h2.copyWith(fontSize: 20)),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Standard confirm dialog (master §3.8). Returns true when confirmed.
Future<bool> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String body,
  required String confirmLabel,
  bool destructive = false,
  String cancelLabel = 'Cancel',
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: AppColors.scrim,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E1630),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg)),
      title: Text(title,
          style: AppText.h2.copyWith(fontSize: 17, color: AppColors.ink)),
      content: Text(body,
          style: AppText.body.copyWith(color: AppColors.inkSecondary)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(cancelLabel,
              style: AppText.body.copyWith(
                  fontWeight: FontWeight.w700, color: AppColors.brandDeep)),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel,
              style: AppText.body.copyWith(
                  fontWeight: FontWeight.w700,
                  color: destructive
                      ? AppColors.expense
                      : AppColors.brandDeep)),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// App snackbar (master §3.8): ink fill, white text, optional Undo.
void appSnack(BuildContext context, String message, {VoidCallback? onUndo}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message,
          style: AppText.body.copyWith(
              fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.offWhite)),
      backgroundColor: const Color(0xFF1E1630),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm)),
      action: onUndo != null
          ? SnackBarAction(
              label: 'Undo', textColor: AppColors.accent, onPressed: onUndo)
          : null,
      duration: const Duration(seconds: 3),
    ),
  );
}

/// Sub-screen chrome: circular back button + centred h2 title.
class SubScreenHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SubScreenHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleIconButton(
          icon: Icons.arrow_back_ios_new,
          onTap: () => Navigator.of(context).maybePop(),
        ),
        Expanded(
          child: Text(title,
              style: AppText.h2, textAlign: TextAlign.center),
        ),
        trailing ?? const SizedBox(width: 44),
      ],
    );
  }
}
