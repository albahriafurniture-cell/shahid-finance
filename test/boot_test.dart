import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shahid_finance/data/models.dart';
import 'package:shahid_finance/data/store.dart';
import 'package:shahid_finance/main.dart';
import 'package:shahid_finance/screens/home.dart';
import 'package:shahid_finance/services/auth_gate.dart';
import 'package:shahid_finance/services/vault_service.dart';
import 'package:shahid_finance/utils/format.dart';
import 'package:shahid_finance/utils/password_tools.dart';
import 'package:shahid_finance/widgets/dock.dart';

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
    // v1.1.4: Hive.close() never returns in this sandbox (same family
    // of hang as the box-open note above) — time-box it so the suite
    // exits after the tests themselves have passed.
    try {
      await Hive.close().timeout(const Duration(seconds: 10));
    } catch (_) {
      // Sandbox teardown quirk only; test results above stand.
    }
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
    // v1.1.4: +Family +My Self; v1.1.5: income 'Others' is now a
    // distinct name from expense 'Other' → 16 unique names.
    expect(Store.uniqueCategoryCount, 16);
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

  test('v1.1.4: Family and My Self expense categories exist', () {
    final names =
        Store.categoriesFor('expense').map((c) => c.name).toSet();
    expect(names.contains('Family'), isTrue);
    expect(names.contains('My Self'), isTrue);
    // Exact spellings, distinct icons.
    final family =
        Store.categoriesFor('expense').firstWhere((c) => c.name == 'Family');
    final myself =
        Store.categoriesFor('expense').firstWhere((c) => c.name == 'My Self');
    expect(family.iconKey, isNot(myself.iconKey));
    expect(family.kind, 'expense');
    expect(myself.kind, 'expense');
  });

  test('v1.1.4: receipt field round-trips on a transaction', () async {
    final w = Store.defaultWallet!;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final txn = MoneyTxn(
      id: newId(),
      type: 'expense',
      amount: 2500,
      walletId: w.id,
      categoryId: 'family',
      dateMs: nowMs,
      createdAtMs: nowMs,
      receiptPath: 'receipt_test.jpg',
    );
    // JSON (snapshot) round-trip.
    final restored = MoneyTxn.fromJson(txn.toJson());
    expect(restored.receiptPath, 'receipt_test.jpg');
    // Hive persistence round-trip.
    await Store.saveTxn(txn);
    expect(Store.txns.get(txn.id)?.receiptPath, 'receipt_test.jpg');
    // Snapshot carries only the file name, never photo bytes.
    final snapTxn = (Store.snapshot()['transactions'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((j) => j['id'] == txn.id);
    expect(snapTxn['receiptPath'], 'receipt_test.jpg');
    await Store.deleteTxn(txn.id);
  });

  test('v1.1.4: balance auto-locks after the unlock window', () async {
    final old = BalanceLock.autoLockDuration;
    BalanceLock.autoLockDuration = const Duration(milliseconds: 120);
    try {
      expect(BalanceLock.unlocked.value, isFalse);
      BalanceLock.unlockFor30s();
      expect(BalanceLock.unlocked.value, isTrue);
      await Future.delayed(const Duration(milliseconds: 250));
      expect(BalanceLock.unlocked.value, isFalse);
      // Re-unlock restarts the timer rather than stacking one.
      BalanceLock.unlockFor30s();
      BalanceLock.unlockFor30s();
      expect(BalanceLock.unlocked.value, isTrue);
      await Future.delayed(const Duration(milliseconds: 250));
      expect(BalanceLock.unlocked.value, isFalse);
    } finally {
      BalanceLock.autoLockDuration = old;
      BalanceLock.lock();
    }
  });

  testWidgets('v1.1.4: Home shows Today / Yesterday / This week',
      (tester) async {
    // Tall viewport so the Recent tabs (below the fold in the
    // default viewport) are built — same approach as the v1.1.6
    // Home layout test.
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final w = Store.defaultWallet!;
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    final todayTxn = MoneyTxn(
      id: newId(),
      type: 'expense',
      amount: 700,
      walletId: w.id,
      categoryId: 'myself',
      note: 'Today note',
      dateMs: nowMs,
      createdAtMs: nowMs,
    );
    // v1.1.6: Hive writes inside a testWidgets body stall in this
    // sandbox (FakeAsync zone vs Hive isolate — proven: the identical
    // save passes instantly in a plain test). runAsync executes the
    // real async work outside the fake zone; behaviour verified is
    // unchanged.
    await tester.runAsync(() => Store.saveTxn(todayTxn));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HomeScreen(onSeeAllTransactions: () {}),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('Today note'), findsWidgets);
    await tester.runAsync(() => Store.deleteTxn(todayTxn.id));
  });

  test('v1.1.5: income order is SDS, Freelance, Business, Salary, Others',
      () {
    final names =
        Store.categoriesFor('income').map((c) => c.name).toList();
    expect(names,
        ['SDS', 'Freelance', 'Business', 'Salary', 'Others']);
  });

  test('v1.1.5: income migration reorders old data + renames Other',
      () async {
    // Simulate a pre-v1.1.5 user: old order, old 'Other' label, no SDS.
    await Store.categories.clear();
    final old = [
      AppCategory(
          id: 'salary',
          name: 'Salary',
          kind: 'income',
          iconKey: 'payments',
          strongColor: 0xFF076B3A,
          tintColor: 0xFFDFF7E8,
          sortOrder: 0),
      AppCategory(
          id: 'business',
          name: 'Business',
          kind: 'income',
          iconKey: 'storefront',
          strongColor: 0xFF2F7DE1,
          tintColor: 0xFFE7F0FD,
          sortOrder: 1),
      AppCategory(
          id: 'freelance',
          name: 'Freelance',
          kind: 'income',
          iconKey: 'laptop_mac',
          strongColor: 0xFF9B7EDE,
          tintColor: 0xFFF0EBFC,
          sortOrder: 2),
      AppCategory(
          id: 'other_income',
          name: 'Other',
          kind: 'income',
          iconKey: 'more_horiz',
          strongColor: 0xFF8795A1,
          tintColor: 0xFFEEF2EF,
          sortOrder: 3),
    ];
    for (final c in old) {
      await Store.categories.put(c.id, c);
    }
    await Store.seedDefaults();
    final names =
        Store.categoriesFor('income').map((c) => c.name).toList();
    expect(names,
        ['SDS', 'Freelance', 'Business', 'Salary', 'Others']);
    // Family / My Self are re-added by the seed block (compat).
    expect(Store.categories.containsKey('family'), isTrue);
    expect(Store.categories.containsKey('myself'), isTrue);
  });

  test('v1.1.5: subcategory is optional, round-trips, hidden in picker',
      () async {
    final w = Store.defaultWallet!;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    // Picker hides Family / My Self, but the box still holds them.
    final pickerNames =
        Store.expensePickerCategories().map((c) => c.name).toSet();
    expect(pickerNames.contains('Family'), isFalse);
    expect(pickerNames.contains('My Self'), isFalse);
    expect(
        Store.categoriesFor('expense')
            .map((c) => c.name)
            .contains('Family'),
        isTrue);
    // None selected (default '') round-trips.
    final noSub = MoneyTxn(
      id: newId(),
      type: 'expense',
      amount: 1000,
      walletId: w.id,
      categoryId: 'food',
      dateMs: nowMs,
      createdAtMs: nowMs,
    );
    expect(noSub.subCategory, '');
    expect(MoneyTxn.fromJson(noSub.toJson()).subCategory, '');
    await Store.saveTxn(noSub);
    expect(Store.txns.get(noSub.id)?.subCategory, '');
    await Store.deleteTxn(noSub.id);
    // 'Family' subcategory round-trips via JSON + Hive + snapshot.
    final withSub = MoneyTxn(
      id: newId(),
      type: 'expense',
      amount: 2000,
      walletId: w.id,
      categoryId: 'food',
      dateMs: nowMs,
      createdAtMs: nowMs,
      subCategory: 'Family',
    );
    expect(MoneyTxn.fromJson(withSub.toJson()).subCategory, 'Family');
    await Store.saveTxn(withSub);
    expect(Store.txns.get(withSub.id)?.subCategory, 'Family');
    final snapTxn = (Store.snapshot()['transactions'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((j) => j['id'] == withSub.id);
    expect(snapTxn['subCategory'], 'Family');
    await Store.deleteTxn(withSub.id);
  });

  test('v1.1.5: loan remaining math, auto-settle, reopen on delete',
      () async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final loan = Loan(
      id: newId(),
      personName: 'Test Person',
      direction: 'taken',
      principal: 100000,
      dateMs: nowMs,
      createdAtMs: nowMs,
    );
    await Store.saveLoan(loan);
    expect(Store.remainingFor(loan), 100000);
    expect(Store.isSettled(loan), isFalse);
    final p1 = LoanPayment(
        id: newId(), loanId: loan.id, amount: 30000, dateMs: nowMs,
        createdAtMs: nowMs);
    final p2 = LoanPayment(
        id: newId(), loanId: loan.id, amount: 20000, dateMs: nowMs,
        createdAtMs: nowMs);
    await Store.savePayment(p1);
    await Store.savePayment(p2);
    expect(Store.paidFor(loan.id), 50000);
    expect(Store.remainingFor(loan), 50000);
    expect(Store.isSettled(loan), isFalse);
    final p3 = LoanPayment(
        id: newId(), loanId: loan.id, amount: 50000, dateMs: nowMs,
        createdAtMs: nowMs);
    await Store.savePayment(p3);
    expect(Store.remainingFor(loan), 0);
    expect(Store.isSettled(loan), isTrue);
    // Deleting the settling payment reopens the loan.
    await Store.deletePayment(p3.id);
    expect(Store.remainingFor(loan), 50000);
    expect(Store.isSettled(loan), isFalse);
    await Store.deleteLoan(loan.id);
    expect(Store.loans.get(loan.id), isNull);
    expect(Store.paymentsFor(loan.id), isEmpty);
  });

  test('v1.1.5: loans never affect wallet, income or expense totals',
      () async {
    final beforeBalance = Store.totalBalance;
    final beforeIn = Store.sumIn(Store.allTxnsDesc);
    final beforeOut = Store.sumOut(Store.allTxnsDesc);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final loan = Loan(
      id: newId(),
      personName: 'Isolation Check',
      direction: 'given',
      principal: 75000,
      dateMs: nowMs,
      createdAtMs: nowMs,
    );
    await Store.saveLoan(loan);
    await Store.savePayment(LoanPayment(
        id: newId(), loanId: loan.id, amount: 25000, dateMs: nowMs,
        createdAtMs: nowMs));
    expect(Store.totalBalance, beforeBalance);
    expect(Store.sumIn(Store.allTxnsDesc), beforeIn);
    expect(Store.sumOut(Store.allTxnsDesc), beforeOut);
    // Loans ride along in the cloud snapshot (small records).
    final snapLoans = (Store.snapshot()['loans'] as List)
        .cast<Map<String, dynamic>>();
    expect(snapLoans.any((j) => j['id'] == loan.id), isTrue);
    final snapPayments = (Store.snapshot()['loanPayments'] as List)
        .cast<Map<String, dynamic>>();
    expect(snapPayments.any((j) => j['loanId'] == loan.id), isTrue);
    await Store.deleteLoan(loan.id);
  });

  test('v1.1.6: Recent tab period filtering Today/Yesterday/This week',
      () {
    // Wednesday 2026-10-28: Monday of the week is 2026-10-26.
    final now = DateTime(2026, 10, 28, 12);
    final w = Store.defaultWallet!;
    MoneyTxn txn(String note, DateTime d, String type) => MoneyTxn(
          id: newId(),
          type: type,
          amount: 1000,
          walletId: w.id,
          categoryId: type == 'income' ? 'sds' : 'food',
          note: note,
          dateMs: d.millisecondsSinceEpoch,
          createdAtMs: d.millisecondsSinceEpoch,
        );
    final all = [
      txn('today', DateTime(2026, 10, 28, 9), 'expense'),
      txn('yesterday', DateTime(2026, 10, 27, 9), 'income'),
      txn('monday', DateTime(2026, 10, 26, 9), 'expense'),
      txn('last-sunday', DateTime(2026, 10, 25, 9), 'expense'),
      txn('last-month', DateTime(2026, 9, 30, 9), 'income'),
    ];
    final today = HomeScreen.txnsForPeriod(all, 0, now);
    expect(today.map((t) => t.note), ['today']);
    final yesterday = HomeScreen.txnsForPeriod(all, 1, now);
    expect(yesterday.map((t) => t.note), ['yesterday']);
    final week = HomeScreen.txnsForPeriod(all, 2, now);
    expect(week.map((t) => t.note).toSet(),
        {'today', 'yesterday', 'monday'});
    // Monday boundary: week starts Monday, not Sunday.
    expect(HomeScreen.weekStart(now), DateTime(2026, 10, 26));
  });

  test('v1.1.6: goals remaining/progress math + snapshot + isolation',
      () async {
    final beforeBalance = Store.totalBalance;
    final beforeIn = Store.sumIn(Store.allTxnsDesc);
    final beforeOut = Store.sumOut(Store.allTxnsDesc);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final goal = SavingsGoal(
      id: newId(),
      name: 'Test Goal',
      targetAmount: 10000,
      createdAtMs: nowMs,
    );
    await Store.saveGoal(goal);
    expect(goal.remaining, 10000);
    expect(goal.progress, 0);
    await Store.addToGoal(goal.id, 4000);
    final after = Store.goals.get(goal.id)!;
    expect(after.savedAmount, 4000);
    expect(after.remaining, 6000);
    expect(after.progress, 0.4);
    expect(after.isComplete, isFalse);
    // Adding past the target caps at the target (progress never > 1).
    await Store.addToGoal(goal.id, 8000);
    final capped = Store.goals.get(goal.id)!;
    expect(capped.savedAmount, 10000);
    expect(capped.remaining, 0);
    expect(capped.progress, 1.0);
    expect(capped.isComplete, isTrue);
    // Goals ride in the cloud snapshot, like loans.
    final snapGoals = (Store.snapshot()['goals'] as List)
        .cast<Map<String, dynamic>>();
    expect(snapGoals.any((j) => j['id'] == goal.id), isTrue);
    // And never touch wallet / income / expense totals.
    expect(Store.totalBalance, beforeBalance);
    expect(Store.sumIn(Store.allTxnsDesc), beforeIn);
    expect(Store.sumOut(Store.allTxnsDesc), beforeOut);
    await Store.deleteGoal(goal.id);
    expect(Store.goals.get(goal.id), isNull);
  });

  testWidgets('v1.1.6: Home matches screenshot layout',
      (tester) async {
    // Tall viewport so the whole ListView (including Recent
    // Transactions below the fold) is built without scrolling —
    // scrollUntilVisible is ambiguous here because the wallet
    // carousel PageView is a second Scrollable.
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HomeScreen(onSeeAllTransactions: () {}),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    // Header + hero + fixed quick actions + recent tabs.
    expect(find.textContaining('TOTAL BALANCE'), findsOneWidget);
    expect(find.text('This month'), findsOneWidget);
    expect(find.text('Add Income'), findsWidgets);
    expect(find.text('Add Expense'), findsWidgets);
    expect(find.text('Budgets'), findsOneWidget);
    expect(find.text('Transfer'), findsOneWidget);
    expect(find.text('Goals'), findsOneWidget);
    expect(find.text('Loans'), findsOneWidget);
    expect(find.text('My Wallets'), findsOneWidget);
    expect(find.text('Swipe ›'), findsOneWidget);
    expect(find.text('Recent Transactions'), findsOneWidget);
    expect(find.text('See all'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('This week'), findsOneWidget);
  });

  test('v1.1.7: people view totals group by name, case-insensitive',
      () async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final taken = Loan(
      id: newId(),
      personName: 'Ali Raza',
      direction: 'taken',
      principal: 100000,
      dateMs: nowMs,
      createdAtMs: nowMs,
    );
    final given = Loan(
      id: newId(),
      personName: '  ali raza ',
      direction: 'given',
      principal: 40000,
      dateMs: nowMs,
      createdAtMs: nowMs,
    );
    await Store.saveLoan(taken);
    await Store.saveLoan(given);
    await Store.savePayment(LoanPayment(
        id: newId(), loanId: taken.id, amount: 25000, dateMs: nowMs,
        createdAtMs: nowMs));
    final summaries = Store.peopleSummaries();
    final ali = summaries.firstWhere(
        (s) => Store.personKey(s.displayName) == 'ali raza');
    expect(ali.loanCount, 2);
    expect(ali.takenTotal, 100000);
    expect(ali.givenTotal, 40000);
    expect(ali.takenOutstanding, 75000);
    expect(ali.givenOutstanding, 40000);
    expect(Store.loansForPerson('ALI RAZA').length, 2);
    await Store.deleteLoan(taken.id);
    await Store.deleteLoan(given.id);
  });

  test('v1.1.7: due date overdue logic + due-date sort', () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nowMs = now.millisecondsSinceEpoch;
    final overdue = Loan(
      id: newId(),
      personName: 'Overdue Person',
      direction: 'taken',
      principal: 50000,
      dateMs: nowMs,
      dueDateMs: today.subtract(const Duration(days: 1))
          .millisecondsSinceEpoch,
      createdAtMs: nowMs,
    );
    final upcoming = Loan(
      id: newId(),
      personName: 'Upcoming Person',
      direction: 'taken',
      principal: 50000,
      dateMs: nowMs,
      dueDateMs:
          today.add(const Duration(days: 5)).millisecondsSinceEpoch,
      createdAtMs: nowMs,
    );
    final noDue = Loan(
      id: newId(),
      personName: 'No Due Person',
      direction: 'taken',
      principal: 50000,
      dateMs: nowMs,
      createdAtMs: nowMs,
    );
    await Store.saveLoan(overdue);
    await Store.saveLoan(upcoming);
    await Store.saveLoan(noDue);
    expect(Store.isOverdue(overdue, now: now), isTrue);
    expect(Store.isOverdue(upcoming, now: now), isFalse);
    expect(Store.isOverdue(noDue, now: now), isFalse);
    // Settled loans are never overdue, even with a past due date.
    await Store.savePayment(LoanPayment(
        id: newId(), loanId: overdue.id, amount: 50000, dateMs: nowMs,
        createdAtMs: nowMs));
    expect(Store.isOverdue(overdue, now: now), isFalse);
    // Sort: due-dated nearest first (past due sorts first, so the
    // user sees the most urgent loan at the top), then no-due loans.
    final sorted = Store.loansSortedByDue('taken')
        .where((l) => [
              overdue.id,
              upcoming.id,
              noDue.id,
            ].contains(l.id))
        .toList();
    expect(sorted.map((l) => l.id).toList(),
        [overdue.id, upcoming.id, noDue.id]);
    await Store.deleteLoan(overdue.id);
    await Store.deleteLoan(upcoming.id);
    await Store.deleteLoan(noDue.id);
  });

  test('v1.1.7: payment timeline running remaining, oldest first',
      () async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final loan = Loan(
      id: newId(),
      personName: 'Timeline Person',
      direction: 'given',
      principal: 100000,
      dateMs: nowMs,
      createdAtMs: nowMs,
    );
    await Store.saveLoan(loan);
    await Store.savePayment(LoanPayment(
        id: newId(), loanId: loan.id, amount: 30000, dateMs: nowMs - 2000,
        createdAtMs: nowMs));
    await Store.savePayment(LoanPayment(
        id: newId(), loanId: loan.id, amount: 20000, dateMs: nowMs - 1000,
        createdAtMs: nowMs));
    final timeline = Store.paymentTimeline(loan.id);
    expect(timeline.length, 2);
    expect(timeline[0].payment.amount, 30000);
    expect(timeline[0].remainingAfter, 70000);
    expect(timeline[1].payment.amount, 20000);
    expect(timeline[1].remainingAfter, 50000);
    await Store.deleteLoan(loan.id);
  });

  test('v1.1.7: witness + note optional round-trip (model + JSON)',
      () async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final loan = Loan(
      id: newId(),
      personName: 'Witness Person',
      direction: 'taken',
      principal: 60000,
      dateMs: nowMs,
      note: 'For shop rent',
      witness: 'Ahmed Khan',
      dueDateMs: nowMs + 86400000,
      createdAtMs: nowMs,
    );
    await Store.saveLoan(loan);
    final readBack = Store.loans.get(loan.id)!;
    expect(readBack.witness, 'Ahmed Khan');
    expect(readBack.note, 'For shop rent');
    expect(readBack.dueDateMs, nowMs + 86400000);
    final fromJson = Loan.fromJson(loan.toJson());
    expect(fromJson.witness, 'Ahmed Khan');
    expect(fromJson.dueDateMs, loan.dueDateMs);
    // Old records without the new fields read as defaults.
    final legacy = Loan.fromJson({
      'id': 'legacy',
      'personName': 'Legacy',
      'direction': 'taken',
      'principal': 1000,
      'dateMs': nowMs,
      'phone': '',
      'note': '',
      'createdAtMs': nowMs,
    });
    expect(legacy.witness, '');
    expect(legacy.dueDateMs, 0);
    await Store.deleteLoan(loan.id);
  });

  test('v1.1.7: vault entry round-trip, search + filter', () async {
    final box = await Hive.openBox('vault_test_box');
    VaultService.useBoxForTest(box);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await VaultService.save(VaultEntry(
      id: newId(),
      title: 'Gmail',
      username: 'shahid@example.com',
      password: 'Secret123!',
      website: 'gmail.com',
      category: 'Login',
      updatedAtMs: nowMs,
    ));
    await VaultService.save(VaultEntry(
      id: newId(),
      title: 'Meezan App',
      username: '0300xxxxxxx',
      password: 'BankPass9#',
      category: 'Bank',
      favourite: true,
      updatedAtMs: nowMs,
    ));
    expect(VaultService.entries.length, 2);
    expect(VaultService.search('gmail').length, 1);
    expect(VaultService.search('meezan').first.category, 'Bank');
    expect(
        VaultService.filtered(category: 'Bank').length, 1);
    expect(VaultService.filtered(favouritesOnly: true).length, 1);
    expect(VaultService.filtered(query: 'zzz'), isEmpty);
    // Generator + strength meter.
    final gen = generateStrongPassword(length: 16);
    expect(gen.length, 16);
    expect(passwordStrength('abc'), 'Weak');
    expect(passwordStrength('StrongPass123!@#'), 'Strong');
    await box.clear();
    await box.close();
  });

  test('v1.1.7: diary journal/task/goal CRUD + snapshot', () async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final entry = JournalEntry(
      id: newId(),
      title: 'First day',
      text: 'Today I started journaling.',
      mood: 'happy',
      dateMs: nowMs,
      createdAtMs: nowMs,
      updatedAtMs: nowMs,
    );
    await Store.saveJournal(entry);
    expect(Store.searchJournal('journaling').length, 1);
    expect(Store.searchJournal('zzz'), isEmpty);
    final task = DiaryTask(
      id: newId(), title: 'Buy groceries', createdAtMs: nowMs);
    await Store.saveDiaryTask(task);
    expect(Store.allDiaryTasks.any((t) => t.id == task.id), isTrue);
    await Store.toggleDiaryTask(task.id);
    expect(Store.diaryTasks.get(task.id)!.done, isTrue);
    final goal = LifeGoal(
      id: newId(), name: 'Read books', stepsTotal: 4, createdAtMs: nowMs);
    await Store.saveLifeGoal(goal);
    goal.stepsDone = 1;
    await Store.saveLifeGoal(goal);
    expect(Store.lifeGoals.get(goal.id)!.progress, 0.25);
    expect(Store.lifeGoals.get(goal.id)!.isDone, isFalse);
    final snap = Store.snapshot();
    expect(
        (snap['journal'] as List)
            .any((j) => (j as Map)['id'] == entry.id),
        isTrue);
    expect(
        (snap['diaryTasks'] as List)
            .any((j) => (j as Map)['id'] == task.id),
        isTrue);
    expect(
        (snap['lifeGoals'] as List)
            .any((j) => (j as Map)['id'] == goal.id),
        isTrue);
    // Diary never touches finance totals.
    expect(
        (snap as Map).containsKey('vault'), isFalse);
    await Store.deleteJournal(entry.id);
    await Store.deleteDiaryTask(task.id);
    await Store.deleteLifeGoal(goal.id);
  });

  testWidgets('v1.1.7: dock shows 6 tabs at 360dp without overflow',
      (tester) async {
    // 360dp phone width — the v1.1.1 overlap must not return.
    // Any RenderFlex overflow throws in a widget test, so a pass
    // here proves the scrollable side groups fit.
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: const SizedBox.expand(),
        bottomNavigationBar: FloatingDock(
          currentIndex: 5,
          onTab: (_) {},
          onAddIncome: () {},
          onAddExpense: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Password Manager'), findsOneWidget);
    expect(find.text('Diary'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    // Profile is the last right-group tab: scroll-to-selected must
    // have brought it into view at 360dp.
    expect(tester.getRect(find.text('Profile')).left, lessThan(360));
  });

  test('v1.1.7: dock scroll-to-selected offset helper', () {
    // 3 items of 64dp, viewport 132dp (360dp screen, two groups).
    const itemWidths = [64.0, 64.0, 64.0];
    const viewport = 132.0;
    // Item 0 already visible at offset 0.
    expect(
        dockScrollOffsetForItem(
          itemIndex: 0,
          itemWidths: itemWidths,
          viewportWidth: viewport,
          currentOffset: 0,
        ),
        0);
    // Item 2 ends at 192 > 132: scroll so it is fully visible.
    expect(
        dockScrollOffsetForItem(
          itemIndex: 2,
          itemWidths: itemWidths,
          viewportWidth: viewport,
          currentOffset: 0,
        ),
        60);
    // Scrolling back: item 0 visible again from offset 60.
    expect(
        dockScrollOffsetForItem(
          itemIndex: 0,
          itemWidths: itemWidths,
          viewportWidth: viewport,
          currentOffset: 60,
        ),
        0);
    // Wide viewport: nothing to scroll.
    expect(
        dockScrollOffsetForItem(
          itemIndex: 2,
          itemWidths: itemWidths,
          viewportWidth: 400,
          currentOffset: 0,
        ),
        0);
  });
}
