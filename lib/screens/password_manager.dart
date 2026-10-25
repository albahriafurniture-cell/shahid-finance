import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/store.dart';
import '../data/vault.dart';
import '../services/vault_service.dart';
import '../theme.dart';
import '../utils/password_generator.dart';
import '../widgets/common.dart';
import 'settings.dart';

/// Password Manager — local encrypted vault only (no cloud sync).
/// If the app PIN is on, the vault sits behind the launch PIN gate;
/// otherwise a warning recommends turning the PIN on.
class PasswordManagerScreen extends StatefulWidget {
  const PasswordManagerScreen({super.key});

  @override
  State<PasswordManagerScreen> createState() => _PasswordManagerState();
}

class _PasswordManagerState extends State<PasswordManagerScreen> {
  String _query = '';
  final _searchCtrl = TextEditingController();
  final _visible = <String>{};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      body: SafeArea(
        child: ValueListenableBuilder<int>(
          valueListenable: Store.changes,
          builder: (context, _, _) {
            final entries = VaultService.search(_query);
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                SubScreenHeader(
                  title: 'Password Manager',
                  trailing: CircleIconButton(
                    icon: Icons.add,
                    onTap: () => _editEntry(context, null),
                  ),
                ),
                const SizedBox(height: 16),
                if (!VaultService.ready)
                  Container(
                    decoration: cardDecoration(),
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Vault could not be opened on this device'
                      '${VaultService.initError == null ? '.' : ': ${VaultService.initError}'}'
                      ' Your passwords are not stored anywhere until it opens.',
                      style: AppText.body
                          .copyWith(color: AppColors.warningText),
                    ),
                  )
                else ...[
                  if (!Store.pinEnabled)
                    Container(
                      decoration: cardDecoration(),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_outlined,
                              color: AppColors.warning),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'App lock is off — anyone opening this phone can reach the vault. Turn on App lock for extra protection.',
                              style: AppText.body.copyWith(fontSize: 13),
                            ),
                          ),
                          GhostButton(
                            label: 'Security',
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const SettingsScreen())),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      decoration: cardDecoration(),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_outline,
                              color: AppColors.lime),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Protected by your app PIN — the vault opens only after the PIN gate.',
                              style: AppText.body.copyWith(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: cardDecoration(),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Icon(Icons.shield_outlined,
                            color: AppColors.lime),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Local encrypted only — vault entries are never synced to the cloud in this version.',
                            style: AppText.caption
                                .copyWith(color: AppColors.inkSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Search passwords…',
                      hintStyle: AppText.body
                          .copyWith(color: AppColors.inkTertiary),
                      prefixIcon: const Icon(Icons.search,
                          color: AppColors.inkTertiary),
                      filled: true,
                      fillColor: AppColors.surfaceInset,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: AppText.body,
                  ),
                  const SizedBox(height: 16),
                  if (entries.isEmpty)
                    EmptyState(
                      icon: Icons.key_outlined,
                      title: 'No passwords yet',
                      body:
                          'Add your first login — it stays encrypted on this device only.',
                      actionLabel: 'Add password',
                      onAction: () => _editEntry(context, null),
                    )
                  else
                    GroupCard(
                      children: [
                        for (final e in entries) _entryRow(context, e),
                      ],
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _entryRow(BuildContext context, VaultEntry e) {
    final shown = _visible.contains(e.id);
    return InkWell(
      onTap: () => _editEntry(context, e),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.mintTint,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              alignment: Alignment.center,
              child: Text(
                e.title.isEmpty ? '?' : e.title[0].toUpperCase(),
                style: AppText.bodyStrong.copyWith(color: AppColors.lime),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(e.title,
                            style: AppText.bodyStrong,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (e.favourite)
                        const Icon(Icons.star,
                            size: 16, color: AppColors.lime),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${e.username.isEmpty ? e.category : e.username} · ${shown ? e.password : '••••••••'}',
                    style: AppText.caption
                        .copyWith(color: AppColors.inkSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                  shown ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 20,
                  color: AppColors.inkTertiary),
              onPressed: () => setState(() {
                if (shown) {
                  _visible.remove(e.id);
                } else {
                  _visible.add(e.id);
                }
              }),
            ),
            IconButton(
              icon: const Icon(Icons.copy,
                  size: 20, color: AppColors.inkTertiary),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: e.password));
                if (context.mounted) {
                  appSnack(context, 'Password copied');
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 20, color: AppColors.expense),
              onPressed: () async {
                final ok = await showConfirmDialog(
                  context: context,
                  title: 'Delete this password?',
                  body: '“${e.title}” will be removed from the vault.',
                  confirmLabel: 'Delete',
                  destructive: true,
                );
                if (ok) {
                  await VaultService.delete(e.id);
                  if (context.mounted) {
                    appSnack(context, 'Password deleted');
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editEntry(BuildContext context, VaultEntry? existing) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final userCtrl = TextEditingController(text: existing?.username ?? '');
    final passCtrl = TextEditingController(text: existing?.password ?? '');
    final siteCtrl = TextEditingController(text: existing?.website ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    var category = existing?.category ?? 'Other';
    var favourite = existing?.favourite ?? false;
    var obscure = true;
    await showAppSheet<void>(
      context: context,
      title: existing == null ? 'Add password' : 'Edit password',
      child: StatefulBuilder(
        builder: (ctx, setSheet) {
          Widget field(String label, TextEditingController ctrl, String hint,
              {bool obsc = false, Widget? suffix}) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppText.label
                        .copyWith(color: AppColors.inkSecondary)),
                const SizedBox(height: 8),
                TextField(
                  controller: ctrl,
                  obscureText: obsc,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: AppText.body
                        .copyWith(color: AppColors.inkTertiary),
                    suffixIcon: suffix,
                    filled: true,
                    fillColor: AppColors.surfaceInset,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
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

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              field('App / website', titleCtrl, 'e.g. Facebook, Meezan'),
              const SizedBox(height: 14),
              field('Username / email', userCtrl, 'you@example.com'),
              const SizedBox(height: 14),
              field(
                'Password',
                passCtrl,
                'Your password',
                obsc: obscure,
                suffix: IconButton(
                  icon: Icon(
                      obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.inkTertiary),
                  onPressed: () => setSheet(() => obscure = !obscure),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    passCtrl.text.isEmpty
                        ? ''
                        : 'Strength: ${passwordStrength(passCtrl.text)}',
                    style: AppText.caption
                        .copyWith(color: AppColors.inkSecondary),
                  ),
                  const Spacer(),
                  GhostButton(
                    label: 'Generate strong',
                    onTap: () => setSheet(() {
                      passCtrl.text = generateStrongPassword();
                      obscure = false;
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              field('Website (optional)', siteCtrl, 'https://…'),
              const SizedBox(height: 14),
              Text('Category',
                  style: AppText.label
                      .copyWith(color: AppColors.inkSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final c in vaultCategories)
                    ChoiceChip(
                      label: Text(c),
                      selected: category == c,
                      onSelected: (_) => setSheet(() => category = c),
                      selectedColor: AppColors.lime,
                      labelStyle: AppText.label.copyWith(
                          color: category == c
                              ? AppColors.canvas
                              : AppColors.ink),
                      backgroundColor: AppColors.surfaceInset,
                      side: const BorderSide(color: AppColors.hairline),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              field('Notes (optional)', notesCtrl, 'Anything to remember'),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.star_outline,
                      size: 20, color: AppColors.lime),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text('Favourite', style: AppText.body)),
                  Switch(
                    value: favourite,
                    onChanged: (v) => setSheet(() => favourite = v),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: existing == null ? 'Save password' : 'Save changes',
                onTap: () async {
                  if (titleCtrl.text.trim().isEmpty ||
                      passCtrl.text.isEmpty) {
                    appSnack(context,
                        'Title and password are required');
                    return;
                  }
                  final now = DateTime.now().millisecondsSinceEpoch;
                  await VaultService.save(VaultEntry(
                    id: existing?.id ?? newId(),
                    title: titleCtrl.text.trim(),
                    username: userCtrl.text.trim(),
                    password: passCtrl.text,
                    website: siteCtrl.text.trim(),
                    category: category,
                    notes: notesCtrl.text.trim(),
                    favourite: favourite,
                    createdAtMs: existing?.createdAtMs ?? now,
                    updatedAtMs: now,
                  ));
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (context.mounted) {
                    appSnack(context, 'Password saved');
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
