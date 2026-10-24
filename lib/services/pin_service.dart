import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';

import '../data/store.dart';

enum VerifyResult { ok, wrong, locked }

/// PIN storage & verification. The PIN is never stored in plain text —
/// only a salted SHA-256 hash lives in the settings box. Lockout: 5 failed
/// attempts → 30 seconds (PIN spec B.1/B.3).
class PinService {
  static const int maxAttempts = 5;
  static const Duration lockoutDuration = Duration(seconds: 30);

  static String _hash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt::$pin')).toString();

  static bool get hasPin => Store.settings.get('pinHash') != null;

  static Future<void> setPin(String pin) async {
    final rnd = Random.secure();
    final salt =
        List.generate(16, (_) => rnd.nextInt(256)).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await Store.settings.put('pinSalt', salt);
    await Store.settings.put('pinHash', _hash(pin, salt));
    await Store.settings.put('pinFailedAttempts', 0);
    await Store.settings.put('pinLockoutUntilMs', 0);
    await Store.setSetting('pinEnabled', true);
  }

  static Future<void> clearPin() async {
    await Store.settings.delete('pinHash');
    await Store.settings.delete('pinSalt');
    await Store.settings.put('pinFailedAttempts', 0);
    await Store.settings.put('pinLockoutUntilMs', 0);
    await Store.setSetting('pinEnabled', false);
    await Store.setSetting('biometricEnabled', false);
  }

  static int get failedAttempts =>
      (Store.settings.get('pinFailedAttempts') as int?) ?? 0;

  static int get attemptsLeft => maxAttempts - failedAttempts;

  static Duration get lockoutRemaining {
    final until = (Store.settings.get('pinLockoutUntilMs') as int?) ?? 0;
    final left = until - DateTime.now().millisecondsSinceEpoch;
    return left > 0 ? Duration(milliseconds: left) : Duration.zero;
  }

  static bool get isLockedOut => lockoutRemaining > Duration.zero;

  static Future<VerifyResult> verify(String pin) async {
    if (isLockedOut) return VerifyResult.locked;
    final salt = Store.settings.get('pinSalt') as String?;
    final stored = Store.settings.get('pinHash') as String?;
    if (salt == null || stored == null) return VerifyResult.wrong;
    if (_hash(pin, salt) == stored) {
      await Store.settings.put('pinFailedAttempts', 0);
      await Store.settings.put('pinLockoutUntilMs', 0);
      return VerifyResult.ok;
    }
    final fails = failedAttempts + 1;
    await Store.settings.put('pinFailedAttempts', fails);
    if (fails >= maxAttempts) {
      await Store.settings.put('pinLockoutUntilMs',
          DateTime.now().add(lockoutDuration).millisecondsSinceEpoch);
      await Store.settings.put('pinFailedAttempts', 0);
      return VerifyResult.locked;
    }
    return VerifyResult.wrong;
  }
}

/// Biometric unlock via local_auth (needs FlutterFragmentActivity — set in
/// MainActivity). Every call is guarded: no hardware → false, never a crash.
class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return supported && canCheck;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock Shahid Finance',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
