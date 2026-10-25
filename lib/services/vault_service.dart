import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/store.dart';
import '../data/vault.dart';

/// Encrypted local password vault. The AES key is generated once and
/// kept ONLY in flutter_secure_storage (never in Hive, files or notes);
/// the `passwords` box is opened with HiveAesCipher. No cloud sync of
/// vault entries in this version — local encrypted only.
class VaultService {
  static const _keyName = 'vault_aes_key';
  static const _storage = FlutterSecureStorage();
  static Box? _box;
  static String? initError;

  static Box? get box => _box;
  static bool get ready => _box != null && _box!.isOpen;

  /// Test seam: inject an already-opened (encrypted) box.
  static void useBoxForTest(Box box) => _box = box;

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
