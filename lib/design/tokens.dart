import 'package:flutter/material.dart';

/// Bauhaus / Neo-Brutalist design tokens.
/// Mirrors the `tailwind.config` block used by the TrackFin HTML designs.
class BColors {
  BColors._();

  // Core brand
  static const Color primary = Color(0xFF1A1A1A); // near-black
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFFFCC00); // accent yellow
  static const Color onPrimaryContainer = Color(0xFF1A1A1A);
  static const Color primaryFixedDim = Color(0xFFE6B800);
  static const Color inversePrimary = Color(0xFFF5F0E8);

  // Accent red
  static const Color secondary = Color(0xFFE63B2E);
  static const Color onSecondary = Color(0xFF1A1A1A);
  static const Color secondaryContainer = Color(0xFFFFDAD6);
  static const Color secondaryFixed = Color(0xFFFFDAD6);
  static const Color secondaryFixedDim = Color(0xFFFFB3AB);

  // Accent blue
  static const Color tertiary = Color(0xFF0055FF);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFFD6E3FF);
  static const Color tertiaryFixed = Color(0xFFD6E3FF);
  static const Color tertiaryFixedDim = Color(0xFFA8C6FF);

  // Surfaces
  static const Color surface = Color(0xFFF5F0E8); // aged paper
  static const Color surfaceBright = Color(0xFFFAF7F2);
  static const Color background = Color(0xFFF5F0E8);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF2EDE5);
  static const Color surfaceContainer = Color(0xFFEEE9E0);
  static const Color surfaceContainerHigh = Color(0xFFE8E3DA);
  static const Color surfaceContainerHighest = Color(0xFFE2DDD4);
  static const Color surfaceVariant = Color(0xFFE8E3DA);
  static const Color surfaceDim = Color(0xFFD6D1C9);

  // On-surface
  static const Color onSurface = Color(0xFF1A1A1A);
  static const Color onSurfaceVariant = Color(0xFF4A4A4A);
  static const Color onBackground = Color(0xFF1A1A1A);
  static const Color inverseSurface = Color(0xFF1A1A1A);
  static const Color inverseOnSurface = Color(0xFFF5F0E8);
  static const Color surfaceTint = Color(0xFF1A1A1A);

  // Outline
  static const Color outline = Color(0xFF1A1A1A);
  static const Color outlineVariant = Color(0xFFD0CBC3);

  // Error
  static const Color error = Color(0xFFCC0000);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  // Fixed
  static const Color primaryFixed = Color(0xFFFFCC00);
  static const Color onPrimaryFixed = Color(0xFF1A1A1A);
  static const Color onPrimaryFixedVariant = Color(0xFF1A1A1A);
  static const Color onSecondaryFixed = Color(0xFF1A1A1A);
  static const Color onSecondaryFixedVariant = Color(0xFF1A1A1A);
  static const Color onTertiaryFixed = Color(0xFF1A1A1A);
  static const Color onTertiaryFixedVariant = Color(0xFF1A1A1A);
  static const Color onTertiaryContainer = Color(0xFF1A1A1A);
}

/// Spacing scale. The designs use Tailwind keys `space-xs`..`space-xl` plus `margin`.
class BSpace {
  BSpace._();
  static const double xs = 4;
  static const double sm = 8;
  static const double gutter = 16;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double margin = 20;
}

/// Border radii are intentionally tiny — the style rejects soft rounding.
class BRadius {
  BRadius._();
  static const double sm = 2;
  static const double md = 4;
  static const double lg = 8;
  static const double chip = 12;
}

/// Offset "hard" shadows. No blur, no spread — solid blocks only.
class BShadow {
  BShadow._();

  static const List<BoxShadow> sm = [
    BoxShadow(color: BColors.outline, offset: Offset(2, 2))
  ];
  static const List<BoxShadow> md = [
    BoxShadow(color: BColors.outline, offset: Offset(3, 3))
  ];
  static const List<BoxShadow> lg = [
    BoxShadow(color: BColors.outline, offset: Offset(4, 4))
  ];

  /// Pressed state: shadow collapses and the block shifts down-right.
  static const List<BoxShadow> pressed = [
    BoxShadow(color: BColors.outline, offset: Offset(1, 1))
  ];
}

class BFont {
  BFont._();
  static const String headline = 'SpaceGrotesk';
  static const String body = 'Inter';
  static const String amount = 'JetBrainsMono';
}

/// Border widths. Designs mix `border` (1px) and `border-2` (2px).
class BBorder {
  BBorder._();
  static const double thin = 1;
  static const double thick = 2;
}

/// Page background behind every screen (aged paper).
const Color scaffoldBackground = BColors.surface;
