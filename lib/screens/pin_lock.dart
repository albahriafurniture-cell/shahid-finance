import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/store.dart';
import '../services/pin_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

enum PinMode { enter, set, verify }

/// PIN screen — one shared geometry for Enter / Set / Verify
/// (onboarding+PIN spec B.0). Dots, status line and keypad never move
/// between modes or states.
class PinLockScreen extends StatefulWidget {
  final PinMode mode;

  /// Set-PIN context: arriving from onboarding (shows "Skip for now").
  final bool firstRun;

  /// Called after a successful enter/verify (launch gate, settings flows).
  final VoidCallback? onSuccess;

  const PinLockScreen({
    super.key,
    required this.mode,
    this.firstRun = false,
    this.onSuccess,
  });

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen>
    with SingleTickerProviderStateMixin {
  String _entered = '';
  String? _firstPin; // set-mode: the create-step entry
  bool _confirmStep = false;
  String _status = '';
  bool _statusIsError = false;
  bool _errorFlash = false;
  bool _successFlash = false;
  bool _biometricAvailable = false;
  Timer? _lockoutTimer;
  late final AnimationController _shake;

  bool get _isSet => widget.mode == PinMode.set;
  bool get _locked => !_isSet && PinService.isLockedOut;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    if (_locked) _startLockoutTicker();
    if (widget.mode == PinMode.enter && Store.biometricEnabled) {
      BiometricService.isAvailable().then((ok) {
        if (mounted) {
          setState(() => _biometricAvailable = ok);
          if (ok) _tryBiometric();
        }
      });
    }
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _shake.dispose();
    super.dispose();
  }

