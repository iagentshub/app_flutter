import 'package:flutter/material.dart';

/// Shared hover, keyboard focus and modal geometry for both platforms.
ThemeData interactionTheme(ThemeData base) {
  final scheme = base.colorScheme;
  WidgetStateProperty<Color?> overlay(Color color) =>
      WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return null;
        if (states.contains(WidgetState.pressed)) {
          return color.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.focused)) {
          return color.withValues(alpha: 0.14);
        }
        if (states.contains(WidgetState.hovered)) {
          return color.withValues(alpha: 0.05);
        }
        return null;
      });
  WidgetStateProperty<BorderSide?> border({
    bool outlined = false,
    bool filled = false,
  }) => WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.focused) &&
        !states.contains(WidgetState.disabled)) {
      return BorderSide(
        color: filled ? scheme.onPrimary : scheme.primary,
        width: 2,
      );
    }
    return BorderSide(
      color: scheme.onSurface.withValues(alpha: outlined ? 0.22 : 0),
      width: 2,
    );
  });
  ButtonStyle style(
    ButtonStyle? original, {
    bool outlined = false,
    bool filled = false,
  }) => (original ?? const ButtonStyle()).copyWith(
    overlayColor: overlay(filled ? scheme.onPrimary : scheme.onSurface),
    side: border(outlined: outlined, filled: filled),
    // Feedback is immediate, including when the system reduces motion.
    animationDuration: Duration.zero,
  );
  return base.copyWith(
    filledButtonTheme: FilledButtonThemeData(
      style: style(base.filledButtonTheme.style, filled: true),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: style(base.outlinedButtonTheme.style, outlined: true),
    ),
    textButtonTheme: TextButtonThemeData(
      style: style(base.textButtonTheme.style),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: style(base.iconButtonTheme.style),
    ),
    dialogTheme: base.dialogTheme.copyWith(
      insetPadding: const EdgeInsets.all(24),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        color: scheme.onSurface,
      ),
      contentTextStyle: base.textTheme.bodyMedium?.copyWith(
        color: scheme.onSurface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
  );
}
