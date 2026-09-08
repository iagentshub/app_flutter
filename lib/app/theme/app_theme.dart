import 'package:flutter/material.dart';

import '../../shared/widgets/motion/app_page_transitions.dart';
import 'fnc_colors.dart';
import 'fnc_fonts.dart';
import 'web_theme.dart';

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
      surfaceContainerLowest: FncColors.pageBackgroundLight,
      surfaceContainerLow: FncColors.white,
      surfaceContainer: FncColors.surfaceAltLight,
      surfaceContainerHigh: FncColors.white,
      surfaceContainerHighest: FncColors.surfaceAltLight,
      onSurface: FncColors.black,
      error: FncColors.errorLight,
      onError: FncColors.white,
      outline: FncColors.outlineLight,
      // Sin estos dos, M3 los resuelve a su baseline: un gris con tinte lila
      // ajeno a la paleta, que salía en cada texto secundario y cada divisor
      // de la app. `_SidebarTokens` ya los sustituía, pero solo dentro del
      // menú lateral; aquí se corrigen en el origen, con la misma derivación.
      onSurfaceVariant: FncColors.black.withValues(alpha: 0.60),
      outlineVariant: FncColors.black.withValues(alpha: 0.08),
      surfaceTint: FncColors.transparent,
      inverseSurface: FncColors.black,
      onInverseSurface: FncColors.white,
    );

    const cardColor = FncColors.white;
    const pageBackground = FncColors.pageBackgroundLight;
    const surface2 = FncColors.surfaceAltLight;
    const line = FncColors.dividerLineLight;

    return webTheme(
      ThemeData(
        colorScheme: scheme,
        scaffoldBackgroundColor: pageBackground,
        cardColor: cardColor,
        useMaterial3: true,
        // En escritorio y web los controles venían con el tamaño táctil de
        // móvil, que con ratón sobra: `adaptivePlatformDensity` los compacta
        // solo ahí y deja Android e iOS como estaban.
        visualDensity: VisualDensity.adaptivePlatformDensity,
        // Las páginas que se abren con `Navigator.push` toman su transición de
        // aquí, no de cada llamada — ver app_page_transitions.dart.
        pageTransitionsTheme: appPageTransitionsTheme,
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
        appBarTheme: AppBarTheme(
          backgroundColor: scheme.surface,
          foregroundColor: scheme.onSurface,
          surfaceTintColor: FncColors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: FncFonts.textTheme(scheme.brightness).titleLarge
              ?.copyWith(color: scheme.onSurface),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: scheme.surfaceContainerHigh,
          surfaceTintColor: FncColors.transparent,
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: scheme.surfaceContainerHigh,
          surfaceTintColor: FncColors.transparent,
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: scheme.surfaceContainerHigh,
          surfaceTintColor: FncColors.transparent,
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
            side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.22)),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: surface2,
          selectedColor: accentColor.withValues(alpha: 0.18),
          side: BorderSide(color: scheme.outlineVariant),
          labelStyle: const TextStyle(color: FncColors.black),
          shape: const StadiumBorder(),
        ),
        dividerTheme: const DividerThemeData(color: FncColors.dividerLight),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: FncColors.black,
          contentTextStyle: TextStyle(color: FncColors.white),
          behavior: SnackBarBehavior.floating,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
    );
  }

  static ThemeData dark([String themeId = 'dark-red']) {
    final accentColor = FncColors.accessibleAccent(
      accent(themeId),
      FncColors.surfaceAltDark,
    );
    final onAccentColor = FncColors.onAccent(accentColor);
    final scheme = ColorScheme.dark(
      primary: accentColor,
      onPrimary: onAccentColor,
      secondary: FncColors.white,
      onSecondary: FncColors.black,
      surface: FncColors.cardDark,
      surfaceContainerLowest: FncColors.pageBackgroundDark,
      surfaceContainerLow: FncColors.cardDark,
      surfaceContainer: FncColors.surfaceAltDark,
      surfaceContainerHigh: FncColors.surfaceAltDark,
      surfaceContainerHighest: FncColors.surfaceAltDark,
      onSurface: FncColors.textDark,
      error: FncColors.errorDark,
      onError: FncColors.black,
      outline: FncColors.outlineDark,
      // Ver la nota del tema claro.
      onSurfaceVariant: FncColors.textSecondaryDark,
      outlineVariant: FncColors.white.withValues(alpha: 0.08),
      surfaceTint: FncColors.transparent,
    );

    const cardColor = FncColors.cardDark;
    const surface2 = FncColors.surfaceAltDark;
    const line = FncColors.dividerLineDark;

    return webTheme(
      ThemeData(
        brightness: Brightness.dark,
        colorScheme: scheme,
        scaffoldBackgroundColor: FncColors.pageBackgroundDark,
        cardColor: cardColor,
        useMaterial3: true,
        // Ver la nota del tema claro.
        visualDensity: VisualDensity.adaptivePlatformDensity,
        pageTransitionsTheme: appPageTransitionsTheme,
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
        textTheme: FncFonts.textTheme(Brightness.dark).apply(
          bodyColor: FncColors.textDark,
          displayColor: FncColors.textDark,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: scheme.surface,
          foregroundColor: scheme.onSurface,
          surfaceTintColor: FncColors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: FncFonts.textTheme(scheme.brightness).titleLarge
              ?.copyWith(color: scheme.onSurface),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: scheme.surfaceContainerHigh,
          surfaceTintColor: FncColors.transparent,
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: scheme.surfaceContainerHigh,
          surfaceTintColor: FncColors.transparent,
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: scheme.surfaceContainerHigh,
          surfaceTintColor: FncColors.transparent,
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
            side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.22)),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: surface2,
          selectedColor: accentColor.withValues(alpha: 0.24),
          side: BorderSide(color: scheme.outlineVariant),
          labelStyle: const TextStyle(color: FncColors.white),
          shape: const StadiumBorder(),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: FncColors.surfaceAltDark,
          contentTextStyle: TextStyle(color: FncColors.white),
          behavior: SnackBarBehavior.floating,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            side: BorderSide(color: FncColors.dividerLineDark),
          ),
        ),
      ),
    );
  }
}
