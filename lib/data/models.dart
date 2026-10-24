import 'package:hive/hive.dart';

/// Data models with hand-written Hive TypeAdapters (no build_runner).
/// Balances are always DERIVED from transactions — a wallet stores only its
/// opening balance, so totals can never disagree with history.

class Wallet {
  String id;
  String name;
  String type; // cash | easypaisa | jazzcash | bank | other
  String last4; // '' when not applicable
  bool isDefault;
  bool archived;
  int openingBalance;
  int createdAtMs;

  Wallet({
    required this.id,
    required this.name,
    required this.type,
    this.last4 = '',
    this.isDefault = false,
    this.archived = false,
    this.openingBalance = 0,
    required this.createdAtMs,
  });

  String get caption {
    switch (type) {
      case 'cash':
        return 'Cash wallet';
      case 'easypaisa':
      case 'jazzcash':
        return last4.isEmpty ? 'Mobile wallet' : 'Mobile wallet · •••$last4';
      case 'bank':
        return last4.isEmpty ? 'Bank account' : 'Bank account · ••$last4';
      default:
        return 'Wallet';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'last4': last4,
        'isDefault': isDefault,
        'archived': archived,
        'openingBalance': openingBalance,
        'createdAtMs': createdAtMs,
      };

  factory Wallet.fromJson(Map<String, dynamic> j) => Wallet(
        id: j['id'] as String,
        name: j['name'] as String,
        type: j['type'] as String,
        last4: (j['last4'] as String?) ?? '',
        isDefault: (j['isDefault'] as bool?) ?? false,
        archived: (j['archived'] as bool?) ?? false,
        openingBalance: (j['openingBalance'] as num?)?.toInt() ?? 0,
        createdAtMs: (j['createdAtMs'] as num?)?.toInt() ?? 0,
      );
}

class WalletAdapter extends TypeAdapter<Wallet> {
  @override
  final int typeId = 0;

  @override
  Wallet read(BinaryReader reader) {
    return Wallet(
      id: reader.readString(),
      name: reader.readString(),
      type: reader.readString(),
      last4: reader.readString(),
      isDefault: reader.readBool(),
      archived: reader.readBool(),
      openingBalance: reader.readInt(),
      createdAtMs: reader.readInt(),
    );
  }

  @override
  void write(BinaryWriter writer, Wallet obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.name);
    writer.writeString(obj.type);
    writer.writeString(obj.last4);
    writer.writeBool(obj.isDefault);
    writer.writeBool(obj.archived);
    writer.writeInt(obj.openingBalance);
    writer.writeInt(obj.createdAtMs);
  }
}

/// A single money movement. type: income | expense | transfer | adjustment.
/// amount is positive for income/expense/transfer and SIGNED for adjustment.
class MoneyTxn {
  String id;
  String type;
  int amount;
  String walletId;
  String toWalletId; // transfer only, '' otherwise
  String categoryId;
  String note;
  int dateMs; // when the transaction happened
  int createdAtMs;

  MoneyTxn({
    required this.id,
    required this.type,
    required this.amount,
    required this.walletId,
    this.toWalletId = '',
    this.categoryId = '',
    this.note = '',
    required this.dateMs,
    required this.createdAtMs,
  });

  DateTime get date => DateTime.fromMillisecondsSinceEpoch(dateMs);
  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';
  bool get isTransfer => type == 'transfer';
  bool get isAdjustment => type == 'adjustment';

  /// Signed effect of this transaction on [walletId]'s balance.
  int effectOn(String walletId) {
    if (isIncome) return this.walletId == walletId ? amount : 0;
    if (isExpense) return this.walletId == walletId ? -amount : 0;
    if (isAdjustment) return this.walletId == walletId ? amount : 0;
    if (isTransfer) {
      if (this.walletId == walletId) return -amount;
      if (toWalletId == walletId) return amount;
    }
    return 0;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'amount': amount,
        'walletId': walletId,
        'toWalletId': toWalletId,
        'categoryId': categoryId,
        'note': note,
        'dateMs': dateMs,
        'createdAtMs': createdAtMs,
      };

