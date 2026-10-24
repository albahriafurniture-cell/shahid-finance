import 'package:flutter/material.dart';

import '../data/store.dart';
import '../services/backup_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Sign In (master Screen 2A) — Firebase Auth: Google + Email/Password.
/// Exists to enable cloud backup; the app also works fully offline, and
/// that is stated plainly on this screen (trust line for this market).
class SignInScreen extends StatefulWidget {
  /// Called when the user is ready to enter the app (signed in OR chose
  /// to continue offline).
  final VoidCallback onSignedIn;
  const SignInScreen({super.key, required this.onSignedIn});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _createMode = false;
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  bool get _configured => BackupService.ready;

  Future<void> _afterAuth() async {
    // Auto-backup prompt: cloud data exists and local is empty → restore.
    try {
      final hasCloud = await BackupService.hasCloudBackup();
      if (hasCloud && Store.txns.isEmpty && Store.wallets.isEmpty) {
        if (!mounted) return;
        final restore = await showConfirmDialog(
          context: context,
          title: 'Restore your backup?',
          body:
              'We found a cloud backup for this account. Restore it to this device now?',
          confirmLabel: 'Restore',
        );
        if (restore) await BackupService.restoreNow();
      }
    } catch (_) {
      // Backup probing must never block entering the app.
    }
    if (mounted) widget.onSignedIn();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) await _afterAuth();
    } on BackupException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: AppColors.heroGradient,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: AppShadows.hero,
                  ),
                  alignment: Alignment.center,
                  child: Text('Rs',
                      style: AppText.h1.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Welcome to Shahid Finance',
                  style: AppText.h1, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Sign in to sync your data across devices.',
                  style: AppText.body.copyWith(color: AppColors.inkSecondary),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Container(
                decoration: cardDecoration(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.expenseTint,
                          borderRadius:
                              BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                size: 18, color: AppColors.expense),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_error!,
                                  style: AppText.label.copyWith(
                                      fontSize: 13,
                                      color: AppColors.expense)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (!_configured)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.warningTint,
                          borderRadius:
                              BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          'Cloud backup is not configured on this build. You can still use Shahid Finance fully offline.',
                          style: AppText.label.copyWith(
                              fontSize: 13, color: AppColors.warningText),
                        ),
                      ),
                    if (!_configured) const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: (!_configured || _busy)
                          ? null
                          : () => _run(BackupService.signInWithGoogle),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        side: const BorderSide(color: AppColors.hairline),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.md),
                        ),
                        backgroundColor: AppColors.surface,
                      ),
                      child: Text('Continue with Google',
                          style: AppText.body.copyWith(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Expanded(
                            child: Divider(color: AppColors.hairline)),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('or',
                              style: AppText.caption.copyWith(
                                  color: AppColors.inkTertiary)),
                        ),
                        const Expanded(
                            child: Divider(color: AppColors.hairline)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _field(
                      label: 'Email',
                      controller: _emailCtrl,
                      hint: 'you@example.com',
                      keyboard: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    _field(
                      label: 'Password',
                      controller: _passwordCtrl,
                      hint: 'Your password',
                      obscure: _obscure,
                      trailing: IconButton(
                        icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 22,
                            color: AppColors.inkTertiary),
                        onPressed: () =>
                            setState(() => _obscure = !_obscure),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GhostButton(
                        label: 'Forgot password?',
                        onTap: (!_configured || _busy)
                            ? null
                            : () async {
                                if (_emailCtrl.text.trim().isEmpty) {
                                  setState(() => _error =
                                      'Enter your email first, then tap Forgot password.');
                                  return;
                                }
                                await _run(() => BackupService
                                    .sendPasswordReset(_emailCtrl.text));
                                if (!mounted || _error != null) return;
                                if (!context.mounted) return;
                                appSnack(context,
                                    'Password reset email sent.');
                              },
                      ),
                    ),
                    PrimaryButton(
                      label: _busy
                          ? 'Please wait…'
                          : (_createMode ? 'Create account' : 'Sign In'),
                      onTap: (!_configured || _busy)
                          ? null
                          : () => _run(() => _createMode
                              ? BackupService.createAccountWithEmail(
                                  _emailCtrl.text, _passwordCtrl.text)
                              : BackupService.signInWithEmail(
                                  _emailCtrl.text, _passwordCtrl.text)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                            _createMode
                                ? 'Already have an account? '
                                : 'New here? ',
                            style: AppText.caption.copyWith(
                                fontSize: 13,
                                color: AppColors.inkSecondary)),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _createMode = !_createMode),
                          child: Text(
                            _createMode ? 'Sign in' : 'Create account',
                            style: AppText.caption.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.brandDeep),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GhostButton(
                label: 'Continue offline',
                onTap: widget.onSignedIn,
              ),
              Text(
                'You can also use Shahid Finance offline — sign in only enables backup & sync.',
                style:
                    AppText.caption.copyWith(color: AppColors.inkTertiary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboard,
    bool obscure = false,
    Widget? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppText.label.copyWith(color: AppColors.inkSecondary)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboard,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                AppText.body.copyWith(color: AppColors.inkTertiary),
            filled: true,
            fillColor: AppColors.surfaceInset,
            suffixIcon: trailing,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide:
                  const BorderSide(color: AppColors.brand, width: 1.5),
            ),
          ),
          style: AppText.body,
        ),
      ],
    );
  }
}