  void _startLockoutTicker() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (!PinService.isLockedOut) {
        t.cancel();
        setState(() => _status = '');
      } else {
        setState(() {});
      }
    });
  }

  String get _lockoutText {
    final left = PinService.lockoutRemaining;
    final mm = left.inMinutes;
    final ss = (left.inSeconds % 60).toString().padLeft(2, '0');
    return 'Too many attempts. Try again in $mm:$ss';
  }

  Future<void> _tryBiometric() async {
    setState(() {
      _status = 'Touch the fingerprint sensor';
      _statusIsError = false;
    });
    final ok = await BiometricService.authenticate();
    if (!mounted) return;
    if (ok) {
      _succeed();
    } else {
      setState(() {
        _status = 'Fingerprint not recognized. Enter your PIN.';
        _statusIsError = false;
      });
    }
  }

  void _succeed() {
    setState(() {
      _successFlash = true;
      _status = '';
    });
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      Session.unlocked = true;
      if (widget.onSuccess != null) {
        widget.onSuccess!();
      } else {
        Navigator.of(context).pop(true);
      }
    });
  }

  Future<void> _onDigit(String d) async {
    if (_locked || _successFlash) return;
    if (_entered.length >= 4) return;
    HapticFeedback.lightImpact();
    setState(() {
      _entered += d;
      _errorFlash = false;
    });
    if (_entered.length == 4) {
      await Future.delayed(const Duration(milliseconds: 150));
      if (mounted) _submit();
    }
  }

  void _onBackspace() {
    if (_locked || _entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  Future<void> _submit() async {
    if (_isSet) {
      if (!_confirmStep) {
        setState(() {
          _firstPin = _entered;
          _entered = '';
          _confirmStep = true;
          _status = '';
        });
      } else if (_entered == _firstPin) {
        await PinService.setPin(_entered);
        if (!mounted) return;
        setState(() => _successFlash = true);
        Future.delayed(const Duration(milliseconds: 350), () {
          if (!mounted) return;
          Session.unlocked = true;
          appSnack(context, 'PIN lock is on');
          if (widget.onSuccess != null) {
            widget.onSuccess!();
          } else {
            Navigator.of(context).pop(true);
          }
        });
      } else {
        _shakeIt("PINs don't match. Try again.");
        setState(() {
          _firstPin = null;
          _confirmStep = false;
        });
      }
      return;
    }
    final result = await PinService.verify(_entered);
    if (!mounted) return;
    switch (result) {
      case VerifyResult.ok:
        _succeed();
      case VerifyResult.locked:
        _shakeIt(_lockoutText);
        _startLockoutTicker();
      case VerifyResult.wrong:
        final left = PinService.attemptsLeft;
        _shakeIt(left == 1
            ? 'Incorrect PIN. 1 attempt left'
            : 'Incorrect PIN. $left attempts left');
    }
  }

  void _shakeIt(String message) {
    setState(() {
      _errorFlash = true;
      _status = message;
      _statusIsError = true;
    });
    _shake.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 320), () {
      if (mounted) setState(() => _entered = '');
    });
  }

  String get _title {
    if (_isSet) return _confirmStep ? 'Confirm your PIN' : 'Create your PIN';
    if (widget.mode == PinMode.verify) return 'Enter your current PIN';
    return Store.userName.isEmpty ? 'Welcome back' : 'Welcome back, ${Store.userName}';
  }

  String get _subtitle {
    if (_isSet) {
      return _confirmStep
          ? 'Enter your PIN once more to confirm.'
          : 'Choose a 4-digit PIN you can remember.';
    }
    return 'Enter your 4-digit PIN';
  }

  @override
  Widget build(BuildContext context) {
    final locked = _locked;
    return GlassScaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    if (_isSet && !widget.firstRun)
                      CircleIconButton(
                        icon: Icons.arrow_back_ios_new,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                    const Spacer(),
                    if (_isSet && widget.firstRun)
                      GhostButton(
                        label: 'Skip for now',
                        onTap: () {
                          Session.unlocked = true;
                          if (widget.onSuccess != null) {
                            widget.onSuccess!();
                          } else {
                            Navigator.of(context).pop(false);
                          }
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Avatar / lock medallion
              if (_isSet)
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: AppColors.accentTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock,
                      size: 30, color: AppColors.brandDeep),
                )
              else
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: AppColors.accentTint,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    Store.userName.isEmpty
                        ? 'S'
                        : Store.userName[0].toUpperCase(),
                    style: AppText.h1.copyWith(color: AppColors.brandDeep),
                  ),
                ),
              const SizedBox(height: 16),
              Text(_title,
                  style: _isSet ? AppText.h1 : AppText.h2.copyWith(fontSize: 17),
                  textAlign: TextAlign.center),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Text(_subtitle,
                    style: AppText.body.copyWith(color: AppColors.inkSecondary),
                    textAlign: TextAlign.center),
              ),
              const SizedBox(height: 32),
              AnimatedBuilder(
                animation: _shake,
                builder: (ctx, child) {
                  final dx = _errorFlash
                      ? 8 * (1 - _shake.value) * ((_shake.value * 6).truncate().isEven ? 1 : -1)
                      : 0.0;
                  return Transform.translate(
                      offset: Offset(dx, 0), child: child);
                },
                child: _dots(locked),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 20,
                child: Text(
                  locked ? _lockoutText : _status,
                  style: AppText.caption.copyWith(
                    fontWeight:
                        (_statusIsError || locked) ? FontWeight.w600 : FontWeight.w500,
                    color: (_statusIsError || locked)
                        ? AppColors.expense
                        : AppColors.inkSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const Spacer(),
              _keypad(locked),
              const SizedBox(height: 16),
              SizedBox(
                height: 44,
                child: Center(
                  child: _isSet
                      ? (widget.firstRun
                          ? Text('You can turn this off later in Settings.',
                              style: AppText.caption
                                  .copyWith(color: AppColors.inkTertiary))
                          : const SizedBox.shrink())
                      : GhostButton(
                          label: 'Forgot PIN?',
                          onTap: () {
                            appSnack(context,
                                'Sign in again with your account to reset your PIN.');
                          },
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dots(bool locked) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 4; i++) ...[
          if (i > 0) const SizedBox(width: 18),
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _errorFlash
                  ? AppColors.expense
                  : (i < _entered.length || _successFlash)
                      ? AppColors.brand
                      : Colors.white,
              border: Border.all(
                color: locked
                    ? AppColors.expense
                    : (_errorFlash
                        ? AppColors.expense
                        : AppColors.hairline),
                width: 1.5,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _keypad(bool locked) {
    Widget key(Widget child, VoidCallback? onTap) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: AppShadows.card,
          ),
          alignment: Alignment.center,
          child: child,
        ),
      );
    }

    Widget digit(String d, String letters) {
      return key(
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(d,
                style: AppText.h1.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: locked ? AppColors.inkTertiary : AppColors.ink,
                )),
            if (letters.isNotEmpty)
              Text(letters,
                  style: AppText.caption.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                    color: AppColors.inkTertiary,
                  )),
          ],
        ),
        locked ? null : () => _onDigit(d),
      );
    }

    const letters = {
      '2': 'ABC', '3': 'DEF', '4': 'GHI', '5': 'JKL',
      '6': 'MNO', '7': 'PQRS', '8': 'TUV', '9': 'WXYZ',
    };
    final showBiometric =
        widget.mode == PinMode.enter && Store.biometricEnabled && _biometricAvailable;

    return Column(
      children: [
        for (final row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ]) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 16),
                digit(row[i], letters[row[i]] ?? ''),
              ],
            ],
          ),
          const SizedBox(height: 12),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showBiometric)
              key(
                const Icon(Icons.fingerprint,
                    size: 28, color: AppColors.brandDeep),
                locked ? null : _tryBiometric,
              )
            else
              const SizedBox(width: 72, height: 72),
            const SizedBox(width: 16),
            digit('0', ''),
            const SizedBox(width: 16),
            key(
              Icon(Icons.backspace_outlined,
                  size: 26,
                  color: locked ? AppColors.inkTertiary : AppColors.ink),
              locked ? null : _onBackspace,
            ),
          ],
        ),
      ],
    );
  }
}
