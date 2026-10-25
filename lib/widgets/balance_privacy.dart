import 'package:flutter/material.dart';

import '../data/store.dart';
import '../services/auth_gate.dart';
import '../theme.dart';
import 'common.dart';

/// v1.1.4 balance privacy: balances are MASKED by default. Tapping the
/// lock unlocks them (fingerprint, PIN fallback) for 30 seconds, then
/// BalanceLock re-masks them automatically. AmountText's own
/// hideAmounts eye toggle still applies on top when unlocked.
class MaskedAmount extends StatelessWidget {
  final int value;
  final TextStyle style;
  final bool neutral;
  const MaskedAmount({
    super.key,
    required this.value,
    required this.style,
    this.neutral = true,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: BalanceLock.unlocked,
      builder: (context, unlocked, _) {
        if (unlocked && !Store.hideAmounts) {
          return AmountText(value: value, style: style, neutral: neutral);
        }
        return Text('Rs ••••••', style: style);
      },
    );
  }
}

/// Small "locked — tap to unlock" pill shown under a masked balance.
class UnlockBalanceButton extends StatelessWidget {
  const UnlockBalanceButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: BalanceLock.unlocked,
      builder: (context, unlocked, _) {
        if (unlocked) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () => BalanceLock.unlock(context),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline,
                    size: 14, color: AppColors.accent),
                const SizedBox(width: 6),
                Text('Tap to unlock',
                    style: AppText.label.copyWith(
                        fontSize: 12, color: AppColors.accent)),
              ],
            ),
          ),
        );
      },
    );
  }
}
