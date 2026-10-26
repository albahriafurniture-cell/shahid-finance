import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../utils/format.dart';
import 'models.dart';

const _uuid = Uuid();
String newId() => _uuid.v4();

/// Local-first data store. Everything lives in Hive; the app is fully
/// functional offline and signed out. Cloud backup (services/backup.dart)
/// only snapshots what is here.
class Store {
  static const walletsBox = 'wallets';
  static const txnsBox = 'transactions';
  static const budgetsBox = 'budgets';
  static const categoriesBox = 'categories';
  static const settingsBox = 'settings';
  static const loansBox = 'loans';
  static const loanPaymentsBox = 'loan_payments';

  static late Box<Wallet> wallets;
  static late Box<MoneyTxn> txns;
  static late Box<Budget> budgets;
  static late Box<AppCategory> categories;
  static late Box settings;
  static late Box<Loan> loans;
  static late Box<LoanPayment> loanPayments;

  /// Bumped on every mutation; screens listen and rebuild.
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);
  static void bump() => changes.value++;

  static bool _adaptersRegistered = false;

  static void registerAdapters() {
    if (_adaptersRegistered) return;
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(WalletAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(MoneyTxnAdapter());
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(AppCategoryAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(BudgetAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(LoanAdapter());
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(LoanPaymentAdapter());
    }
    _adaptersRegistered = true;
  }

  static Future<void> init() async {
    await Hive.initFlutter();
    registerAdapters();
    await _openBoxes();
    await seedDefaults();
    // v1.1.2 migration (user order, exact): the profile name is SHAHID.
    // A stored "Shahid Lucky" (any case) is migrated to "SHAHID" once.
    final stored = setting('userName', '');
    if (stored.trim().toLowerCase() == 'shahid lucky') {
      await settings.put('userName', 'SHAHID');
    }
  }

  /// Test/boot path: Hive already initialised against a directory.
  static Future<void> initFromDirectory() async {
    registerAdapters();
    await _openBoxes();
    await seedDefaults();
  }

  static Future<void> _openBoxes() async {
    wallets = await Hive.openBox<Wallet>(walletsBox);
    txns = await Hive.openBox<MoneyTxn>(txnsBox);
    budgets = await Hive.openBox<Budget>(budgetsBox);
    categories = await Hive.openBox<AppCategory>(categoriesBox);
    settings = await Hive.openBox(settingsBox);
    loans = await Hive.openBox<Loan>(loansBox);
    loanPayments = await Hive.openBox<LoanPayment>(loanPaymentsBox);
  }

  // ---------------------------------------------------------------- settings
  static T setting<T>(String key, T fallback) {
    final v = settings.get(key);
    return v is T ? v : fallback;
  }

  static Future<void> setSetting(String key, Object? value) async {
    await settings.put(key, value);
    bump();
  }

  static bool get onboardingDone => setting('onboardingDone', false);
  static String get userName => setting('userName', '');
  static String get userPhone => setting('userPhone', '');
  static bool get pinEnabled => setting('pinEnabled', false);
  static bool get biometricEnabled => setting('biometricEnabled', false);
  static bool get hideAmounts => setting('hideAmounts', false);
  static bool get notifications => setting('notifications', true);
  static bool get budgetAlerts => setting('budgetAlerts', true);
  static bool get weeklySummary => setting('weeklySummary', false);
  static bool get autoBackup => setting('autoBackup', true);
  static int get cycleStartDay => setting('cycleStartDay', 1);
  static String? get lastBackupAtIso => settings.get('lastBackupAt') as String?;
  static String? get backupAccount => settings.get('backupAccount') as String?;

  // ------------------------------------------------------------------- seeds
  static Future<void> seedDefaults() async {
    if (categories.isEmpty) {
      final seed = <AppCategory>[
        _cat('food', 'Food', 'expense', 'restaurant', 0xFFF5A623, 0xFFFDF3E0, 0),
        _cat('groceries', 'Groceries', 'expense', 'shopping_basket', 0xFF0E9F5A,
            0xFFDFF7E8, 1),
        _cat('transport', 'Transport', 'expense', 'directions_car', 0xFF2F7DE1,
            0xFFE7F0FD, 2),
        _cat('shopping', 'Shopping', 'expense', 'shopping_bag', 0xFF9B7EDE,
            0xFFF0EBFC, 3),
        _cat('bills', 'Bills', 'expense', 'receipt_long', 0xFF2BB3A3, 0xFFE2F5F2,
            4),
        _cat('health', 'Health', 'expense', 'medical_services', 0xFFE5484D,
            0xFFFDECEC, 5),
        _cat('entertainment', 'Entertainment', 'expense', 'movie', 0xFFE56AA0,
            0xFFFCE9F2, 6),
        _cat('education', 'Education', 'expense', 'school', 0xFF5B8C5A,
            0xFFEAF3E6, 7),
        _cat('other_expense', 'Other', 'expense', 'more_horiz', 0xFF8795A1,
            0xFFEEF2EF, 8),
        // v1.1.5 income order (user order, exact): SDS, Freelance,
        // Business, Salary, Others.
        _cat('sds', 'SDS', 'income', 'storefront', 0xFF076B3A, 0xFFDFF7E8,
            0),
        _cat('freelance', 'Freelance', 'income', 'laptop_mac', 0xFF9B7EDE,
            0xFFF0EBFC, 1),
        _cat('business', 'Business', 'income', 'storefront', 0xFF2F7DE1,
            0xFFE7F0FD, 2),
        _cat('salary', 'Salary', 'income', 'payments', 0xFF076B3A,
            0xFFDFF7E8, 3),
        _cat('other_income', 'Others', 'income', 'more_horiz', 0xFF8795A1,
            0xFFEEF2EF, 4),
      ];
      for (final c in seed) {
        await categories.put(c.id, c);
      }
    }
    // v1.1.4 migration: "Family" and "My Self" (user's exact spellings)
    // must appear for EXISTING users too, not only fresh installs.
    // v1.1.5: they stay in the box for backward compat (old v1.1.4
    // transactions that used them as a main category still render),
    // but they are no longer offered in the expense picker — they are
    // optional subcategories now (see expensePickerCategories).
    for (final c in [
      _cat('family', 'Family', 'expense', 'group', 0xFFE56AA0, 0xFFFCE9F2, 9),
      _cat('myself', 'My Self', 'expense', 'person', 0xFF00D4FF, 0xFFE0F7FF,
          10),
    ]) {
      if (!categories.containsKey(c.id)) await categories.put(c.id, c);
    }
    // v1.1.5 income migration (existing users): enforce the exact
    // order SDS, Freelance, Business, Salary, Others — add SDS if
    // missing, rename old 'Other' income label to 'Others', reorder
    // by id regardless of the previous sortOrder.
    const incomeOrder = {
      'sds': 0,
      'freelance': 1,
      'business': 2,
      'salary': 3,
      'other_income': 4,
    };
    if (!categories.containsKey('sds')) {
      await categories.put(
          'sds',
          _cat('sds', 'SDS', 'income', 'storefront', 0xFF076B3A,
              0xFFDFF7E8, 0));
    }
    final otherInc = categories.get('other_income');
    if (otherInc != null && otherInc.name == 'Other') {
      otherInc.name = 'Others';
      await categories.put(otherInc.id, otherInc);
    }
    for (final e in incomeOrder.entries) {
      final c = categories.get(e.key);
      if (c != null && c.sortOrder != e.value) {
        c.sortOrder = e.value;
        await categories.put(c.id, c);
      }
    }
    // First-run defaults for scalar settings.
    final defaults = <String, Object>{
      'cycleStartDay': 1,
      'notifications': true,
      'budgetAlerts': true,
      'weeklySummary': false,
      'autoBackup': true,
      'onboardingDone': false,
      'pinEnabled': false,
      'biometricEnabled': false,
      'hideAmounts': false,
    };
    for (final e in defaults.entries) {
      if (!settings.containsKey(e.key)) await settings.put(e.key, e.value);
    }
  }

  static AppCategory _cat(String id, String name, String kind, String icon,
          int strong, int tint, int order) =>
      AppCategory(
        id: id,
        name: name,
        kind: kind,
        iconKey: icon,
        strongColor: strong,
        tintColor: tint,
        sortOrder: order,
      );

  /// Creates the four first-class wallets with ZERO balances (the mockup
  /// figures are design samples, never app data). Easypaisa is the default.
  static Future<void> seedWallets() async {
    if (wallets.isNotEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final seed = <Wallet>[
      Wallet(
          id: newId(),
          name: 'Easypaisa',
          type: 'easypaisa',
          isDefault: true,
          createdAtMs: now),
      Wallet(id: newId(), name: 'Cash', type: 'cash', createdAtMs: now),
      Wallet(id: newId(), name: 'JazzCash', type: 'jazzcash', createdAtMs: now),
      Wallet(id: newId(), name: 'Meezan', type: 'bank', createdAtMs: now),
    ];
    for (final w in seed) {
      await wallets.put(w.id, w);
    }
    bump();
  }

  // ----------------------------------------------------------------- wallets
  static List<Wallet> get allWallets => wallets.values.toList();

  static List<Wallet> get activeWallets {
    final list = wallets.values.where((w) => !w.archived).toList();
    list.sort((a, b) {
      if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
      return balanceOf(b.id).compareTo(balanceOf(a.id));
    });
    return list;
  }

  static Wallet? walletById(String id) => wallets.get(id);

  static Wallet? get defaultWallet {
    for (final w in wallets.values) {
      if (w.isDefault && !w.archived) return w;
    }
    final active = activeWallets;
    return active.isEmpty ? null : active.first;
  }

  static int balanceOf(String walletId) {
    final w = wallets.get(walletId);
    if (w == null) return 0;
    var bal = w.openingBalance;
    for (final t in txns.values) {
      bal += t.effectOn(walletId);
    }
    return bal;
  }

  static int get totalBalance =>
      activeWallets.fold(0, (sum, w) => sum + balanceOf(w.id));

  static int txnCountForWallet(String walletId) {
    // Counting rule (spec §1.10): a transfer counts once in the grand
    // total but appears in both wallets' counts.
    var n = 0;
    for (final t in txns.values) {
      if (t.walletId == walletId || t.toWalletId == walletId) n++;
    }
    return n;
  }

  static Future<void> saveWallet(Wallet w) async {
    await wallets.put(w.id, w);
    bump();
  }

  static Future<void> setDefaultWallet(String id) async {
    for (final w in wallets.values) {
      final nd = w.id == id;
      if (w.isDefault != nd) {
        w.isDefault = nd;
        await wallets.put(w.id, w);
      }
    }
    bump();
  }

  // ------------------------------------------------------------- transactions
  static List<MoneyTxn> get allTxnsDesc {
    final list = txns.values.toList();
    list.sort((a, b) {
      final d = b.dateMs.compareTo(a.dateMs);
      return d != 0 ? d : b.createdAtMs.compareTo(a.createdAtMs);
    });
    return list;
  }

  static Future<void> saveTxn(MoneyTxn t) async {
    await txns.put(t.id, t);
    bump();
  }

  static Future<MoneyTxn?> deleteTxn(String id) async {
    final t = txns.get(id);
    if (t != null) {
      await txns.delete(id);
      bump();
    }
    return t;
  }

  /// Running balance of each transaction's wallet right after it landed.
  /// Returns map txnId -> balance-after for the source wallet.
  static Map<String, int> runningBalances() {
    final result = <String, int>{};
    final byWallet = <String, List<MoneyTxn>>{};
    for (final t in txns.values) {
      byWallet.putIfAbsent(t.walletId, () => []).add(t);
    }
    byWallet.forEach((walletId, list) {
      list.sort((a, b) {
        final d = a.dateMs.compareTo(b.dateMs);
        return d != 0 ? d : a.createdAtMs.compareTo(b.createdAtMs);
      });
      var bal = wallets.get(walletId)?.openingBalance ?? 0;
      for (final t in list) {
        bal += t.effectOn(walletId);
        result[t.id] = bal;
      }
    });
    return result;
  }

  static int sumIn(Iterable<MoneyTxn> list) =>
      list.where((t) => t.isIncome).fold(0, (s, t) => s + t.amount);

  static int sumOut(Iterable<MoneyTxn> list) =>
      list.where((t) => t.isExpense).fold(0, (s, t) => s + t.amount);

  static List<MoneyTxn> txnsInMonth(int year, int month) {
    return txns.values
        .where((t) => t.date.year == year && t.date.month == month)
        .toList();
  }

  static List<MoneyTxn> txnsInCycle(Cycle c) =>
      txns.values.where((t) => c.contains(t.date)).toList();

  static Future<void> transfer({
    required Wallet from,
    required Wallet to,
    required int amount,
  }) async {
    final now = DateTime.now();
    await saveTxn(MoneyTxn(
      id: newId(),
      type: 'transfer',
      amount: amount,
      walletId: from.id,
      toWalletId: to.id,
      note: '',
      dateMs: now.millisecondsSinceEpoch,
      createdAtMs: now.millisecondsSinceEpoch,
    ));
  }

  static Future<void> adjustBalance({
    required Wallet wallet,
    required int newBalance,
    required String reason,
  }) async {
    final delta = newBalance - balanceOf(wallet.id);
    if (delta == 0) return;
    final now = DateTime.now();
    await saveTxn(MoneyTxn(
      id: newId(),
      type: 'adjustment',
      amount: delta,
      walletId: wallet.id,
      note: reason.isEmpty ? 'Balance adjustment' : reason,
      dateMs: now.millisecondsSinceEpoch,
      createdAtMs: now.millisecondsSinceEpoch,
    ));
  }

  // ---------------------------------------------------------------- budgets
  static List<Budget> get allBudgets => budgets.values.toList();

  static Budget? budgetForCategory(String categoryId) {
    for (final b in budgets.values) {
      if (b.categoryId == categoryId) return b;
    }
    return null;
  }

  static Future<void> saveBudget(Budget b) async {
    await budgets.put(b.id, b);
    bump();
  }

  static Future<void> deleteBudget(String id) async {
    await budgets.delete(id);
    bump();
  }

  static int spentForCategoryInCycle(String categoryId, Cycle c) {
    return txnsInCycle(c)
        .where((t) => t.isExpense && t.categoryId == categoryId)
        .fold(0, (s, t) => s + t.amount);
  }

  // -------------------------------------------------------------- categories
  static List<AppCategory> categoriesFor(String kind) {
    final list = categories.values
        .where((c) => c.kind == kind && !c.archived)
        .toList();
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  static AppCategory? categoryById(String id) => categories.get(id);

  /// v1.1.5: ids that stopped being main expense categories and
  /// became optional subcategories. Kept in the box (old transactions
  /// still resolve through categoryById); only the picker hides them.
  static const subCategoryIds = {'family', 'myself'};

  /// Expense categories offered in the Add Expense picker: main
  /// categories only — Family / My Self are subcategories now.
  static List<AppCategory> expensePickerCategories() => categoriesFor('expense')
      .where((c) => !subCategoryIds.contains(c.id))
      .toList();

  /// Optional expense subcategory labels, in display order.
  static const expenseSubCategories = ['Family', 'My Self'];

  // ------------------------------------------------------------------- loans
  /// Loans are a SEPARATE tracker: creating a loan or a payment never
  /// touches wallets, transactions, income or expense totals — the
  /// helpers below only read/write the loans boxes.
  static List<Loan> get allLoans {
    final list = loans.values.toList();
    list.sort((a, b) => b.dateMs.compareTo(a.dateMs));
    return list;
  }

  static List<Loan> loansFor(String direction) =>
      allLoans.where((l) => l.direction == direction).toList();

  static List<LoanPayment> paymentsFor(String loanId) {
    final list =
        loanPayments.values.where((p) => p.loanId == loanId).toList();
    list.sort((a, b) => b.dateMs.compareTo(a.dateMs));
    return list;
  }

  static int paidFor(String loanId) =>
      paymentsFor(loanId).fold(0, (s, p) => s + p.amount);

  static int remainingFor(Loan loan) =>
      (loan.principal - paidFor(loan.id)).clamp(0, loan.principal);

  static bool isSettled(Loan loan) => remainingFor(loan) <= 0;

  static int outstandingFor(String direction) =>
      loansFor(direction).fold(0, (s, l) => s + remainingFor(l));

  static Future<void> saveLoan(Loan loan) async {
    await loans.put(loan.id, loan);
    bump();
  }

  static Future<void> deleteLoan(String id) async {
    for (final p in paymentsFor(id)) {
      await loanPayments.delete(p.id);
    }
    await loans.delete(id);
    bump();
  }

  static Future<void> savePayment(LoanPayment payment) async {
    await loanPayments.put(payment.id, payment);
    bump();
  }

  static Future<void> deletePayment(String id) async {
    await loanPayments.delete(id);
    bump();
  }

  /// Unique category count (Other is shared between kinds) — "12 categories".
  static int get uniqueCategoryCount =>
      categories.values.where((c) => !c.archived).map((c) => c.name).toSet().length;

  // ------------------------------------------------------------- backup / csv
  static Map<String, dynamic> snapshot() {
    return {
      'app': 'shahid-finance',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'wallets': allWallets.map((w) => w.toJson()).toList(),
      'transactions': txns.values.map((t) => t.toJson()).toList(),
      'budgets': allBudgets.map((b) => b.toJson()).toList(),
      'categories': categories.values.map((c) => c.toJson()).toList(),
      'loans': loans.values.map((l) => l.toJson()).toList(),
      'loanPayments': loanPayments.values.map((p) => p.toJson()).toList(),
      'settings': {
        for (final k in settings.keys) k as String: settings.get(k),
      },
    };
  }

  static Future<void> restoreFrom(Map<String, dynamic> snap) async {
    await wallets.clear();
    await txns.clear();
    await budgets.clear();
    await categories.clear();
    await loans.clear();
    await loanPayments.clear();
    for (final j in (snap['wallets'] as List? ?? [])) {
      final w = Wallet.fromJson(Map<String, dynamic>.from(j as Map));
      await wallets.put(w.id, w);
    }
    for (final j in (snap['transactions'] as List? ?? [])) {
      final t = MoneyTxn.fromJson(Map<String, dynamic>.from(j as Map));
      await txns.put(t.id, t);
    }
    for (final j in (snap['budgets'] as List? ?? [])) {
      final b = Budget.fromJson(Map<String, dynamic>.from(j as Map));
      await budgets.put(b.id, b);
    }
    for (final j in (snap['categories'] as List? ?? [])) {
      final c = AppCategory.fromJson(Map<String, dynamic>.from(j as Map));
      await categories.put(c.id, c);
    }
    for (final j in (snap['loans'] as List? ?? [])) {
      final l = Loan.fromJson(Map<String, dynamic>.from(j as Map));
      await loans.put(l.id, l);
    }
    for (final j in (snap['loanPayments'] as List? ?? [])) {
      final p = LoanPayment.fromJson(Map<String, dynamic>.from(j as Map));
      await loanPayments.put(p.id, p);
    }
    final savedSettings = snap['settings'];
    if (savedSettings is Map) {
      for (final e in savedSettings.entries) {
        // Never restore secrets (PIN hash) onto a device from a snapshot.
        if (e.key == 'pinHash' || e.key == 'pinSalt') continue;
        await settings.put(e.key as String, e.value);
      }
    }
    await seedDefaults();
    bump();
  }

  static String exportCsv() {
    final sb = StringBuffer();
    sb.writeln('Date,Type,Category,Wallet,To Wallet,Note,Amount (PKR)');
    String esc(String s) =>
        s.contains(',') || s.contains('"') ? '"${s.replaceAll('"', '""')}"' : s;
    for (final t in allTxnsDesc) {
      final cat = categoryById(t.categoryId)?.name ?? '';
      final w = walletById(t.walletId)?.name ?? '';
      final tw = t.toWalletId.isEmpty ? '' : (walletById(t.toWalletId)?.name ?? '');
      final signed = t.isExpense
          ? -t.amount
          : t.isAdjustment
              ? t.amount
              : t.amount;
      sb.writeln([
        fmtDate(t.date),
        t.type,
        esc(cat),
        esc(w),
        esc(tw),
        esc(t.note),
        signed,
      ].join(','));
    }
    return sb.toString();
  }
}
