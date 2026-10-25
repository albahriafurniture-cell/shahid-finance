import 'package:flutter/material.dart';

import '../data/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'pin_lock.dart';
import 'sign_in.dart';

/// Onboarding: 3 slides + setup step, one shared chrome so nothing moves
/// between steps (onboarding spec A.0). Setup Continue → Set PIN.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  final _nameCtrl = TextEditingController();
  int _page = 0;
  bool _setup = false;
  bool _nameError = false;

  static const _slides = [
    (
      'Know where your money goes',
      'Track income and expenses in seconds, and see your balance at a glance.'
    ),
    (
      'Reports that make sense',
      'Simple charts show your spending habits week by week, month by month.'
    ),
    (
      'Budgets that keep you on track',
      'Set monthly limits per category and get warned before you overspend.'
    ),
  ];

  int get _step => _setup ? 3 : _page;

  Future<void> _finish() async {
    await Store.seedWallets();
    await Store.setSetting('onboardingDone', true);
    Session.unlocked = true;
    widget.onDone();
  }

  void _toSignIn() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SignInScreen(onSignedIn: () async {
          Navigator.of(context).pop();
          await _finish();
        }),
      ),
    );
  }

  void _next() {
    if (_setup) return;
    if (_page < 2) {
      _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut);
    } else {
      setState(() => _setup = true);
    }
  }

  Future<void> _continueFromSetup() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _nameError = true);
      return;
    }
    // v1.1.2: profile name is SHAHID, exactly — never "Shahid Lucky".
    final typed = _nameCtrl.text.trim();
    await Store.setSetting(
        'userName', typed.toLowerCase() == 'shahid lucky' ? 'SHAHID' : typed);
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PinLockScreen(
          mode: PinMode.set,
          firstRun: true,
          onSuccess: () async {
            Navigator.of(context).pop();
            await _finish();
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top row
            SizedBox(
              height: 44,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    if (_setup)
                      CircleIconButton(
                        icon: Icons.arrow_back_ios_new,
                        onTap: () => setState(() => _setup = false),
                      ),
                    if (!_setup)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/images/app_icon.png',
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        ),
                      ),
                    const Spacer(),
                    if (!_setup)
                      GhostButton(label: 'Skip', onTap: _toSignIn),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _setup ? _setupStep() : _slidesView(),
            ),
            // Bottom block: indicator + CTA (+ reserved ghost row on slides)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _indicator(),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: _setup
                        ? 'Continue'
                        : (_page == 2 ? 'Get Started' : 'Next'),
                    gradient: true,
                    onTap: _setup
                        ? (_nameCtrl.text.trim().isNotEmpty
                            ? _continueFromSetup
                            : null)
                        : _next,
                  ),
                  if (!_setup)
                    SizedBox(
                      height: 44,
                      child: _page == 2
                          ? Center(
                              child: GhostButton(
                                label: 'I already have an account',
                                onTap: _toSignIn,
                              ),
                            )
                          : null,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _indicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 4; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: i == _step ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i < _step
                  ? AppColors.brand
                  : i == _step
                      ? AppColors.brand
                      : AppColors.hairlineDark,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
        ],
      ],
    );
  }

  Widget _slidesView() {
    return PageView.builder(
      controller: _pageCtrl,
      itemCount: 3,
      onPageChanged: (i) => setState(() => _page = i),
      itemBuilder: (ctx, i) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SingleChildScrollView(
            child: Column(
            children: [
              const SizedBox(height: 24),
              _illustrationStage(i),
              const SizedBox(height: 24),
              Text(_slides[i].$1,
                  style: AppText.headline, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Text(_slides[i].$2,
                    style:
                        AppText.body.copyWith(color: AppColors.inkSecondary),
                    textAlign: TextAlign.center),
              ),
            ],
            ),
          ),
        );
      },
    );
  }

  Widget _illustrationStage(int i) {
    return Container(
      width: 300,
      height: 240,
      decoration: const BoxDecoration(
        color: AppColors.accentTint,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(36),
          topRight: Radius.circular(28),
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: Center(child: [ _walletArt(), _chartArt(), _shieldArt() ][i]),
    );
  }

  // Flat two-tone-green spot illustrations (master §6), built from shapes.
  Widget _walletArt() {
    Widget coin(String label, Color fill, Color textColor, double size) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(label,
            style: AppText.label
                .copyWith(fontSize: size * 0.32, fontWeight: FontWeight.w800, color: textColor)),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 22,
              margin: const EdgeInsets.only(left: 30),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(10)),
              ),
            ),
            Container(
              width: 170,
              height: 110,
              decoration: BoxDecoration(
                color: AppColors.deepPurple,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  width: 52,
                  height: 110,
                  decoration: const BoxDecoration(
                    color: AppColors.brand,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        Positioned(
          right: 52,
          bottom: 38,
          child: coin('Rs', AppColors.accent, AppColors.canvas, 44),
        ),
        Positioned(
          right: 30,
          bottom: 74,
          child: coin('Rs', const Color(0xFFF5A623), AppColors.canvas, 34),
        ),
      ],
    );
  }

  Widget _chartArt() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final (h, c) in [
              (60.0, AppColors.accent),
              (95.0, AppColors.info),
              (135.0, AppColors.warning),
            ]) ...[
              Container(
                width: 40,
                height: h,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(8)),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ],
        ),
        Positioned(
          right: 58,
          top: 30,
          child: Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.brandDeep, width: 8),
              color: Colors.white.withValues(alpha: 0.25),
            ),
          ),
        ),
        Positioned(
          right: 44,
          top: 96,
          child: Transform.rotate(
            angle: 0.7,
            child: Container(
              width: 14,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.brandDeep,
                borderRadius: BorderRadius.circular(7),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _shieldArt() {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 150,
          height: 150,
          child: CircularProgressIndicator(
            value: 0.7,
            strokeWidth: 10,
            backgroundColor: AppColors.accent,
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.brandDeep),
          ),
        ),
        const Icon(Icons.shield, size: 110, color: AppColors.brand),
        const Icon(Icons.check, size: 52, color: AppColors.accentTint),
        Positioned(
          right: 62,
          top: 34,
          child: Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
                color: Color(0xFFF5A623), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('Rs',
                style: AppText.label.copyWith(
                    fontWeight: FontWeight.w800, color: AppColors.ink)),
          ),
        ),
      ],
    );
  }

  Widget _setupStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text('Make it yours', style: AppText.headline),
          const SizedBox(height: 8),
          Text(
            'Add your name and confirm your currency. You can change both later in Settings.',
            style: AppText.body.copyWith(color: AppColors.inkSecondary),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: cardDecoration(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your name',
                    style: AppText.label
                        .copyWith(color: AppColors.inkSecondary)),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 30,
                  onChanged: (_) => setState(() => _nameError = false),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'e.g. SHAHID',
                    hintStyle: AppText.body
                        .copyWith(color: AppColors.inkTertiary),
                    filled: true,
                    fillColor: AppColors.surfaceInset,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(
                          color: AppColors.brand, width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: _nameError
                          ? const BorderSide(
                              color: AppColors.expense, width: 1.5)
                          : BorderSide.none,
                    ),
                  ),
                  style: AppText.body,
                ),
                SizedBox(
                  height: 20,
                  child: _nameError
                      ? Text('Please enter your name',
                          style: AppText.caption
                              .copyWith(color: AppColors.expense))
                      : null,
                ),
                Text('Currency',
                    style: AppText.label
                        .copyWith(color: AppColors.inkSecondary)),
                const SizedBox(height: 8),
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceInset,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.brand, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: AppColors.accentTint,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text('Rs',
                            style: AppText.label.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.brandDeep)),
                      ),
                      const SizedBox(width: 12),
                      Text('Pakistani Rupee', style: AppText.bodyStrong),
                      const Spacer(),
                      Text('PKR',
                          style: AppText.body.copyWith(
                              fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: AppColors.brand,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check,
                            size: 13, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text('More currencies coming soon.',
                    style: AppText.caption
                        .copyWith(color: AppColors.inkTertiary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
