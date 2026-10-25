import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shahid_finance/data/models.dart';
import 'package:shahid_finance/data/store.dart';
import 'package:shahid_finance/main.dart';
import 'package:shahid_finance/screens/home.dart';
import 'package:shahid_finance/utils/format.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // NOTE: Hive/Store init lives in setUpAll, not inside the widget
  // test body — opening Hive boxes inside a testWidgets body hangs
  // in this sandbox (proven on the untouched v1.0 tree too).
  late Directory testDir;
  setUpAll(() async {
    testDir = await Directory.systemTemp.createTemp('sf_test_');
    Hive.init(testDir.path);
    await Store.initFromDirectory();
    await Store.seedWallets();
  });
  tearDownAll(() async {
    await Hive.close();
    if (await testDir.exists()) await testDir.delete(recursive: true);
  });

  test('Pakistani digit grouping formatter', () {
    expect(groupPakistani(0), '0');
    expect(groupPakistani(999), '999');
    expect(groupPakistani(1000), '1,000');
    expect(groupPakistani(128450), '1,28,450');
    expect(groupPakistani(10000000), '1,00,00,000');
    expect(fmtRs(128450), 'Rs 1,28,450');
    expect(fmtSigned(500, income: true), '+Rs 500');
    expect(fmtSigned(500, income: false), '−Rs 500');
    expect(parseAmount('1,28,450'), 128450);
    expect(groupTyped('128450'), '1,28,450');
  });

  test('Cycle math honours the start day', () {
    final c = cycleFor(1, DateTime(2026, 10, 24));
    expect(c.start, DateTime(2026, 10, 1));
    expect(c.end, DateTime(2026, 10, 31));
    expect(c.totalDays, 31);
    final mid = cycleFor(15, DateTime(2026, 10, 10));
    expect(mid.start, DateTime(2026, 9, 15));
    expect(mid.end, DateTime(2026, 10, 14));
    expect(cycleDayLabel(1), '1st');
    expect(cycleDayLabel(0), 'Last day of month');
    expect(pacePerDay(32450, 9), 3610);
    expect(percentOf(57550, 90000), 64);
  });

  testWidgets('Fresh install boots to onboarding with seeded data',
      (tester) async {
    // Seed invariants (wallets seeded in setUpAll — see note above):
    // categories seeded, Easypaisa is the seeded default.
    expect(Store.uniqueCategoryCount, 12);
    expect(Store.allWallets.length, 4);
    expect(Store.defaultWallet?.name, 'Easypaisa');
    expect(Store.totalBalance, 0);
    expect(Store.onboardingDone, isFalse);

    await tester.pumpWidget(const ShahidFinanceApp());
    await tester.pump(const Duration(milliseconds: 400));

    // Onboarding slide 1 renders.
    expect(find.text('Know where your money goes'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  test('v1.1.3: opening balance adds to balances, never to in/out totals',
      () async {
    // Runs after the boot test; restores the seeded state at the end.
    final w = Store.defaultWallet!;
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    w.openingBalance = 50000;
    await Store.saveWallet(w);
    await Store.saveTxn(MoneyTxn(
      id: newId(),
      type: 'income',
      amount: 10000,
      walletId: w.id,
      dateMs: nowMs,
      createdAtMs: nowMs,
    ));
    await Store.saveTxn(MoneyTxn(
      id: newId(),
      type: 'expense',
      amount: 3000,
      walletId: w.id,
      dateMs: nowMs,
      createdAtMs: nowMs,
    ));
    final monthTxns = Store.txnsInMonth(now.year, now.month);
    expect(Store.balanceOf(w.id), 57000); // 50000 opening + 10000 − 3000
    expect(Store.totalBalance, 57000);
    expect(Store.sumIn(monthTxns), 10000); // opening balance NOT income
    expect(Store.sumOut(monthTxns), 3000);
    // Backup snapshot carries the opening balance (no fake txn needed).
    final snapWallet = (Store.snapshot()['wallets'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((j) => j['id'] == w.id);
    expect(snapWallet['openingBalance'], 50000);
    // Restore seeded state for later tests.
    for (final t in Store.txns.values.toList()) {
      await Store.deleteTxn(t.id);
    }
    w.openingBalance = 0;
    await Store.saveWallet(w);
    expect(Store.totalBalance, 0);
  });

  testWidgets('v1.1.3: Home elevates income/expense + wallet carousel',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HomeScreen(onSeeAllTransactions: () {}),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    // Large above-the-fold buttons (plus the horizontal quick row).
    expect(find.text('Add Income'), findsWidgets);
    expect(find.text('Add Expense'), findsWidgets);
    expect(find.text('My Wallets'), findsOneWidget);
    expect(find.text('Swipe ›'), findsOneWidget);
    expect(find.text('Easypaisa'), findsWidgets);
  });
}
