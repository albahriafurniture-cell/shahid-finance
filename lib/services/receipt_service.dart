import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Expense receipts (v1.1.4): photos live ONLY in app documents storage
/// (`receipts/<fileName>`). The transaction stores just the file name
/// (MoneyTxn.receiptPath), so the cloud snapshot carries a harmless
/// reference and never photo bytes — a receipt can never break backup,
/// and on a new device an untransferred receipt simply shows as
/// unavailable. Files are kept when a transaction is deleted so Undo
/// restore still has its photo; orphans are harmless.
class ReceiptService {
  static const _dirName = 'receipts';

  static Future<Directory> _dir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$_dirName');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Copy a picked/camera image into app storage. Returns the file name
  /// to store on the transaction, or '' on any failure (the expense
  /// must still save fine with no receipt).
  static Future<String> savePicked(String pickedPath, String txnId) async {
    try {
      final dir = await _dir();
      final ext = pickedPath.contains('.')
          ? pickedPath.substring(pickedPath.lastIndexOf('.'))
          : '.jpg';
      final name = 'receipt_$txnId$ext';
      await File(pickedPath).copy('${dir.path}/$name');
      return name;
    } catch (_) {
      return '';
    }
  }

  static Future<File?> fileFor(String receiptPath) async {
    if (receiptPath.isEmpty) return null;
    // Defensive: only a bare file name is ever trusted.
    if (receiptPath.contains('/') || receiptPath.contains('\\')) {
      return null;
    }
    final dir = await _dir();
    final f = File('${dir.path}/$receiptPath');
    return await f.exists() ? f : null;
  }
}
