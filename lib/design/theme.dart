import 'package:flutter/material.dart';

import 'tokens.dart';

ThemeData buildBauhausTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: BColors.surface,
    colorScheme: const ColorScheme.light(
      primary: BColors.primary,
      onPrimary: BColors.onPrimary,
      primaryContainer: BColors.primaryContainer,
      onPrimaryContainer: BColors.onPrimaryContainer,
      secondary: BColors.secondary,
      onSecondary: BColors.onSecondary,
      secondaryContainer: BColors.secondaryContainer,
      onSecondaryContainer: BColors.onSecondary,
      tertiary: BColors.tertiary,
      onTertiary: BColors.onTertiary,
      tertiaryContainer: BColors.tertiaryContainer,
      onTertiaryContainer: BColors.onTertiaryContainer,
      error: BColors.error,
      onError: BColors.onError,
      errorContainer: BColors.errorContainer,
      onErrorContainer: BColors.onErrorContainer,
      surface: BColors.surface,
      onSurface: BColors.onSurface,
      surfaceContainerLowest: BColors.surfaceContainerLowest,
      surfaceContainerLow: BColors.surfaceContainerLow,
      surfaceContainer: BColors.surfaceContainer,
      surfaceContainerHigh: BColors.surfaceContainerHigh,
      surfaceContainerHighest: BColors.surfaceContainerHighest,
      onSurfaceVariant: BColors.onSurfaceVariant,
      outline: BColors.outline,
      outlineVariant: BColors.outlineVariant,
    ),
    // Bauhaus never uses soft shadows or Material ripples.
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    fontFamily: BFont.body,
  );
}