  factory MoneyTxn.fromJson(Map<String, dynamic> j) => MoneyTxn(
        id: j['id'] as String,
        type: j['type'] as String,
        amount: (j['amount'] as num).toInt(),
        walletId: j['walletId'] as String,
        toWalletId: (j['toWalletId'] as String?) ?? '',
        categoryId: (j['categoryId'] as String?) ?? '',
        note: (j['note'] as String?) ?? '',
        dateMs: (j['dateMs'] as num).toInt(),
        createdAtMs: (j['createdAtMs'] as num?)?.toInt() ?? 0,
      );
}

class MoneyTxnAdapter extends TypeAdapter<MoneyTxn> {
  @override
  final int typeId = 1;

  @override
  MoneyTxn read(BinaryReader reader) {
    return MoneyTxn(
      id: reader.readString(),
      type: reader.readString(),
      amount: reader.readInt(),
      walletId: reader.readString(),
      toWalletId: reader.readString(),
      categoryId: reader.readString(),
      note: reader.readString(),
      dateMs: reader.readInt(),
      createdAtMs: reader.readInt(),
    );
  }

  @override
  void write(BinaryWriter writer, MoneyTxn obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.type);
    writer.writeInt(obj.amount);
    writer.writeString(obj.walletId);
    writer.writeString(obj.toWalletId);
    writer.writeString(obj.categoryId);
    writer.writeString(obj.note);
    writer.writeInt(obj.dateMs);
    writer.writeInt(obj.createdAtMs);
  }
}

class AppCategory {
  String id;
  String name;
  String kind; // expense | income
  String iconKey;
  int strongColor;
  int tintColor;
  bool archived;
  int sortOrder;

  AppCategory({
    required this.id,
    required this.name,
    required this.kind,
    required this.iconKey,
    required this.strongColor,
    required this.tintColor,
    this.archived = false,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind,
        'iconKey': iconKey,
        'strongColor': strongColor,
        'tintColor': tintColor,
        'archived': archived,
        'sortOrder': sortOrder,
      };

  factory AppCategory.fromJson(Map<String, dynamic> j) => AppCategory(
        id: j['id'] as String,
        name: j['name'] as String,
        kind: j['kind'] as String,
        iconKey: j['iconKey'] as String,
        strongColor: (j['strongColor'] as num).toInt(),
        tintColor: (j['tintColor'] as num).toInt(),
        archived: (j['archived'] as bool?) ?? false,
        sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
      );
}

class AppCategoryAdapter extends TypeAdapter<AppCategory> {
  @override
  final int typeId = 2;

  @override
  AppCategory read(BinaryReader reader) {
    return AppCategory(
      id: reader.readString(),
      name: reader.readString(),
      kind: reader.readString(),
      iconKey: reader.readString(),
      strongColor: reader.readInt(),
      tintColor: reader.readInt(),
      archived: reader.readBool(),
      sortOrder: reader.readInt(),
    );
  }

  @override
  void write(BinaryWriter writer, AppCategory obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.name);
    writer.writeString(obj.kind);
    writer.writeString(obj.iconKey);
    writer.writeInt(obj.strongColor);
    writer.writeInt(obj.tintColor);
    writer.writeBool(obj.archived);
    writer.writeInt(obj.sortOrder);
  }
}

/// A monthly budget template for one category — applies to every cycle
/// (budgets copy forward, per spec).
class Budget {
  String id;
  String categoryId;
  int limitAmount;
  bool warnAt80;

  Budget({
    required this.id,
    required this.categoryId,
    required this.limitAmount,
    this.warnAt80 = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'categoryId': categoryId,
        'limitAmount': limitAmount,
        'warnAt80': warnAt80,
      };

  factory Budget.fromJson(Map<String, dynamic> j) => Budget(
        id: j['id'] as String,
        categoryId: j['categoryId'] as String,
        limitAmount: (j['limitAmount'] as num).toInt(),
        warnAt80: (j['warnAt80'] as bool?) ?? true,
      );
}

class BudgetAdapter extends TypeAdapter<Budget> {
  @override
  final int typeId = 3;

  @override
  Budget read(BinaryReader reader) {
    return Budget(
      id: reader.readString(),
      categoryId: reader.readString(),
      limitAmount: reader.readInt(),
      warnAt80: reader.readBool(),
    );
  }

  @override
  void write(BinaryWriter writer, Budget obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.categoryId);
    writer.writeInt(obj.limitAmount);
    writer.writeBool(obj.warnAt80);
  }
}
