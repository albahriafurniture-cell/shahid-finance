import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/store.dart';
import '../services/backup_service.dart';
import '../services/vault_service.dart';
import '../services/pin_service.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/transfer_sheet.dart' show showWalletPicker;
import 'password_manager.dart';
import 'pin_lock.dart';
import 'wallets.dart';

/// Settings (budgets/settings spec §2–§3): profile, backup strip, cloud
/// backup, wallets, preferences, security, data, about, footer.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      body: SafeArea(
        child: ValueListenableBuilder<int>(
          valueListenable: Store.changes,
          builder: (context, _, _) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
              children: [
                Text('Settings', style: AppText.h1),
                const SizedBox(height: 20),
                _profileCard(context),
                const SizedBox(height: 16),
                _backupStrip(context),
                const SizedBox(height: 24),
                _cloudBackupGroup(context),
                const SizedBox(height: 24),
                _groupLabel('PASSWORD MANAGER'),
                GroupCard(children: [
                  _navRow(
                    icon: Icons.key_outlined,
                    label: 'Password Manager',
                    value: VaultService.ready
                        ? '${VaultService.entries.length}'
                        : '—',
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) =>
                                const PasswordManagerScreen())),
                  ),
                ]),
                const SizedBox(height: 24),
                _groupLabel('WALLETS'),
                GroupCard(children: [
                  _navRow(
                    icon: Icons.star_outline,
                    label: 'Default wallet',
                    value: Store.defaultWallet?.name ?? '—',
                    onTap: () async {
                      final w = await showWalletPicker(context,
                          title: 'Default wallet');
                      if (w != null) {
                        await Store.setDefaultWallet(w.id);
                        if (context.mounted) {
                          appSnack(context,
                              '${w.name} is now your default wallet');
                        }
                      }
                    },
                  ),
                  _navRow(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Manage wallets',
                    value: '${Store.activeWallets.length}',
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const WalletsScreen())),
                  ),
                ]),
                const SizedBox(height: 24),
                _groupLabel('PREFERENCES'),
                GroupCard(children: [
                  _navRow(
                    icon: Icons.grid_view_outlined,
                    label: 'Categories',
                    value: '${Store.uniqueCategoryCount}',
                    onTap: () => _showCategories(context),
                  ),
                  _navRow(
                    icon: Icons.calendar_month_outlined,
                    label: 'Budget cycle',
                    value:
                        'Starts on the ${cycleDayLabel(Store.cycleStartDay)}',
                    onTap: () => showCycleSheet(context),
                  ),
                  _switchRow(
                    icon: Icons.notifications_outlined,
                    label: 'Notifications',
                    value: Store.notifications,
                    onChanged: (v) => Store.setSetting('notifications', v),
                  ),
                  Opacity(
                    opacity: Store.notifications ? 1 : 0.45,
                    child: Column(
                      children: [
                        _switchRow(
                          icon: Icons.warning_amber_outlined,
                          label: 'Budget alerts',
                          caption: 'When a budget passes 80% and 100%',
                          value: Store.budgetAlerts,
                          onChanged: Store.notifications
                              ? (v) => Store.setSetting('budgetAlerts', v)
                              : null,
                        ),
                        _switchRow(
                          icon: Icons.summarize_outlined,
                          label: 'Weekly summary',
                          caption: 'Every Monday at 9:00 AM',
                          value: Store.weeklySummary,
                          onChanged: Store.notifications
                              ? (v) => Store.setSetting('weeklySummary', v)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 24),
                _groupLabel('SECURITY'),
                GroupCard(children: [
                  _switchRow(
                    icon: Icons.lock_outline,
                    label: 'App lock',
                    caption: Store.pinEnabled
                        ? 'PIN set · asks on every launch'
                        : 'Ask for a PIN when the app opens',
                    value: Store.pinEnabled,
                    onChanged: (v) => _togglePin(context, v),
                  ),
                  _switchRow(
                    icon: Icons.fingerprint,
                    label: 'Biometric unlock',
                    caption: !Store.pinEnabled
                        ? 'Turn on App lock first'
                        : (Store.biometricEnabled
                            ? 'Fingerprint or face'
                            : 'Off'),
                    value: Store.pinEnabled && Store.biometricEnabled,
                    onChanged: !Store.pinEnabled
                        ? null
                        : (v) => _toggleBiometric(context, v),
                  ),
                  if (Store.pinEnabled)
                    _navRow(
                      icon: Icons.pin_outlined,
                      label: 'Change PIN',
                      onTap: () => _changePin(context),
                    ),
                ]),
                const SizedBox(height: 24),
                _groupLabel('DATA'),
                GroupCard(children: [
                  _switchRow(
                    icon: Icons.cloud_sync_outlined,
                    label: 'Auto-backup',
                    caption: BackupService.isSignedIn
                        ? 'After every change, when online'
                        : 'Sign in to turn this on',
                    value:
                        BackupService.isSignedIn && Store.autoBackup,
                    onChanged: BackupService.isSignedIn
                        ? (v) => Store.setSetting('autoBackup', v)
                        : null,
                  ),
                  _navRow(
                    icon: Icons.file_download_outlined,
                    label: 'Export CSV',
                    onTap: () => _exportCsv(context),
                  ),
                  _navRow(
                    icon: Icons.file_upload_outlined,
                    label: 'Import CSV',
                    onTap: () => appSnack(context,
                        'CSV import is coming in v1.1 — your data stays safe until then'),
                  ),
                ]),
                const SizedBox(height: 24),
                _groupLabel('ABOUT'),
                GroupCard(children: [
                  _staticRow(
                      icon: Icons.info_outline,
                      label: 'Version',
                      value: '1.1'),
                  _navRow(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Privacy policy',
                    onTap: () => appSnack(context,
                        'Your data lives on this device. Cloud backup is optional and tied to your account.'),
                  ),
                  _navRow(
                    icon: Icons.help_outline,
                    label: 'Help & support',
                    onTap: () => appSnack(context,
                        'Questions? Everything in Shahid Finance works offline — your hisaab is always with you.'),
                  ),
                ]),
                const SizedBox(height: 24),
                if (BackupService.isSignedIn)
                  Center(
                    child: TextButton(
                      onPressed: () => _logout(context),
                      child: Text('Log out',
                          style: AppText.body.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.expense)),
                    ),
                  ),
                Center(
                  child: TextButton(
                    onPressed: () => _deleteAccount(context),
                    child: Text('Delete account',
                        style: AppText.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.expense)),
                  ),
                ),
                const SizedBox(height: 16),
                // Footer (exact, per task brief)
                Column(
                  children: [
                    Text('Shahid Finance · Version 1.1',
                        style: AppText.caption
                            .copyWith(color: AppColors.inkTertiary)),
                    const SizedBox(height: 4),
                    Text('Har rupay ka saaf hisaab.',
                        style: AppText.caption.copyWith(
                            color: AppColors.inkTertiary,
                            fontStyle: FontStyle.italic)),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---- profile & backup strip ----

  Widget _profileCard(BuildContext context) {
    final name = Store.userName;
    final initial = name.isEmpty ? 'S' : name[0].toUpperCase();
    return Container(
      decoration: cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              gradient: AppColors.heroGradient,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child:
                Text(initial, style: AppText.h1.copyWith(color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isEmpty ? 'Your name' : name,
                    style: AppText.bodyStrong),
                const SizedBox(height: 2),
                Text(
                  Store.userPhone.isEmpty
                      ? 'Add your phone number'
                      : Store.userPhone,
                  style:
                      AppText.caption.copyWith(color: AppColors.inkTertiary),
                ),
              ],
            ),
          ),
          GhostButton(label: 'Edit', onTap: () => _showEditProfile(context)),
        ],
      ),
    );
  }

  Widget _backupStrip(BuildContext context) {
    if (!BackupService.isSignedIn) {
      return Container(
        decoration: cardDecoration(),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.warningTint,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.cloud_off_outlined,
                  size: 20, color: AppColors.warningText),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Back up your data', style: AppText.bodyStrong),
                  const SizedBox(height: 2),
                  Text(
                    'Sign in to keep your hisaab safe if you change phones.',
                    style: AppText.caption
                        .copyWith(color: AppColors.inkTertiary),
                  ),
                ],
              ),
            ),
            GhostButton(
                label: 'Sign in', onTap: () => _showSignInSheet(context)),
          ],
        ),
      );
    }
    final lastIso = Store.lastBackupAtIso;
    final last = lastIso == null ? null : DateTime.tryParse(lastIso);
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.hero,
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.cloud_done_outlined,
                size: 20, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  last == null
                      ? 'Not backed up yet'
                      : 'Backed up · ${_timeAgo(last)}',
                  style: AppText.bodyStrong.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  BackupService.currentUser?.email ?? '',
                  style: AppText.caption
                      .copyWith(color: Colors.white.withValues(alpha: 0.75)),
                ),
              ],
            ),
          ),
          const Icon(Icons.check, size: 20, color: Colors.white),
        ],
      ),
    );
  }

  String _timeAgo(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} hr ago';
    return '${d.inDays} d ago';
  }

  // ---- cloud backup group ----

  Widget _cloudBackupGroup(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _groupLabel('CLOUD BACKUP'),
        if (!BackupService.ready)
          Container(
            decoration: cardDecoration(),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.cloud_off_outlined,
                    color: AppColors.warning),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Cloud backup is not ready'
                    '${BackupService.initError == null ? '' : ': ${BackupService.initError}'}',
                    style: AppText.body.copyWith(fontSize: 13),
                  ),
                ),
              ],
            ),
          )
        else if (!BackupService.isSignedIn)
          GroupCard(children: [
            _navRow(
              icon: Icons.login,
              label: 'Sign in to enable backup',
              onTap: () => _showSignInSheet(context),
            ),
          ])
        else
          GroupCard(children: [
            _staticRow(
              icon: Icons.account_circle_outlined,
              label: BackupService.currentUser?.email ?? 'Signed in',
              value: '',
            ),
            _navRow(
              icon: Icons.cloud_upload_outlined,
              label: 'Back up now',
              onTap: () => _backupNow(context),
            ),
            _navRow(
              icon: Icons.cloud_download_outlined,
              label: 'Restore from backup',
              onTap: () => _restore(context),
            ),
            _navRow(
              icon: Icons.logout,
              label: 'Sign out',
              onTap: () async {
                await BackupService.signOut();
                Store.bump();
              },
            ),
          ]),
      ],
    );
  }

  Future<void> _backupNow(BuildContext context) async {
    appSnack(context, 'Backing up…');
    try {
      await BackupService.backupNow();
      Store.bump();
      if (context.mounted) appSnack(context, 'Backup complete');
    } on BackupException catch (e) {
      if (context.mounted) appSnack(context, 'Backup failed: ${e.message}');
    }
  }

  Future<void> _restore(BuildContext context) async {
    final ok = await showConfirmDialog(
      context: context,
      title: 'Restore from backup?',
      body:
          'This replaces everything on this device with your cloud backup. This cannot be undone.',
      confirmLabel: 'Restore',
      destructive: true,
    );
    if (!ok) return;
    try {
      await BackupService.restoreNow();
      if (context.mounted) appSnack(context, 'Backup restored');
    } on BackupException catch (e) {
      if (context.mounted) appSnack(context, e.message);
    }
  }

  // ---- sheets & flows ----

  Future<void> _showEditProfile(BuildContext context) async {
    final nameCtrl = TextEditingController(text: Store.userName);
    final phoneCtrl = TextEditingController(text: Store.userPhone);
    await showAppSheet<void>(
      context: context,
      title: 'Edit profile',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _field('Name', nameCtrl, 'Your name'),
          const SizedBox(height: 16),
          _field('Phone (optional)', phoneCtrl, '03XX XXXXXXX',
              numeric: true),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Save',
            onTap: () async {
              await Store.setSetting('userName', nameCtrl.text.trim());
              await Store.setSetting('userPhone', phoneCtrl.text.trim());
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, String hint,
      {bool numeric = false,
      bool obscure = false,
      TextInputType? keyboard}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppText.label.copyWith(color: AppColors.inkSecondary)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          obscureText: obscure,
          keyboardType:
              keyboard ?? (numeric ? TextInputType.phone : TextInputType.text),
          decoration: InputDecoration(
            hintText: hint,
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

  Future<void> _showSignInSheet(BuildContext context) async {
    if (!BackupService.ready) {
      appSnack(context,
          'Cloud backup is not ready: ${BackupService.initError ?? 'not configured'}');
      return;
    }
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    var createAccount = false;
    String? error;
    var busy = false;

    await showAppSheet<void>(
      context: context,
      title: 'Sign in for cloud backup',
      child: StatefulBuilder(
        builder: (ctx, setSheet) {
          Future<void> submit(Future<void> Function() fn) async {
            setSheet(() {
              busy = true;
              error = null;
            });
            try {
              await fn();
            } on BackupException catch (e) {
              if (ctx.mounted) {
                setSheet(() {
                  busy = false;
                  error = e.message;
                });
              }
              return;
            }
            if (!ctx.mounted) return;
            Navigator.of(ctx).pop();
            Store.bump();
            appSnack(context, 'Signed in');
            await _maybeOfferRestore(context);
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field('Email', emailCtrl, 'you@example.com',
                  keyboard: TextInputType.emailAddress),
              const SizedBox(height: 16),
              _field('Password', passCtrl, 'Password', obscure: true),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!,
                    style:
                        AppText.caption.copyWith(color: AppColors.expense)),
              ],
              const SizedBox(height: 20),
              PrimaryButton(
                label: busy
                    ? 'Please wait…'
                    : (createAccount ? 'Create account' : 'Sign in'),
                onTap: busy
                    ? null
                    : () => submit(() => createAccount
                        ? BackupService.createAccountWithEmail(
                            emailCtrl.text.trim(), passCtrl.text)
                        : BackupService.signInWithEmail(
                            emailCtrl.text.trim(), passCtrl.text)),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed:
                      busy ? null : () => submit(BackupService.signInWithGoogle),
                  icon: const Icon(Icons.g_mobiledata, size: 24),
                  label:
                      Text('Continue with Google', style: AppText.bodyStrong),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.hairline),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final email = emailCtrl.text.trim();
                          if (email.isEmpty) {
                            setSheet(() => error =
                                'Enter your email first, then tap Forgot password.');
                            return;
                          }
                          setSheet(() => busy = true);
                          try {
                            await BackupService.sendPasswordReset(email);
                            if (ctx.mounted) {
                              setSheet(() => busy = false);
                            }
                            if (context.mounted) {
                              appSnack(context,
                                  'Password reset email sent to $email');
                            }
                          } on BackupException catch (e) {
                            if (ctx.mounted) {
                              setSheet(() {
                                busy = false;
                                error = e.message;
                              });
                            }
                          }
                        },
                  child: Text('Forgot password?',
                      style: AppText.label.copyWith(color: AppColors.lime)),
                ),
              ),
              if (error != null && !createAccount)
                Center(
                  child: TextButton(
                    onPressed: () => setSheet(() {
                      createAccount = true;
                      error = null;
                    }),
                    child: Text('No account yet? Create an account instead',
                        style:
                            AppText.label.copyWith(color: AppColors.lime)),
                  ),
                ),
              Center(
                child: TextButton(
                  onPressed: () =>
                      setSheet(() => createAccount = !createAccount),
                  child: Text(
                    createAccount
                        ? 'Already have an account? Sign in'
                        : 'New here? Create an account',
                    style: AppText.label.copyWith(color: AppColors.brandDeep),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _maybeOfferRestore(BuildContext context) async {
    if (Store.allTxnsDesc.isNotEmpty) return;
    final has = await BackupService.hasCloudBackup();
    if (!has || !context.mounted) return;
    final ok = await showConfirmDialog(
      context: context,
      title: 'Restore your backup?',
      body:
          'We found a cloud backup for your account. Restore it to this device?',
      confirmLabel: 'Restore',
      cancelLabel: 'Start fresh',
    );
    if (ok && context.mounted) await _restore(context);
  }

  Future<void> _showCategories(BuildContext context) async {
    final now = DateTime.now();
    final monthTxns = Store.txnsInMonth(now.year, now.month);
    final cats = [
      ...Store.categoriesFor('expense'),
      ...Store.categoriesFor('income'),
    ];
    await showAppSheet<void>(
      context: context,
      title: 'Categories',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final c in cats)
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  CategoryTile(category: c, size: 40),
                  const SizedBox(width: 12),
                  Expanded(child: Text(c.name, style: AppText.body)),
                  Text(
                    '${monthTxns.where((t) => t.categoryId == c.id).length} this month',
                    style: AppText.caption
                        .copyWith(color: AppColors.inkTertiary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _togglePin(BuildContext context, bool on) async {
    if (on) {
      final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => const PinLockScreen(mode: PinMode.set),
      ));
      if (ok == true) Store.bump();
    } else {
      final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => const PinLockScreen(mode: PinMode.verify),
      ));
      if (ok == true) {
        await PinService.clearPin();
        await Store.setSetting('biometricEnabled', false);
        Store.bump();
        if (context.mounted) appSnack(context, 'App lock turned off');
      }
    }
  }

  Future<void> _toggleBiometric(BuildContext context, bool on) async {
    if (on) {
      final available = await BiometricService.isAvailable();
      if (!available) {
        if (context.mounted) {
          appSnack(context,
              "Biometrics aren't set up on this device — add a fingerprint in Android Settings first");
        }
        return;
      }
    }
    await Store.setSetting('biometricEnabled', on);
  }

  Future<void> _changePin(BuildContext context) async {
    final verified = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => const PinLockScreen(mode: PinMode.verify),
    ));
    if (verified != true || !context.mounted) return;
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => const PinLockScreen(mode: PinMode.set),
    ));
    if (ok == true && context.mounted) {
      appSnack(context, 'PIN changed');
    }
  }

  Future<void> _exportCsv(BuildContext context) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/shahid-finance-export.csv');
      await file.writeAsString(Store.exportCsv());
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        text: 'Shahid Finance — transactions export',
      ));
    } catch (e) {
      if (context.mounted) appSnack(context, 'Export failed: $e');
    }
  }

  Future<void> _logout(BuildContext context) async {
    final ok = await showConfirmDialog(
      context: context,
      title: 'Log out of Shahid Finance?',
      body:
          'Your data stays on this device. Cloud backups pause until you sign in again.',
      confirmLabel: 'Log out',
      destructive: true,
    );
    if (!ok) return;
    await BackupService.signOut();
    Store.bump();
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final ok = await showConfirmDialog(
      context: context,
      title: 'Delete your account and all data?',
      body:
          'Every wallet, transaction, budget and cloud backup will be permanently deleted. This cannot be undone.',
      confirmLabel: 'Delete everything',
      destructive: true,
    );
    if (!ok) return;
    // Overwrite the cloud backup with a fresh empty state, then wipe local.
    final wasSignedIn = BackupService.isSignedIn;
    await Store.txns.clear();
    await Store.wallets.clear();
    await Store.budgets.clear();
    await Store.categories.clear();
    await Store.settings.clear();
    await Store.seedDefaults();
    if (wasSignedIn) {
      try {
        await BackupService.backupNow();
      } catch (_) {}
      await BackupService.signOut();
    }
    Store.bump();
    if (context.mounted) appSnack(context, 'All data deleted');
  }

  // ---- row builders ----

  Widget _groupLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(text,
          style: AppText.micro.copyWith(color: AppColors.inkTertiary)),
    );
  }

  Widget _navRow({
    required IconData icon,
    required String label,
    String? value,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(icon, size: 22, color: AppColors.inkSecondary),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: AppText.body)),
              if (value != null)
                Text(value,
                    style: AppText.label
                        .copyWith(color: AppColors.inkTertiary)),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right,
                  size: 18, color: AppColors.inkTertiary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _staticRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.inkSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: AppText.body,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Text(value,
                style: AppText.label.copyWith(color: AppColors.inkTertiary)),
          ],
        ),
      ),
    );
  }

  Widget _switchRow({
    required IconData icon,
    required String label,
    String? caption,
    required bool value,
    ValueChanged<bool>? onChanged,
  }) {
    return SizedBox(
      height: caption == null ? 56 : 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.inkSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppText.body),
                  if (caption != null) ...[
                    const SizedBox(height: 2),
                    Text(caption,
                        style: AppText.caption
                            .copyWith(color: AppColors.inkTertiary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// Budget cycle sheet (budgets/settings spec B.6): day options with a live
/// preview + confirm dialog before applying.
Future<void> showCycleSheet(BuildContext context) async {
  var selected = Store.cycleStartDay;
  await showAppSheet<void>(
    context: context,
    title: 'Budget cycle',
    child: StatefulBuilder(
      builder: (ctx, setSheet) {
        String rangeLabel(Cycle c) {
          if (c.start.year == c.end.year && c.start.month == c.end.month) {
            return '${c.start.day} – ${c.end.day} ${DateFormat('MMM').format(c.end)}';
          }
          return '${fmtDate(c.start)} – ${fmtDate(c.end)}';
        }

        String preview(int day) {
          final c = cycleFor(day, DateTime.now());
          return '${fmtMonth(c.start)} · ${rangeLabel(c)}';
        }

        Widget option(int value, String label, String caption) {
          final isSel = selected == value;
          return InkWell(
            onTap: () => setSheet(() => selected = value),
            child: SizedBox(
              height: 60,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: AppText.bodyStrong),
                        const SizedBox(height: 2),
                        Text(caption,
                            style: AppText.caption
                                .copyWith(color: AppColors.inkTertiary)),
                      ],
                    ),
                  ),
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSel ? AppColors.brand : AppColors.hairline,
                        width: 1.5,
                      ),
                    ),
                    child: isSel
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
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            option(1, '1st of the month', 'Calendar month'),
            option(15, '15th of the month', 'Mid-month cycle'),
            option(0, 'Last day of the month', 'End-of-month cycle'),
            const SizedBox(height: 12),
            Container(
              decoration: insetDecoration(),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_outlined,
                      size: 18, color: AppColors.brandDeep),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Current cycle would be ${preview(selected)}',
                      style:
                          AppText.label.copyWith(color: AppColors.brandDeep),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Apply',
              onTap: () async {
                Navigator.of(ctx).pop();
                final label = cycleDayLabel(selected);
                final ok = await showConfirmDialog(
                  context: context,
                  title: 'Change budget cycle?',
                  body:
                      'Budgets will be recalculated from the $label of each month. Existing transactions are not changed.',
                  confirmLabel: 'Change cycle',
                );
                if (ok) {
                  await Store.setSetting('cycleStartDay', selected);
                  if (context.mounted) {
                    appSnack(context, 'Budgets now start on the $label');
                  }
                }
              },
            ),
          ],
        );
      },
    ),
  );
}
