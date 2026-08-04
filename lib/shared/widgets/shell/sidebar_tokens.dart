part of '../app_shell.dart';

/// Tokens visuales del sidebar.
///
/// El `ColorScheme` de `AppTheme` no define `onSurfaceVariant` ni
/// `outlineVariant`, así que ambos caen al baseline de Material 3 — un gris con
/// tinte lila ajeno a la paleta negro/blanco de la app. Estos tokens los
/// sustituyen dentro del shell derivándolos del esquema activo, de modo que
/// siguen al acento de las ocho variantes de tema sin fijar una tabla de
/// colores propia.
class _SidebarTokens {
  const _SidebarTokens({
    required this.surface,
    required this.border,
    required this.muted,
    required this.hover,
    required this.selectedBg,
  });

  factory _SidebarTokens.of(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    return _SidebarTokens(
      // En oscuro `surface` y `scaffoldBackgroundColor` son el mismo negro: sin
      // este velo el sidebar y el contenido se funden en un único bloque.
      surface: Color.alphaBlend(
        (isDark ? Colors.white : Colors.black).withValues(
          alpha: isDark ? 0.03 : 0.02,
        ),
        scheme.surface,
      ),
      border: scheme.onSurface.withValues(alpha: 0.08),
      muted: scheme.onSurface.withValues(alpha: 0.60),
      hover: scheme.onSurface.withValues(alpha: 0.05),
      selectedBg: scheme.primary.withValues(alpha: 0.13),
    );
  }

  /// Fondo del sidebar — un paso por encima del fondo del contenido.
  final Color surface;

  /// Separadores y borde derecho.
  final Color border;

  /// Texto e iconos secundarios (etiquetas de sección, enlaces del pie).
  final Color muted;

  /// Relleno al pasar el puntero o enfocar con teclado.
  final Color hover;

  /// Relleno del ítem activo.
  final Color selectedBg;
}
