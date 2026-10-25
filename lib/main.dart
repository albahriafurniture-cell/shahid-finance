import 'package:flutter/material.dart';

import 'data/store.dart';
import 'services/backup_service.dart';
import 'services/vault_service.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/dock.dart';
import 'screens/add_transaction.dart';
import 'screens/home.dart';
import 'screens/onboarding.dart';
import 'screens/password_manager.dart';
import 'screens/pin_lock.dart';
import 'screens/reports.dart';
import 'screens/settings.dart';
import 'screens/transactions.dart';

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
    await VaultService.init();
    await BackupService.init();
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

/// Main shell: 5 tabs (Home, History, Vault, Reports, Profile) + the
/// floating dock (which owns its FAB fan).
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

  void _pushAdd({required bool income}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AddTransactionScreen(initialIncome: income),
    ));
  }

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
                const PasswordManagerScreen(asTab: true),
                const ReportsScreen(asTab: true),
                const SettingsScreen(asTab: true),
              ],
            ),
          ),
          Positioned.fill(
            child: FloatingDock(
              currentIndex: _tab,
              onTab: (i) => setState(() => _tab = i),
              onAddIncome: () => _pushAdd(income: true),
              onAddExpense: () => _pushAdd(income: false),
            ),
          ),
        ],
      ),
    );
  }
}
