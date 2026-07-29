import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _red = Color(0xFFD90429);
  static const _black = Color(0xFF0B0B0B);
  static const _white = Color(0xFFFFFFFF);

  static ThemeData light() {
    final scheme = const ColorScheme.light(
      primary: _red,
      onPrimary: _white,
      secondary: _black,
      onSecondary: _white,
      surface: _white,
      onSurface: _black,
      error: Color(0xFFB00020),
      onError: _white,
      outline: Color(0xFF2A2A2A),
      surfaceTint: _red,
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
          borderSide: const BorderSide(color: _red, width: 1.4),
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
          backgroundColor: _red,
          foregroundColor: _white,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _black,
          side: const BorderSide(color: _black),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: Color(0xFFFEECEE),
        selectedColor: Color(0xFFFAD2D9),
        side: BorderSide(color: Color(0xFFFFCBD4)),
        labelStyle: TextStyle(color: _black),
        shape: StadiumBorder(),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFD4D4D4)),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: _black,
        contentTextStyle: TextStyle(color: _white),
      ),
    );
  }

  static ThemeData dark() {
    final scheme = const ColorScheme.dark(
      primary: _red,
      onPrimary: _white,
      secondary: _white,
      onSecondary: _black,
      surface: _black,
      onSurface: _white,
      error: Color(0xFFFF6B6B),
      onError: _black,
      outline: Color(0xFFB8B8B8),
      surfaceTint: _red,
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
          borderSide: const BorderSide(color: _red, width: 1.4),
        ),
        labelStyle: const TextStyle(color: Color(0x8AFFFFFF)),
      ),
      textTheme: ThemeData.dark(
        useMaterial3: true,
      ).textTheme.apply(bodyColor: _white, displayColor: _white),
      appBarTheme: const AppBarTheme(
        backgroundColor: _black,
        foregroundColor: _white,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _red,
          foregroundColor: _white,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _white,
          side: const BorderSide(color: _white),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: Color(0x1FFF3B30),
        selectedColor: Color(0x38FF3B30),
        side: BorderSide(color: Color(0x59FF3B30)),
        labelStyle: TextStyle(color: _white),
        shape: StadiumBorder(),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: _white,
        contentTextStyle: TextStyle(color: _black),
      ),
    );
  }
}
