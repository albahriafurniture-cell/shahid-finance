import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/store.dart';

/// v1.1.7: encrypted local password vault, restored from the v1.1.0
/// pattern (the vault was removed from this app in v1.1.2 and is now
/// back as a dock tab at the user's explicit order).
///
/// The AES key is generated once and kept ONLY in
/// flutter_secure_storage (never in Hive, files, or notes); the
/// `passwords` box is opened with HiveAesCipher. Vault entries live
/// ONLY on this phone — they are deliberately NEVER included in the
/// cloud backup snapshot, so a vault can never leak through Firestore
/// and a restore can never overwrite it.
class VaultEntry {
  String id;
  String title;
  String username;
  String password;
  String website;
  String category; // Login, Bank, Card, Social, Work, Other
  String note;
  bool favourite;
  int updatedAtMs;

  VaultEntry({
    required this.id,
    required this.title,
    this.username = '',
    this.password = '',
    this.website = '',
    this.category = 'Login',
    this.note = '',
    this.favourite = false,
    required this.updatedAtMs,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'username': username,
        'password': password,
        'website': website,
        'category': category,
        'note': note,
        'favourite': favourite,
        'updatedAtMs': updatedAtMs,
      };

  factory VaultEntry.fromMap(Map<String, dynamic> m) => VaultEntry(
        id: (m['id'] as String?) ?? '',
        title: (m['title'] as String?) ?? '',
        username: (m['username'] as String?) ?? '',
        password: (m['password'] as String?) ?? '',
        website: (m['website'] as String?) ?? '',
        category: (m['category'] as String?) ?? 'Login',
        note: (m['note'] as String?) ?? '',
        favourite: (m['favourite'] as bool?) ?? false,
        updatedAtMs: (m['updatedAtMs'] as num?)?.toInt() ?? 0,
      );
}

/// Vault categories, in display order.
const vaultCategories = ['Login', 'Bank', 'Card', 'Social', 'Work', 'Other'];

class VaultService {
  static const _keyName = 'vault_aes_key';
  static const _storage = FlutterSecureStorage();
  static Box? _box;
  static String? initError;

  static Box? get box => _box;
  static bool get ready => _box != null && _box!.isOpen;

  /// Test seam: inject an already-opened (plain, in-test) box.
  static void useBoxForTest(Box box) => _box = box;

  /// Test seam: simulate a vault that never opened (init failed).
  static void resetForTest() {
    _box = null;
    initError = null;
  }

  static Future<void> init() async {
    try {
      var encoded = await _storage.read(key: _keyName);
      if (encoded == null) {
        final key = Hive.generateSecureKey();
        await _storage.write(key: _keyName, value: base64Encode(key));
        encoded = base64Encode(key);
      }
      final key = base64Decode(encoded);
      _box = await Hive.openBox(
        'passwords',
        encryptionCipher: HiveAesCipher(key),
      );
      initError = null;
    } catch (e) {
      initError = e.toString();
      _box = null;
    }
  }

  static List<VaultEntry> get entries {
    if (!ready) return [];
    final list = _box!.values
        .map((v) => VaultEntry.fromMap(Map<String, dynamic>.from(v as Map)))
        .toList();
    list.sort((a, b) {
      if (a.favourite != b.favourite) return a.favourite ? -1 : 1;
      return b.updatedAtMs.compareTo(a.updatedAtMs);
    });
    return list;
  }

  /// Search by title / username / website / category (case-insensitive).
  static List<VaultEntry> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return entries;
    return entries
        .where((e) =>
            e.title.toLowerCase().contains(q) ||
            e.username.toLowerCase().contains(q) ||
            e.website.toLowerCase().contains(q) ||
            e.category.toLowerCase().contains(q))
        .toList();
  }

  /// Combined filter used by the tab: query + category + favourites.
  static List<VaultEntry> filtered({
    String query = '',
    String category = 'All',
    bool favouritesOnly = false,
  }) {
    var list = search(query);
    if (category != 'All') {
      list = list.where((e) => e.category == category).toList();
    }
    if (favouritesOnly) {
      list = list.where((e) => e.favourite).toList();
    }
    return list;
  }

  static Future<void> save(VaultEntry entry) async {
    if (!ready) throw StateError('Vault is not ready');
    entry.updatedAtMs = DateTime.now().millisecondsSinceEpoch;
    await _box!.put(entry.id, entry.toMap());
    Store.bump();
  }

  static Future<void> delete(String id) async {
    if (!ready) return;
    await _box!.delete(id);
    Store.bump();
  }
}
