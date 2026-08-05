import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppTheme {
  static const _red = Color(0xFFD90429);
  static const _blue = Color(0xFF2563EB);
  static const _orange = Color(0xFFF97316);
  static const _purple = Color(0xFF7C3AED);
  static const _teal = Color(0xFF0891B2);
  static const _green = Color(0xFF059669);
  static const _slate = Color(0xFF64748B);
  static const _black = Color(0xFF0B0B0B);
  static const _white = Color(0xFFFFFFFF);

  static double _contrastRatio(Color a, Color b) {
    final lighter = math.max(a.computeLuminance(), b.computeLuminance());
    final darker = math.min(a.computeLuminance(), b.computeLuminance());
    return (lighter + 0.05) / (darker + 0.05);
  }

  static Color _onAccent(Color background) =>
      _contrastRatio(background, _black) >= _contrastRatio(background, _white)
      ? _black
      : _white;

  static Color _accessibleAccent(Color accentColor, Color surface) {
    // `primary` también se usa como foreground seleccionado en navegación y
    // filtros; debe contrastar tanto con la superficie como con `onPrimary`.
    if (_contrastRatio(accentColor, surface) >= 4.5) return accentColor;
    final target = surface.computeLuminance() > 0.5 ? _black : _white;
    for (var step = 1; step <= 100; step++) {
      final candidate = Color.lerp(accentColor, target, step / 100)!;
      if (_contrastRatio(candidate, surface) >= 4.5) return candidate;
    }
    return target;
  }

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
    'marble' => _slate,
    'ocean' => _teal,
    'forest' => _green,
    _ => switch (canonicalId(themeId)) {
      String id when id.endsWith('-blue') => _blue,
      String id when id.endsWith('-orange') => _orange,
      String id when id.endsWith('-purple') => _purple,
      _ => _red,
    },
  };

  static ThemeData light([String themeId = 'light-red']) {
    final accentColor = _accessibleAccent(accent(themeId), _white);
    final onAccentColor = _onAccent(accentColor);
    final scheme = ColorScheme.light(
      primary: accentColor,
      onPrimary: onAccentColor,
      secondary: _black,
      onSecondary: _white,
      surface: _white,
      onSurface: _black,
      error: Color(0xFFB00020),
      onError: _white,
      outline: Color(0xFF2A2A2A),
      surfaceTint: accentColor,
      inverseSurface: _black,
      onInverseSurface: _white,
    );

    const cardColor = _white;
    const pageBackground = Color(0xFFF5F5F7);
    const surface2 = Color(0xFFF0F0F2);
    const line = Color(0x14000000);

    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: pageBackground,
      cardColor: cardColor,
      useMaterial3: true,
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.light(useMaterial3: true).textTheme,
      ),
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
        labelStyle: const TextStyle(color: Color(0x8A000000)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _black,
        foregroundColor: _white,
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
          foregroundColor: _black,
          side: const BorderSide(color: _black),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: accentColor.withValues(alpha: 0.08),
        selectedColor: accentColor.withValues(alpha: 0.18),
        side: BorderSide(color: accentColor.withValues(alpha: 0.28)),
        labelStyle: const TextStyle(color: _black),
        shape: const StadiumBorder(),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFD4D4D4)),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: _black,
        contentTextStyle: TextStyle(color: _white),
      ),
    );
  }

  static ThemeData dark([String themeId = 'dark-red']) {
    final accentColor = _accessibleAccent(accent(themeId), _black);
    final onAccentColor = _onAccent(accentColor);
    final scheme = ColorScheme.dark(
      primary: accentColor,
      onPrimary: onAccentColor,
      secondary: _white,
      onSecondary: _black,
      surface: _black,
      onSurface: _white,
      error: Color(0xFFFF6B6B),
      onError: _black,
      outline: Color(0xFFB8B8B8),
      surfaceTint: accentColor,
    );

    const cardColor = Color(0xFF141414);
    const surface2 = Color(0xFF1C1C1C);
    const line = Color(0x14FFFFFF);

    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: _black,
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
        labelStyle: const TextStyle(color: Color(0x8AFFFFFF)),
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.dark(useMaterial3: true).textTheme,
      ).apply(bodyColor: _white, displayColor: _white),
      appBarTheme: const AppBarTheme(
        backgroundColor: _black,
        foregroundColor: _white,
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
          foregroundColor: _white,
          side: const BorderSide(color: _white),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: accentColor.withValues(alpha: 0.12),
        selectedColor: accentColor.withValues(alpha: 0.24),
        side: BorderSide(color: accentColor.withValues(alpha: 0.36)),
        labelStyle: const TextStyle(color: _white),
        shape: const StadiumBorder(),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: _white,
        contentTextStyle: TextStyle(color: _black),
      ),
    );
  }
}
