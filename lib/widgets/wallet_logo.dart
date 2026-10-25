import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils/icons.dart';

/// Original brand logo asset for a wallet type, or null for Cash.
/// Logos are the brands' own marks, used as-is — never recoloured,
/// stretched, or redrawn. Wide wordmarks (Easypaisa, JazzCash) and the
/// round Meezan seal all render on a white tile with BoxFit.contain,
/// so they stay legible at any tile size. Cash keeps a generic icon.
String? walletLogoAsset(String type) {
  switch (type) {
    case 'easypaisa':
      return 'assets/images/wallets/easypaisa.png';
    case 'jazzcash':
      return 'assets/images/wallets/jazzcash.png';
    case 'bank': // Meezan (the only bank wallet type in the app)
      return 'assets/images/wallets/meezan.png';
    default:
      return null;
  }
}

/// Wallet tile: original brand logo for Easypaisa / JazzCash / Meezan,
/// generic tinted icon for Cash and any other type.
class WalletAvatar extends StatelessWidget {
  final String type;
  final double size;

  const WalletAvatar({super.key, required this.type, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final logo = walletLogoAsset(type);
    if (logo != null) {
      return Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.09),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Image.asset(logo, fit: BoxFit.contain),
      );
    }
    final style = walletStyleFor(type);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Color(style.tint),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Icon(iconFor(style.iconKey),
          size: size * 0.5, color: Color(style.strong)),
    );
  }
}
