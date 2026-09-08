import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'interaction_theme.dart';

/// Ajustes de los controles web sin alterar la paleta ni los temas nativos.
ThemeData webTheme(ThemeData base) {
  base = interactionTheme(base);
  if (!kIsWeb) return base;
  const shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(10)),
  );
  final scheme = base.colorScheme;
  return base.copyWith(
    visualDensity: VisualDensity.standard,
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: base.iconButtonTheme.style?.merge(
        IconButton.styleFrom(
          shape: shape,
          iconSize: 19,
          minimumSize: const Size(40, 40),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: base.filledButtonTheme.style?.copyWith(
        shape: const WidgetStatePropertyAll(shape),
        minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: base.outlinedButtonTheme.style?.copyWith(
        shape: const WidgetStatePropertyAll(shape),
        minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
      ),
    ),
    popupMenuTheme: base.popupMenuTheme.copyWith(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      elevation: 6,
      surfaceTintColor: Colors.transparent,
    ),
  );
}
