import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../data/store.dart';

class BackupException implements Exception {
  final String message;
  BackupException(this.message);
  @override
  String toString() => message;
}

/// Cloud backup — Firebase Auth (Google + Email/Password) + Firestore.
///
/// The snapshot lives at users/{uid}/backup/data as a single document
/// holding the full JSON export of the local Hive store plus an
/// `updatedAt` server timestamp.
///
/// HARD RULE: the app must run perfectly with no google-services.json.
/// [init] is wrapped in try/catch; when Firebase is not configured every
/// method here throws a friendly [BackupException] and the UI shows
/// "Cloud backup is not configured on this build" — local features are
/// never affected.
class BackupService {
  static bool ready = false;
  static String? initError;

  /// Web OAuth client (type 3) from google-services.json — passed as
  /// serverClientId so Firebase reliably receives an idToken.
  static const webClientId =
      '132852240377-aqrgp73r00aim7dhsof779pnqobqs0me.apps.googleusercontent.com';

  static GoogleSignIn _googleSignIn() =>
      GoogleSignIn(serverClientId: webClientId);

  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
      ready = true;
    } catch (e) {
      ready = false;
      initError = e.toString();
    }
  }

  static void _requireReady() {
    if (!ready) {
      throw BackupException('Cloud backup is not configured on this build.');
    }
  }

  static User? get currentUser =>
      ready ? FirebaseAuth.instance.currentUser : null;

  static bool get isSignedIn => currentUser != null;

  static Stream<User?> authState() {
    if (!ready) return Stream.value(null);
    return FirebaseAuth.instance.authStateChanges();
  }

  static String _friendly(Object e) {
    final text = e.toString();
    // Google Play services ApiException 10 = DEVELOPER_ERROR: the APK's
    // signing SHA-1 is not registered for this OAuth client. Only a
    // release-signed build (the 9B:5D:…:2E keystore) can Google-sign-in.
    // v1.1.1 fix: google_sign_in 6.3 does NOT throw ApiException here —
    // it throws PlatformException(sign_in_failed, "10: ..."), which is
    // exactly what the user's v1.1.0 screenshot showed raw. Match error
    // 10 in EVERY form, and never surface a raw PlatformException string.
    final platformMsg =
        e is PlatformException ? (e.message ?? '') : '';
    final isError10 = text.contains('ApiException: 10') ||
        text.contains('statusCode: 10') ||
        text.contains('DEVELOPER_ERROR') ||
        (e is PlatformException &&
            e.code == 'sign_in_failed' &&
            (platformMsg.contains('10') ||
                RegExp(r'(^|[^0-9])10([^0-9]|$)').hasMatch(platformMsg))) ||
        RegExp(r'sign_in_failed[^)]*\b10\b').hasMatch(text);
    if (isError10) {
      return 'Google sign-in failed (error 10): this build is not signed '
          'with the registered release key. Install the release-signed APK '
          'from the official link, not a debug build.';
    }
    if (e is PlatformException) {
      // Any other platform-level sign-in failure: plain words only,
      // never the raw "PlatformException(...)" string.
      return 'Google sign-in failed. Please try again — and make sure you '
          'are using the release-signed APK from the official link, not a '
          'debug build.';
    }
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          return 'That email address looks invalid.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Email or password is incorrect. If you never created an '
              'account with this email, tap “Create account” below.';
        case 'email-already-in-use':
          return 'An account with this email already exists. Sign in instead.';
        case 'weak-password':
          return 'Password is too weak — use at least 6 characters.';
        case 'network-request-failed':
          return 'No internet connection. Try again when you are online.';
        case 'operation-not-allowed':
          return 'This sign-in method is not enabled for Shahid Finance '
              '(code: operation-not-allowed).';
        case 'too-many-requests':
          return 'Too many attempts — wait a few minutes and try again.';
        case 'user-disabled':
          return 'This account has been disabled (code: user-disabled).';
        default:
          final detail = e.message ?? 'Sign-in failed. Please try again.';
          return '$detail (code: ${e.code})';
      }
    }
    // Generic fallback — plain words only, never a raw exception string.
    return 'Sign-in failed. Please try again.';
  }

  static Future<void> signInWithEmail(String email, String password) async {
    _requireReady();
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email.trim(), password: password);
    } catch (e) {
      throw BackupException(_friendly(e));
    }
  }

  static Future<void> createAccountWithEmail(
      String email, String password) async {
    _requireReady();
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email.trim(), password: password);
    } catch (e) {
      throw BackupException(_friendly(e));
    }
  }

  static Future<void> signInWithGoogle() async {
    _requireReady();
    try {
      final googleUser = await _googleSignIn().signIn();
      if (googleUser == null) {
        throw BackupException('Google sign-in was cancelled.');
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
    } on BackupException {
      rethrow;
    } catch (e) {
      throw BackupException(_friendly(e));
    }
  }

  static Future<void> sendPasswordReset(String email) async {
    _requireReady();
    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: email.trim());
    } catch (e) {
      throw BackupException(_friendly(e));
    }
  }

  static Future<void> signOut() async {
    _requireReady();
    try {
      await _googleSignIn().signOut();
    } catch (_) {
      // Not signed in with Google — nothing to undo.
    }
    await FirebaseAuth.instance.signOut();
    await Store.setSetting('backupAccount', null);
  }

  static DocumentReference<Map<String, dynamic>> _backupDoc(String uid) =>
      FirebaseFirestore.instance.doc('users/$uid/backup/data');

  /// Writes the full local snapshot to the cloud and stamps the local
  /// last-backup time. Returns the backup time.
  static Future<DateTime> backupNow() async {
    _requireReady();
    final user = currentUser;
    if (user == null) throw BackupException('Sign in first to back up.');
    final snapshot = Store.snapshot();
    await _backupDoc(user.uid).set({
      'data': snapshot,
      'updatedAt': FieldValue.serverTimestamp(),
      'appVersion': '1.1.2',
    });
    final now = DateTime.now();
    await Store.settings.put('lastBackupAt', now.toIso8601String());
    await Store.settings.put('backupAccount', user.email ?? user.uid);
    Store.bump();
    return now;
  }

  /// The cloud backup's timestamp, or null when none exists.
  static Future<DateTime?> cloudBackupTime() async {
    _requireReady();
    final user = currentUser;
    if (user == null) return null;
    final doc = await _backupDoc(user.uid).get();
    if (!doc.exists) return null;
    final ts = doc.data()?['updatedAt'];
    if (ts is Timestamp) return ts.toDate();
    return null;
  }

  static Future<bool> hasCloudBackup() async =>
      (await cloudBackupTime()) != null;

  /// Replaces ALL local data with the cloud snapshot (confirm dialog is
  /// the caller's job).
  static Future<void> restoreNow() async {
    _requireReady();
    final user = currentUser;
    if (user == null) throw BackupException('Sign in first to restore.');
    final doc = await _backupDoc(user.uid).get();
    final data = doc.data()?['data'];
    if (data == null) {
      throw BackupException('No cloud backup found for this account.');
    }
    await Store.restoreFrom(Map<String, dynamic>.from(data as Map));
    await Store.settings.put('lastBackupAt', DateTime.now().toIso8601String());
    await Store.settings.put('backupAccount', user.email ?? user.uid);
    Store.bump();
  }
}
