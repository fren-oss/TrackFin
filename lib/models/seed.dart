import 'package:flutter/material.dart';

import '../design/tokens.dart';
import 'finance.dart';

/// Fixed parts of the app that are *not* user data.
///
/// The category list is part of the design (an eight-tile grid), so it stays a
/// constant. Everything else — wallets, expenses, analytics figures — used to
/// live here as demo numbers and now derives from [AppState], because the app
/// has to start from zero.
class Seed {
  Seed._();

  static const List<Category> categories = [
    Category('makanan', 'Makan', 'restaurant'),
    Category('transport', 'Transport', 'directions_subway'),
    Category('belanja', 'Belanja', 'shopping_cart'),
    Category('hiburan', 'Hiburan', 'sports_esports'),
    Category('tagihan', 'Tagihan', 'receipt_long'),
    Category('kesehatan', 'Kesehatan', 'medical_services'),
    Category('pendidikan', 'Edukasi', 'school'),
    Category('lainnya', 'Lainnya', 'more_horiz'),
  ];

  /// Preset wallet shapes offered in the add-wallet sheet.
  static const List<({String label, String icon, Color accent})> walletTypes = [
    (
      label: 'Dompet Fisik / Tunai',
      icon: 'payments',
      accent: BColors.secondary
    ),
    (label: 'Pos Tabungan', icon: 'savings', accent: BColors.tertiary),
    (
      label: 'Pos Belanja',
      icon: 'shopping_cart',
      accent: BColors.secondaryContainer
    ),
    (
      label: 'Pos Operasional',
      icon: 'wallet',
      accent: BColors.surfaceContainerHighest
    ),
    (
      label: 'Rekening Bank',
      icon: 'account_balance',
      accent: BColors.tertiaryContainer
    ),
  ];
}
