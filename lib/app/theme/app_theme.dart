import 'package:flutter/material.dart';

import 'fnc_colors.dart';
import 'fnc_fonts.dart';

abstract final class AppTheme {
  static String canonicalId(String themeId) => switch (themeId) {
    'noir' => 'dark-red',
    'marble' => 'light-red',
    'ember' => 'dark-orange',
    'ocean' => 'dark-blue',
    'forest' => 'dark-blue',
    'dusk' => 'dark-purple',
    _ => themeId,
  };

  static ThemeMode mode(String themeId) =>
      canonicalId(themeId).startsWith('light-')
      ? ThemeMode.light
      : ThemeMode.dark;

  static Color accent(String themeId) => switch (themeId) {
    'marble' => FncColors.slate,
    'ocean' => FncColors.teal,
    'forest' => FncColors.green,
    _ => switch (canonicalId(themeId)) {
      String id when id.endsWith('-blue') => FncColors.blue,
      String id when id.endsWith('-orange') => FncColors.orange,
      String id when id.endsWith('-purple') => FncColors.purple,
      _ => FncColors.red,
    },
  };

  /// Variante de [color] que supera 4.5:1 contra [surface], para colores de
  /// estado que se pintan como texto/icono sobre `scheme.surface` en vez de
  /// vivir en el `ColorScheme`.
  static Color statusColor(Color color, Color surface) =>
      FncColors.statusColor(color, surface);

  static ThemeData light([String themeId = 'light-red']) {
    final accentColor = FncColors.accessibleAccent(
      accent(themeId),
      FncColors.white,
    );
    final onAccentColor = FncColors.onAccent(accentColor);
    final scheme = ColorScheme.light(
      primary: accentColor,
      onPrimary: onAccentColor,
      secondary: FncColors.black,
      onSecondary: FncColors.white,
      surface: FncColors.white,
      onSurface: FncColors.black,
      error: FncColors.errorLight,
      onError: FncColors.white,
      outline: FncColors.outlineLight,
      surfaceTint: accentColor,
      inverseSurface: FncColors.black,
      onInverseSurface: FncColors.white,
    );

    const cardColor = FncColors.white;
    const pageBackground = FncColors.pageBackgroundLight;
    const surface2 = FncColors.surfaceAltLight;
    const line = FncColors.dividerLineLight;

    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: pageBackground,
      cardColor: cardColor,
      useMaterial3: true,
      textTheme: FncFonts.textTheme(Brightness.light),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface2,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: accentColor, width: 1.4),
        ),
        labelStyle: const TextStyle(color: FncColors.hintTextLight),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: FncColors.black,
        foregroundColor: FncColors.white,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: onAccentColor,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: FncColors.black,
          side: const BorderSide(color: FncColors.black),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: accentColor.withValues(alpha: 0.08),
        selectedColor: accentColor.withValues(alpha: 0.18),
        side: BorderSide(color: accentColor.withValues(alpha: 0.28)),
        labelStyle: const TextStyle(color: FncColors.black),
        shape: const StadiumBorder(),
      ),
      dividerTheme: const DividerThemeData(color: FncColors.dividerLight),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: FncColors.black,
        contentTextStyle: TextStyle(color: FncColors.white),
      ),
    );
  }

  static ThemeData dark([String themeId = 'dark-red']) {
    final accentColor = FncColors.accessibleAccent(
      accent(themeId),
      FncColors.black,
    );
    final onAccentColor = FncColors.onAccent(accentColor);
    final scheme = ColorScheme.dark(
      primary: accentColor,
      onPrimary: onAccentColor,
      secondary: FncColors.white,
      onSecondary: FncColors.black,
      surface: FncColors.black,
      onSurface: FncColors.white,
      error: FncColors.errorDark,
      onError: FncColors.black,
      outline: FncColors.outlineDark,
      surfaceTint: accentColor,
    );

    const cardColor = FncColors.cardDark;
    const surface2 = FncColors.surfaceAltDark;
    const line = FncColors.dividerLineDark;

    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: FncColors.black,
      cardColor: cardColor,
      useMaterial3: true,
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface2,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: accentColor, width: 1.4),
        ),
        labelStyle: const TextStyle(color: FncColors.hintTextDark),
      ),
      textTheme: FncFonts.textTheme(
        Brightness.dark,
      ).apply(bodyColor: FncColors.white, displayColor: FncColors.white),
      appBarTheme: const AppBarTheme(
        backgroundColor: FncColors.black,
        foregroundColor: FncColors.white,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: onAccentColor,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: FncColors.white,
          side: const BorderSide(color: FncColors.white),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: accentColor.withValues(alpha: 0.12),
        selectedColor: accentColor.withValues(alpha: 0.24),
        side: BorderSide(color: accentColor.withValues(alpha: 0.36)),
        labelStyle: const TextStyle(color: FncColors.white),
        shape: const StadiumBorder(),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: FncColors.white,
        contentTextStyle: TextStyle(color: FncColors.black),
      ),
    );
  }
}
