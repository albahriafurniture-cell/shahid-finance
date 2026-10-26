import 'package:flutter/material.dart';

import 'data/store.dart';
import 'services/backup_service.dart';
import 'services/vault_service.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/dock.dart';
import 'screens/diary.dart';
import 'screens/home.dart';
import 'screens/onboarding.dart';
import 'screens/pin_lock.dart';
import 'screens/reports.dart';
import 'screens/settings.dart';
import 'screens/transactions.dart';
import 'screens/vault.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Keep boot failures visible instead of a blank screen (hisab pattern).
  ErrorWidget.builder = (details) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: SingleChildScrollView(
                child: Text(
                  'Shahid Finance hit a problem:\n\n${details.exception}\n\n${details.stack}',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            ),
          ),
        ),
      );

  Object? bootError;
  try {
    await Store.init();
    await BackupService.init();
    // Vault init must never block boot: on failure the tab shows its
    // locked state and VaultService.initError explains why.
    try {
      await VaultService.init();
    } catch (_) {
      // Vault tab handles the not-ready state itself.
    }
  } catch (e) {
    bootError = e;
  }

  runApp(ShahidFinanceApp(bootError: bootError));
}

class ShahidFinanceApp extends StatelessWidget {
  final Object? bootError;
  const ShahidFinanceApp({super.key, this.bootError});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shahid Finance',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: bootError != null
          ? Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Could not open your data.\n\n$bootError',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          : const Gate(),
    );
  }
}

/// Launch gate: onboarding → PIN lock → main shell.
class Gate extends StatefulWidget {
  const Gate({super.key});

  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: Store.changes,
      builder: (context, _, _) {
        if (!Store.onboardingDone) {
          return OnboardingScreen(onDone: () => setState(() {}));
        }
        if (Store.pinEnabled && !Session.unlocked) {
          return PinLockScreen(
            mode: PinMode.enter,
            onSuccess: () => setState(() => Session.unlocked = true),
          );
        }
        return const MainShell();
      },
    );
  }
}

/// Main shell: 6 tabs (Home, History, Vault, Diary, Reports,
/// Profile) + the floating dock (a plain scrollable tab row since
/// v1.1.9 — the centre + FAB fan was removed at the user's order;
/// Add Income/Expense live on the big Home buttons).
/// ORDER 1 fix (v1.1.1): the tab content sits inside SafeArea(top) so no
/// tab header ever draws under the Android status bar again — the
/// aurora background stays full-bleed behind it.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Stack(
        children: [
          const AuroraBackground(),
          SafeArea(
            top: true,
            bottom: false,
            child: IndexedStack(
              index: _tab,
              children: [
                HomeScreen(
                    onSeeAllTransactions: () => setState(() => _tab = 1)),
                const TransactionsScreen(),
                const VaultScreen(),
                const DiaryScreen(),
                const ReportsScreen(asTab: true),
                const SettingsScreen(asTab: true),
              ],
            ),
          ),
          Positioned.fill(
            child: FloatingDock(
              currentIndex: _tab,
              onTab: (i) => setState(() => _tab = i),
            ),
          ),
        ],
      ),
    );
  }
}
