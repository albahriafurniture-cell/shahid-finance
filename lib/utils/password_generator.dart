import 'dart:math';

/// Strong password generator (vault only). Always 16 chars by default
/// with at least one upper, one lower, one digit and one symbol.
const _upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
const _lower = 'abcdefghijkmnpqrstuvwxyz';
const _digits = '23456789';
const _symbols = '!@#\$%^&*()-_=+';

String generateStrongPassword({int length = 16, Random? random}) {
  final r = random ?? Random.secure();
  final len = length < 12 ? 12 : length;
  final chars = <String>[
    _upper[r.nextInt(_upper.length)],
    _lower[r.nextInt(_lower.length)],
    _digits[r.nextInt(_digits.length)],
    _symbols[r.nextInt(_symbols.length)],
  ];
  const all = '$_upper$_lower$_digits$_symbols';
  while (chars.length < len) {
    chars.add(all[r.nextInt(all.length)]);
  }
  chars.shuffle(r);
  return chars.join();
}

String passwordStrength(String password) {
  var classes = 0;
  if (password.contains(RegExp(r'[A-Z]'))) classes++;
  if (password.contains(RegExp(r'[a-z]'))) classes++;
  if (password.contains(RegExp(r'[0-9]'))) classes++;
  if (password.contains(RegExp(r'[^A-Za-z0-9]'))) classes++;
  if (password.length >= 16 && classes == 4) return 'Strong';
  if (password.length >= 12 && classes >= 3) return 'Good';
  if (password.length >= 8 && classes >= 2) return 'Fair';
  return 'Weak';
}
