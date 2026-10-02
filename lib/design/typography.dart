import 'package:flutter/material.dart';

import 'tokens.dart';

/// Bauhaus typography. Headlines/labels use Space Grotesk, body copy uses
/// Inter, and every currency figure uses JetBrains Mono for tabular alignment.
class BText {
  BText._();

  static const TextStyle brand = TextStyle(
    fontFamily: BFont.headline,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.1,
    color: BColors.onSurface,
  );

  static const TextStyle brandCaps = TextStyle(
    fontFamily: BFont.headline,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.1,
    color: BColors.onSurface,
  );

  static const TextStyle pageLabel = TextStyle(
    fontFamily: BFont.headline,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
    height: 1.2,
    color: BColors.onSurfaceVariant,
  );

  static const TextStyle display = TextStyle(
    fontFamily: BFont.headline,
    fontSize: 30,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    height: 1.1,
    color: BColors.onSurface,
  );

  static const TextStyle h1 = TextStyle(
    fontFamily: BFont.headline,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.15,
    color: BColors.onSurface,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: BFont.headline,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.1,
    height: 1.2,
    color: BColors.onSurface,
  );

  static const TextStyle h3 = TextStyle(
    fontFamily: BFont.headline,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.2,
    color: BColors.onSurface,
  );

  /// Small bold uppercase used for every eyebrow, chip and section kicker.
  static const TextStyle label = TextStyle(
    fontFamily: BFont.headline,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
    height: 1.2,
    color: BColors.onSurface,
  );

  static const TextStyle labelWide = TextStyle(
    fontFamily: BFont.headline,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.1,
    height: 1.2,
    color: BColors.onSurface,
  );

  static const TextStyle labelTiny = TextStyle(
    fontFamily: BFont.headline,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.7,
    height: 1.2,
    color: BColors.onSurface,
  );

  static const TextStyle body = TextStyle(
    fontFamily: BFont.body,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: BColors.onSurface,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: BFont.body,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: BColors.onSurfaceVariant,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontFamily: BFont.body,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.4,
    color: BColors.onSurface,
  );

  // ---- Tabular currency figures ----

  static const TextStyle amountHero = TextStyle(
    fontFamily: BFont.amount,
    fontSize: 36,
    fontWeight: FontWeight.w700,
    letterSpacing: -1,
    height: 1.1,
    color: BColors.onSurface,
  );

  static const TextStyle amountDisplay = TextStyle(
    fontFamily: BFont.amount,
    fontSize: 30,
    fontWeight: FontWeight.w700,
    letterSpacing: -1,
    height: 1.1,
    color: BColors.onSurface,
  );

  static const TextStyle amountLg = TextStyle(
    fontFamily: BFont.amount,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.2,
    color: BColors.onSurface,
  );

  static const TextStyle amountMd = TextStyle(
    fontFamily: BFont.amount,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.25,
    color: BColors.onSurface,
  );

  static const TextStyle amountSm = TextStyle(
    fontFamily: BFont.amount,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.2,
    color: BColors.onSurfaceVariant,
  );

  static const TextStyle numpad = TextStyle(
    fontFamily: BFont.amount,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1,
    color: BColors.onSurface,
  );
}
