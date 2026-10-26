import 'dart:math';

/// v1.1.7: strong password generator + strength meter for the
/// Password Manager tab. Ambiguous characters (I, l, O, 0, 1) are
/// excluded so generated passwords stay readable.
const _upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
const _lower = 'abcdefghijkmnpqrstuvwxyz';
const _digits = '23456789';
const _symbols = '!@#\$%^&*()-_=+';

String generateStrongPassword({
  int length = 16,
  bool letters = true,
  bool numbers = true,
  bool symbols = true,
  Random? random,
}) {
  final r = random ?? Random.secure();
  final len = length < 8 ? 8 : length;
  var pool = '';
  final chars = <String>[];
  if (letters) {
    pool += _upper + _lower;
    chars.add(_upper[r.nextInt(_upper.length)]);
    chars.add(_lower[r.nextInt(_lower.length)]);
  }
  if (numbers) {
    pool += _digits;
    chars.add(_digits[r.nextInt(_digits.length)]);
  }
  if (symbols) {
    pool += _symbols;
    chars.add(_symbols[r.nextInt(_symbols.length)]);
  }
  if (pool.isEmpty) pool = _lower;
  while (chars.length < len) {
    chars.add(pool[r.nextInt(pool.length)]);
  }
  chars.shuffle(r);
  return chars.join();
}

/// Strength in three bands the UI shows: weak / medium / strong.
String passwordStrength(String password) {
  var classes = 0;
  if (password.contains(RegExp(r'[A-Z]'))) classes++;
  if (password.contains(RegExp(r'[a-z]'))) classes++;
  if (password.contains(RegExp(r'[0-9]'))) classes++;
  if (password.contains(RegExp(r'[^A-Za-z0-9]'))) classes++;
  if (password.length >= 14 && classes == 4) return 'Strong';
  if (password.length >= 10 && classes >= 3) return 'Medium';
  if (password.length >= 8 && classes >= 2) return 'Medium';
  return 'Weak';
}

/// 0.0–1.0 progress for the strength meter bar.
double passwordStrengthValue(String password) {
  switch (passwordStrength(password)) {
    case 'Strong':
      return 1.0;
    case 'Medium':
      return 0.6;
    default:
      return 0.3;
  }
}
