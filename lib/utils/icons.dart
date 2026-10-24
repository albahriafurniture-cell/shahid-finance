import 'package:flutter/material.dart';

/// Icon registry — models persist an iconKey string, never a code point,
/// so a font change can never corrupt stored data. Glyphs follow the
/// master spec §6 mapping (Material rounded set → Flutter Icons).
const Map<String, IconData> kIconRegistry = {
  'restaurant': Icons.restaurant,
  'shopping_basket': Icons.shopping_basket,
  'directions_car': Icons.directions_car,
  'shopping_bag': Icons.shopping_bag,
  'receipt_long': Icons.receipt_long,
  'medical_services': Icons.medical_services,
  'movie': Icons.movie,
  'school': Icons.school,
  'payments': Icons.payments,
  'storefront': Icons.storefront,
  'laptop_mac': Icons.laptop_mac,
  'more_horiz': Icons.more_horiz,
  'swap_horiz': Icons.swap_horiz,
  'smartphone': Icons.smartphone,
  'sim_card': Icons.sim_card,
  'account_balance': Icons.account_balance,
  'wallet': Icons.account_balance_wallet_outlined,
};

IconData iconFor(String key) => kIconRegistry[key] ?? Icons.more_horiz;

/// Per-wallet-type visual treatment (transactions/wallets spec §2.5.1) —
/// colours borrowed only from the master category palette.
class WalletStyle {
  final String iconKey;
  final int tint;
  final int strong;
  const WalletStyle(this.iconKey, this.tint, this.strong);
}

WalletStyle walletStyleFor(String type) {
  switch (type) {
    case 'cash':
      return const WalletStyle('payments', 0xFFDFF7E8, 0xFF076B3A);
    case 'easypaisa':
      return const WalletStyle('smartphone', 0xFFE2F5F2, 0xFF2BB3A3);
    case 'jazzcash':
      return const WalletStyle('sim_card', 0xFFFDF3E0, 0xFFF5A623);
    case 'bank':
      return const WalletStyle('account_balance', 0xFFF0EBFC, 0xFF9B7EDE);
    default:
      return const WalletStyle('wallet', 0xFFEEF2EF, 0xFF8795A1);
  }
}
