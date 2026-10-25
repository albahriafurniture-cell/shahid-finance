import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/common.dart';
import 'pin_service.dart';
import '../screens/pin_lock.dart';

/// One shared gate for sensitive actions (v1.1.4): fingerprint first,
/// PIN as fallback. Returns true only when the user actually proved
/// identity; a failed/cancelled attempt aborts the action with no change.
/// If the device has NEITHER a biometric nor a PIN set up, the action is
/// refused with guidance — silently allowing it would defeat the lock
/// the user asked for.
class AuthGate {
  static Future<bool> require(BuildContext context) async {
    // Fingerprint first, when the device can do it.
    if (await BiometricService.isAvailable()) {
      if (await BiometricService.authenticate()) return true;
      // Biometric failed/cancelled: fall through to PIN if one exists.
      if (PinService.hasPin) {
        if (!context.mounted) return false;
        return await _askPin(context);
      }
      if (!context.mounted) return false;
      appSnack(context,
          'Fingerprint not recognized. Set a PIN in Settings to use PIN fallback.');
      return false;
    }
    if (PinService.hasPin) {
      if (!context.mounted) return false;
      return await _askPin(context);
    }
    if (!context.mounted) return false;
    appSnack(context,
        'Set up App lock (PIN or fingerprint) in Settings first.');
    return false;
  }

  static Future<bool> _askPin(BuildContext context) async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => const PinLockScreen(mode: PinMode.verify),
    ));
    return ok == true;
  }
}

/// Balance privacy (v1.1.4): balances are MASKED by default and only
/// shown for 30 seconds after a successful unlock, then masked again
/// automatically — even if the user stays on the screen. The timer is
/// a single static timer, cancelled and restarted on every unlock, so
/// it can never fire twice or leak across navigations.
class BalanceLock {
  static final ValueNotifier<bool> unlocked = ValueNotifier<bool>(false);

  /// Overridable for tests (production value is 30 seconds).
  static Duration autoLockDuration = const Duration(seconds: 30);

  static Timer? _timer;

  static void lock() {
    _timer?.cancel();
    _timer = null;
    if (unlocked.value) unlocked.value = false;
  }

  static void unlockFor30s() {
    _timer?.cancel();
    unlocked.value = true;
    _timer = Timer(autoLockDuration, () {
      _timer = null;
      unlocked.value = false;
    });
  }

  /// Unlock flow: fingerprint first, PIN fallback, same as AuthGate.
  static Future<bool> unlock(BuildContext context) async {
    final ok = await AuthGate.require(context);
    if (ok) unlockFor30s();
    return ok;
  }
}
