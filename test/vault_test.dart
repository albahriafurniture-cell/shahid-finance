import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shahid_finance/data/vault.dart';
import 'package:shahid_finance/services/vault_service.dart';
import 'package:shahid_finance/utils/password_generator.dart';

void main() {
  test('Strong password generator: 16 chars, all classes, varies', () {
    final a = generateStrongPassword();
    final b = generateStrongPassword(random: Random(42));
    expect(a.length, 16);
    expect(a.contains(RegExp(r'[A-Z]')), isTrue);
    expect(a.contains(RegExp(r'[a-z]')), isTrue);
    expect(a.contains(RegExp(r'[0-9]')), isTrue);
    expect(a.contains(RegExp(r'[^A-Za-z0-9]')), isTrue);
    expect(passwordStrength(a), 'Strong');
    expect(a, isNot(equals(b)));
  });

  test('Vault entry map round-trip preserves every field', () {
    final e = VaultEntry(
      id: 'v1',
      title: 'Meezan',
      username: 'shahid@example.com',
      password: 'S3cret!x',
      website: 'https://meezanbank.com',
      category: 'Bank',
      notes: 'main account',
      favourite: true,
      createdAtMs: 1000,
      updatedAtMs: 2000,
    );
    final back = VaultEntry.fromMap(e.toMap());
    expect(back.title, 'Meezan');
    expect(back.username, 'shahid@example.com');
    expect(back.password, 'S3cret!x');
    expect(back.website, 'https://meezanbank.com');
    expect(back.category, 'Bank');
    expect(back.notes, 'main account');
    expect(back.favourite, isTrue);
    expect(back.createdAtMs, 1000);
    expect(vaultCategories, contains('Bank'));
  });

  test('Encrypted box round-trip via HiveAesCipher', () async {
    final dir = await Directory.systemTemp.createTemp('sf_vault_test_');
    addTearDown(() async {
      await Hive.close();
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    Hive.init(dir.path);
    final key = Hive.generateSecureKey();
    final box = await Hive.openBox(
      'passwords',
      encryptionCipher: HiveAesCipher(key),
    );
    VaultService.useBoxForTest(box);
    final entry = VaultEntry(
      id: 'v2',
      title: 'Gmail',
      username: 'shahid@example.com',
      password: 'P@ssw0rd123456',
      category: 'Email',
      createdAtMs: 1,
      updatedAtMs: 1,
    );
    await VaultService.save(entry);
    expect(VaultService.search('gmail').length, 1);
    expect(VaultService.search('gmail').first.password, 'P@ssw0rd123456');
    await VaultService.delete('v2');
    expect(VaultService.entries, isEmpty);
  });
}
