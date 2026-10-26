import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/store.dart';
import '../screens/pin_lock.dart';
import '../services/auth_gate.dart';
import '../services/pin_service.dart';
import '../services/vault_service.dart';
import '../theme.dart';
import '../utils/password_tools.dart';
import '../utils/site_catalog.dart';
import '../widgets/common.dart';
import '../widgets/site_icon.dart';

/// v1.1.7: Password Manager as a dock tab (back by explicit user
/// order, superseding the v1.1.2 removal). Encrypted local vault:
/// entries live ONLY on this phone, never in cloud backup.
///
/// The WHOLE tab is gated behind biometric-or-PIN auth: until the
/// user proves identity, only a locked state is shown — never entries.
class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  bool _authed = false;
  bool _authAttempted = false;
  // v1.1.9: two distinct dead-ends the old locked screen hid:
  // _needsSetup = auth can never succeed (no biometric, no app PIN);
  // _vaultBroken = the encrypted box never opened (init error).
  bool _needsSetup = false;
  bool _vaultBroken = false;
  String _query = '';
  String _category = 'All';
  bool _favouritesOnly = false;
  bool _grouped = false;
  final Set<String> _expandedGroups = {};
  final Set<String> _visible = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    final ok = await AuthGate.require(context);
    if (!mounted) return;
    var needsSetup = false;
    var vaultBroken = false;
    if (!ok) {
      // Distinguish "vault never opened" from "auth failed": the
      // first needs a vault retry, the second a way in.
      vaultBroken = !VaultService.ready && VaultService.initError != null;
      if (!vaultBroken) {
        needsSetup = !PinService.hasPin &&
            !(await BiometricService.isAvailable());
      }
    }
    setState(() {
      _authed = ok;
      _authAttempted = true;
      _needsSetup = needsSetup;
      _vaultBroken = vaultBroken;
    });
  }

  /// The old screen was a dead end when no biometric/PIN existed:
  /// "Unlock vault" just failed again with a disappearing snackbar.
  /// Offer PIN setup right here, then retry the unlock.
  Future<void> _setupPin() async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => const PinLockScreen(mode: PinMode.set),
    ));
    if (!mounted) return;
    if (ok == true) {
      setState(() => _needsSetup = false);
      await _unlock();
    }
  }

  Future<void> _retryVault() async {
    await VaultService.init();
    if (!mounted) return;
    setState(() => _vaultBroken = false);
    await _unlock();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: Store.changes,
      builder: (context, _, _) {
        final entries = VaultService.filtered(
          query: _query,
          category: _category,
          favouritesOnly: _favouritesOnly,
        );
        final total = VaultService.entries.length;
        return GlassScaffold(
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('Password Manager',
                            style: AppText.h1),
                      ),
                      if (_authed)
                        CircleIconButton(
                          icon: Icons.lock_outline,
                          onTap: () => setState(() {
                            _authed = false;
                            _visible.clear();
                          }),
                        ),
                    ],
                  ),
                ),
                if (!_authed)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: cardDecoration(),
                              child: EmptyState(
                                icon: Icons.lock_outline,
                                title: _vaultBroken
                                    ? 'Vault could not open'
                                    : 'Vault locked',
                                body: _vaultBroken
                                    ? 'The encrypted vault failed to open (${VaultService.initError ?? 'unknown error'}). Your saved passwords are untouched — retry opening it.'
                                    : _authAttempted
                                        ? 'Unlock with your fingerprint or PIN to see your passwords. They never leave this phone.'
                                        : 'Unlocking…',
                                actionLabel: _authAttempted
                                    ? (_vaultBroken
                                        ? 'Retry vault'
                                        : 'Unlock vault')
                                    : null,
                                onAction: _authAttempted
                                    ? (_vaultBroken
                                        ? _retryVault
                                        : _unlock)
                                    : null,
                              ),
                            ),
                          ),
                          // Dead-end fix: with no biometric and no
                          // PIN, "Unlock" can never succeed — offer
                          // PIN setup instead of looping forever.
                          if (_needsSetup) ...[
                            const SizedBox(height: 12),
                            PrimaryButton(
                              label: 'Set up PIN',
                              onTap: _setupPin,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No fingerprint or PIN is set up yet, so the vault has no way to unlock. Setting a PIN takes a minute.',
                              textAlign: TextAlign.center,
                              style: AppText.caption.copyWith(
                                  color: AppColors.inkTertiary),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      children: [
                        Container(
                          decoration: cardDecoration(),
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.accentTint,
                                  borderRadius: BorderRadius.circular(
                                      AppRadius.sm),
                                ),
                                child: const Icon(Icons.shield_outlined,
                                    size: 26, color: AppColors.brand),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text('Encrypted on this phone',
                                        style: AppText.bodyStrong),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$total saved · never backed up to the cloud',
                                      style: AppText.caption.copyWith(
                                          color: AppColors.inkTertiary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _searchField(),
                        const SizedBox(height: 12),
                        _categoryChips(),
                        const SizedBox(height: 12),
                        _viewToggle(),
                        const SizedBox(height: 16),
                        if (entries.isEmpty)
                          Container(
                            decoration: cardDecoration(),
                            child: EmptyState(
                              icon: Icons.key_outlined,
                              title: total == 0
                                  ? 'No passwords yet'
                                  : 'Nothing matches',
                              body: total == 0
                                  ? 'Add your first login — it stays encrypted on this phone.'
                                  : 'Try a different search or category.',
                              actionLabel:
                                  total == 0 ? 'Add password' : null,
                              onAction: total == 0
                                  ? () => _openForm(context)
                                  : null,
                            ),
                          )
                        else if (_grouped)
                          for (final g in groupEntries(entries)) ...[
                            _groupCard(g),
                            const SizedBox(height: 12),
                          ]
                        else
                          GroupCard(
                            children: [
                              for (final e in entries) _entryRow(e),
                            ],
                          ),
                      ],
                    ),
                  ),
                if (_authed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: PrimaryButton(
                      label: 'Add Password',
                      height: 58,
                      onTap: () => _openForm(context),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _searchField() {
    return TextField(
      onChanged: (v) => setState(() => _query = v),
      decoration: InputDecoration(
        hintText: 'Search title, username, website…',
        hintStyle:
            AppText.body.copyWith(color: AppColors.inkTertiary),
        prefixIcon:
            const Icon(Icons.search, color: AppColors.inkTertiary),
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
    );
  }

  Widget _categoryChips() {
    Widget chip(String label, {bool star = false}) {
      final selected = star ? _favouritesOnly : _category == label;
      return GestureDetector(
        onTap: () => setState(() {
          if (star) {
            _favouritesOnly = !_favouritesOnly;
          } else {
            _category = label;
          }
        }),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : AppColors.surfaceInset,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (star)
                Icon(Icons.star,
                    size: 14,
                    color: selected
                        ? Colors.white
                        : AppColors.inkSecondary),
              if (star) const SizedBox(width: 4),
              Text(label,
                  style: AppText.label.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? Colors.white
                        : AppColors.inkSecondary,
                  )),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('All'),
          const SizedBox(width: 8),
          for (final c in vaultCategories) ...[
            chip(c),
            const SizedBox(width: 8),
          ],
          chip('Favourites', star: true),
        ],
      ),
    );
  }

  /// All / By app toggle. Grouped view is the point of v1.1.8:
  /// one site, many accounts, each with its own username/password.
  Widget _viewToggle() {
    Widget seg(String label, bool selected, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppText.label.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.inkSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceInset,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          seg('All', !_grouped, () => setState(() => _grouped = false)),
          seg('By app / site', _grouped,
              () => setState(() => _grouped = true)),
        ],
      ),
    );
  }

  Widget _groupCard(SiteGroup g) {
    final expanded = _expandedGroups.contains(g.site.key);
    return Container(
      decoration: cardDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() {
              if (expanded) {
                _expandedGroups.remove(g.site.key);
              } else {
                _expandedGroups.add(g.site.key);
              }
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SiteIcon(site: g.site),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(g.site.name, style: AppText.title),
                        const SizedBox(height: 2),
                        Text(
                          '${g.entries.length} account${g.entries.length == 1 ? '' : 's'}',
                          style: AppText.caption.copyWith(
                              color: AppColors.inkTertiary),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _openForm(context,
                        prefillSite: g.site),
                    child: Text('+ Add account',
                        style: AppText.label.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.brand)),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.inkSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            for (final e in g.entries) ...[
              const Divider(
                  height: 1, thickness: 1, color: AppColors.surfaceInset),
              _entryRow(e),
            ],
        ],
      ),
    );
  }

  Widget _entryRow(VaultEntry e) {
    final shown = _visible.contains(e.id);
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SiteIcon(site: siteForEntry(e)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.title,
                        style: AppText.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (e.username.isNotEmpty) e.username,
                        e.category,
                      ].join(' · '),
                      style: AppText.caption.copyWith(
                          color: AppColors.inkTertiary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () async {
                  final updated = VaultEntry(
                    id: e.id,
                    title: e.title,
                    username: e.username,
                    password: e.password,
                    website: e.website,
                    category: e.category,
                    note: e.note,
                    favourite: !e.favourite,
                    updatedAtMs: e.updatedAtMs,
                  );
                  await VaultService.save(updated);
                },
                icon: Icon(
                  e.favourite ? Icons.star : Icons.star_border,
                  size: 22,
                  color: e.favourite
                      ? AppColors.accent
                      : AppColors.inkTertiary,
                ),
              ),
              IconButton(
                onPressed: () => _openForm(context, existing: e),
                icon: const Icon(Icons.edit_outlined,
                    size: 20, color: AppColors.inkSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceInset,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    shown ? e.password : '••••••••••',
                    style: AppText.body.copyWith(
                        fontFamily: 'monospace',
                        letterSpacing: shown ? 0.5 : 2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: () => setState(() {
                    if (shown) {
                      _visible.remove(e.id);
                    } else {
                      _visible.add(e.id);
                    }
                  }),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      shown
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: AppColors.inkSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () async {
                    await Clipboard.setData(
                        ClipboardData(text: e.password));
                    if (mounted) {
                      appSnack(context, 'Password copied');
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.copy_outlined,
                        size: 20, color: AppColors.inkSecondary),
                  ),
                ),
                if (e.username.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () async {
                      await Clipboard.setData(
                          ClipboardData(text: e.username));
                      if (mounted) {
                        appSnack(context, 'Username copied');
                      }
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.person_outline,
                          size: 20, color: AppColors.inkSecondary),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (e.website.isNotEmpty || e.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                [
                  if (e.website.isNotEmpty) e.website,
                  if (e.note.isNotEmpty) e.note,
                ].join(' · '),
                style: AppText.caption
                    .copyWith(color: AppColors.inkTertiary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  void _openForm(BuildContext context,
      {VaultEntry? existing, SiteInfo? prefillSite}) {
    showAppSheet<void>(
      context: context,
      title: existing == null ? 'Add Password' : 'Edit Password',
      child: VaultForm(existing: existing, prefillSite: prefillSite),
    );
  }
}

/// Add / edit form with generator + strength meter.
class VaultForm extends StatefulWidget {
  final VaultEntry? existing;
  final SiteInfo? prefillSite;
  const VaultForm({super.key, this.existing, this.prefillSite});

  @override
  State<VaultForm> createState() => VaultFormState();
}

class VaultFormState extends State<VaultForm> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _userCtrl;
  late final TextEditingController _passCtrl;
  late final TextEditingController _siteCtrl;
  late final TextEditingController _noteCtrl;
  late String _category;
  late bool _favourite;
  late bool _customSite;
  bool _showPassword = false;
  // v1.1.9: a failed save used to be a silent no-op (StateError
  // from VaultService.save propagated nowhere visible). Show it.
  String? _saveError;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    final pre = widget.prefillSite;
    _titleCtrl = TextEditingController(text: ex?.title ?? '');
    _userCtrl = TextEditingController(text: ex?.username ?? '');
    _passCtrl = TextEditingController(text: ex?.password ?? '');
    _siteCtrl =
        TextEditingController(text: ex?.website ?? pre?.canonical ?? '');
    _noteCtrl = TextEditingController(text: ex?.note ?? '');
    _category = ex?.category ??
        (pre != null && pre.social ? 'Social' : 'Login');
    _favourite = ex?.favourite ?? false;
    // A legacy free-text site that matches no catalog entry keeps
    // its custom text field visible when editing.
    _customSite = ex != null &&
        ex.website.isNotEmpty &&
        resolveSite(ex.website) == null;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _siteCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  bool get _valid =>
      _titleCtrl.text.trim().isNotEmpty &&
      _passCtrl.text.isNotEmpty;

  Future<void> _save() async {
    if (!_valid) return;
    setState(() => _saveError = null);
    final now = DateTime.now().millisecondsSinceEpoch;
    final entry = VaultEntry(
      id: widget.existing?.id ?? newId(),
      title: _titleCtrl.text.trim(),
      username: _userCtrl.text.trim(),
      password: _passCtrl.text,
      website: _siteCtrl.text.trim(),
      category: _category,
      note: _noteCtrl.text.trim(),
      favourite: _favourite,
      updatedAtMs: now,
    );
    try {
      await VaultService.save(entry);
    } catch (e) {
      if (!mounted) return;
      // Never a silent no-op again: show exactly why it failed,
      // and offer a vault retry when the box simply never opened.
      setState(() => _saveError = VaultService.ready
          ? 'Could not save: $e'
          : 'Vault is not open yet — it failed to open at startup. Retry below, then save again.');
      appSnack(context, 'Password NOT saved');
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    appSnack(context,
        widget.existing == null ? 'Password saved' : 'Password updated');
  }

  Future<void> _retryVault() async {
    await VaultService.init();
    if (!mounted) return;
    setState(() => _saveError = VaultService.ready
        ? null
        : 'Vault is still not open: ${VaultService.initError ?? 'unknown error'}');
  }

  Future<void> _delete() async {
    final ex = widget.existing;
    if (ex == null) return;
    final ok = await showConfirmDialog(
      context: context,
      title: 'Delete this password?',
      body: '${ex.title} will be removed from the vault.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await VaultService.delete(ex.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _generate() async {
    var length = 16.0;
    var letters = true;
    var numbers = true;
    var symbols = true;
    var preview = generateStrongPassword(length: 16);
    final chosen = await showAppSheet<String>(
      context: context,
      title: 'Generate Password',
      child: StatefulBuilder(
        builder: (ctx, setSheet) {
          void regen() {
            preview = generateStrongPassword(
              length: length.round(),
              letters: letters,
              numbers: numbers,
              symbols: symbols,
            );
          }

          Widget toggle(String label, bool value, ValueChanged<bool> on) {
            return Row(
              children: [
                Expanded(child: Text(label, style: AppText.body)),
                Switch(
                  value: value,
                  activeThumbColor: AppColors.accent,
                  onChanged: (v) {
                    setSheet(() {
                      on(v);
                      regen();
                    });
                  },
                ),
              ],
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceInset,
                  borderRadius:
                      BorderRadius.circular(AppRadius.md),
                ),
                child: SelectableText(preview,
                    style: AppText.bodyStrong.copyWith(
                        fontFamily: 'monospace', fontSize: 16)),
              ),
              const SizedBox(height: 8),
              Text('Strength: ${passwordStrength(preview)}',
                  style: AppText.label
                      .copyWith(color: AppColors.inkSecondary)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Length: ${length.round()}',
                      style: AppText.body),
                  Expanded(
                    child: Slider(
                      value: length,
                      min: 8,
                      max: 32,
                      divisions: 24,
                      activeColor: AppColors.accent,
                      onChanged: (v) => setSheet(() {
                        length = v;
                        regen();
                      }),
                    ),
                  ),
                ],
              ),
              toggle('Letters', letters, (v) => letters = v),
              toggle('Numbers', numbers, (v) => numbers = v),
              toggle('Symbols', symbols, (v) => symbols = v),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Use this password',
                onTap: () => Navigator.of(ctx).pop(preview),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setSheet(regen),
                child: Text('Generate again',
                    style: AppText.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.brand)),
              ),
            ],
          );
        },
      ),
    );
    if (chosen != null) setState(() => _passCtrl.text = chosen);
  }

  @override
  Widget build(BuildContext context) {
    final strength = passwordStrength(_passCtrl.text);
    final strengthValue = passwordStrengthValue(_passCtrl.text);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Title'),
        _field(_titleCtrl, 'e.g. Gmail, Meezan App'),
        const SizedBox(height: 16),
        _label('Username / Email'),
        _field(_userCtrl, 'Username or email'),
        const SizedBox(height: 16),
        _label('Password'),
        TextField(
          controller: _passCtrl,
          obscureText: !_showPassword,
          decoration: InputDecoration(
            hintText: 'Password',
            hintStyle:
                AppText.body.copyWith(color: AppColors.inkTertiary),
            filled: true,
            fillColor: AppColors.surfaceInset,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide.none,
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                  icon: Icon(
                    _showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.inkSecondary,
                  ),
                ),
                IconButton(
                  onPressed: _generate,
                  icon: const Icon(Icons.auto_awesome_outlined,
                      color: AppColors.brand),
                ),
              ],
            ),
          ),
          style: AppText.body.copyWith(fontFamily: 'monospace'),
          onChanged: (_) => setState(() {}),
        ),
        if (_passCtrl.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: strengthValue,
                    minHeight: 6,
                    backgroundColor: AppColors.surfaceInset,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      strength == 'Strong'
                          ? AppColors.brand
                          : strength == 'Medium'
                              ? AppColors.accent
                              : AppColors.expense,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(strength,
                  style: AppText.label.copyWith(
                      fontWeight: FontWeight.w700,
                      color: strength == 'Strong'
                          ? AppColors.brand
                          : strength == 'Medium'
                              ? AppColors.accent
                              : AppColors.expense)),
            ],
          ),
        ],
        const SizedBox(height: 16),
        _label('Website / App'),
        _sitePicker(),
        if (_customSite) ...[
          const SizedBox(height: 12),
          _field(_siteCtrl, 'e.g. mybank.com'),
        ],
        const SizedBox(height: 16),
        _label('Category'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in vaultCategories)
              GestureDetector(
                onTap: () => setState(() => _category = c),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _category == c
                        ? AppColors.accent
                        : AppColors.surfaceInset,
                    borderRadius:
                        BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Text(c,
                      style: AppText.label.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _category == c
                            ? Colors.white
                            : AppColors.inkSecondary,
                      )),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _label('Note (optional)'),
        _field(_noteCtrl, 'Anything to remember'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: Text('Favourite', style: AppText.body)),
            Switch(
              value: _favourite,
              activeThumbColor: AppColors.accent,
              onChanged: (v) => setState(() => _favourite = v),
            ),
          ],
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: widget.existing == null
              ? 'Save Password'
              : 'Save Changes',
          onTap: _valid ? _save : null,
        ),
        // A greyed Save with no explanation reads as "broken" —
        // say plainly what is missing.
        if (!_valid) ...[
          const SizedBox(height: 8),
          Text('Title aur password zaroori hain',
              style: AppText.caption.copyWith(
                  color: AppColors.inkTertiary)),
        ],
        if (_saveError != null) ...[
          const SizedBox(height: 8),
          Text(_saveError!,
              style: AppText.caption.copyWith(color: AppColors.expense)),
          if (!VaultService.ready) ...[
            const SizedBox(height: 4),
            TextButton(
              onPressed: _retryVault,
              child: Text('Retry vault',
                  style: AppText.body.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.brand)),
            ),
          ],
        ],
        if (widget.existing != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _delete,
            child: Text('Delete this password',
                style: AppText.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.expense)),
          ),
        ],
      ],
    );
  }

  /// Site picker button: shows the resolved brand tile + name,
  /// or the custom text when the site is not in the catalog.
  Widget _sitePicker() {
    final text = _siteCtrl.text.trim();
    final site = resolveSite(text);
    final shown = site ?? (text.isEmpty ? null : fallbackSite(text));
    return GestureDetector(
      onTap: _pickSite,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceInset,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            if (shown != null) ...[
              SiteIcon(site: shown, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Text(shown.name,
                    style: AppText.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ] else
              Expanded(
                child: Text('Choose app / site',
                    style: AppText.body),
              ),
            const Icon(Icons.keyboard_arrow_down,
                color: AppColors.inkSecondary),
          ],
        ),
      ),
    );
  }

  /// Searchable catalog sheet + "Other / custom" free-text option.
  /// Picking a site stores its canonical domain, so the tile and
  /// the By-app grouping match reliably; nothing is overwritten —
  /// every save creates its own entry id.
  Future<void> _pickSite() async {
    final searchCtrl = TextEditingController();
    await showAppSheet<void>(
      context: context,
      title: 'Choose app / site',
      child: StatefulBuilder(
        builder: (ctx, setSheet) {
          final q = searchCtrl.text.trim().toLowerCase();
          final sites = q.isEmpty
              ? siteCatalog
              : siteCatalog
                  .where((s) =>
                      s.name.toLowerCase().contains(q) ||
                      s.canonical.contains(q) ||
                      s.matchKeys.any((k) => k.contains(q)))
                  .toList();
          Widget row(SiteInfo s) {
            return InkWell(
              onTap: () {
                setState(() {
                  _siteCtrl.text = s.canonical;
                  _customSite = false;
                  if (_category == 'Login' && s.social) {
                    _category = 'Social';
                  }
                });
                Navigator.of(ctx).pop();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    SiteIcon(site: s, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(s.name, style: AppText.bodyStrong),
                          Text(s.canonical,
                              style: AppText.caption.copyWith(
                                  color: AppColors.inkTertiary)),
                        ],
                      ),
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
              TextField(
                controller: searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search apps & sites…',
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
                onChanged: (_) => setSheet(() {}),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () {
                  setState(() {
                    _customSite = true;
                    if (_siteCtrl.text.isNotEmpty &&
                        resolveSite(_siteCtrl.text) != null) {
                      _siteCtrl.text = '';
                    }
                  });
                  Navigator.of(ctx).pop();
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceInset,
                          borderRadius:
                              BorderRadius.circular(AppRadius.sm),
                        ),
                        child: const Icon(Icons.add,
                            color: AppColors.inkSecondary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('Other / custom site',
                            style: AppText.bodyStrong),
                      ),
                    ],
                  ),
                ),
              ),
              if (sites.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No match — use "Other / custom site".',
                      style: AppText.body),
                )
              else
                for (final s in sites) row(s),
            ],
          );
        },
      ),
    );
    searchCtrl.dispose();
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: AppText.label.copyWith(color: AppColors.inkSecondary)),
    );
  }

  Widget _field(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            AppText.body.copyWith(color: AppColors.inkTertiary),
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
      onChanged: (_) => setState(() {}),
    );
  }
}
