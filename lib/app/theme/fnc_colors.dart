import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Fuente única de verdad para todo color usado en la app. Nada fuera de
/// este archivo debe declarar un `Color(0x...)` ni referenciar `Colors.*`
/// directamente (excepto `Colors.transparent`, ver [transparent]).
///
/// Tres categorías de color, cada una decide su forma:
/// 1) Paleta de marca / semántico de dominio — no cambia con light/dark ni
///    con el accent activo → constante `static const`.
/// 2) Superficies fijas de `ThemeData` por brightness — dependen solo del
///    binario light/dark, no del accent → constante `static const`.
/// 3) Superficie/contraste que debe adaptarse al `ColorScheme` activo
///    (fondo alterno, borde, hover, texto atenuado) → función que recibe
///    `BuildContext`, nunca una constante.
abstract final class FncColors {
  // ---------------------------------------------------------------------
  // 1) Paleta de marca (antes _red/_blue/... privados en AppTheme)
  // ---------------------------------------------------------------------
  static const red = Color(0xFFD90429);
  static const blue = Color(0xFF2563EB);
  static const orange = Color(0xFFF97316);
  static const purple = Color(0xFF7C3AED);
  static const teal = Color(0xFF0891B2);
  static const green = Color(0xFF059669);
  static const slate = Color(0xFF64748B);
  static const black = Color(0xFF0B0B0B);
  static const white = Color(0xFFFFFFFF);
  static const transparent = Colors.transparent;

  // ---------------------------------------------------------------------
  // 2) Semánticos de estado (reemplazan verde/rojo/ámbar sueltos)
  // ---------------------------------------------------------------------
  static const success = green;
  static const danger = Color(0xFFDC2626);
  static const warning = Color(0xFFF59E0B);
  static const info = teal;

  static const errorLight = Color(0xFFB00020);
  static const errorDark = Color(0xFFFF6B6B);

  // ---------------------------------------------------------------------
  // 3) Series de gráfico
  // ---------------------------------------------------------------------
  // Centinel · pruebas funcionales (probe_results.dart)
  static const chartGreen = Color(0xFF22C55E);
  static const chartIndigo = Color(0xFF6366F1);
  static const chartOrange = orange;
  static const chartRed = Color(0xFFEF4444);
  static const chartFunctional = <Color>[
    chartGreen,
    chartIndigo,
    chartOrange,
    chartRed,
  ];

  // Centinel · pruebas de estrés (stress_results.dart)
  static const chartEmerald = green;
  static const chartBlue = Color(0xFF3987E5);
  static const chartPurple = Color(0xFF9085E9);
  static const chartPink = Color(0xFFD55181);
  static const chartStress = <Color>[
    chartEmerald,
    chartBlue,
    chartPurple,
    chartPink,
  ];

  // ---------------------------------------------------------------------
  // 4) Catálogo de labels (antes _labelColors en label_catalog.dart)
  // ---------------------------------------------------------------------
  static const labelOwner = Color(0xFF059669);
  static const labelLinked = Color(0xFF0891B2);
  static const labelAgent = Color(0xFF2563EB);
  static const labelSkill = Color(0xFF9333EA);
  static const labelPrompt = Color(0xFFD97706);
  static const labelKnowledge = Color(0xFF0D9488);
  static const labelConnection = Color(0xFFDB2777);
  static const labelMemory = Color(0xFFB45309);
  static const labelWorkflow = Color(0xFF16A34A);
  static const labelEvaluator = Color(0xFFE11D48);
  static const labelPrivate = Color(0xFF64748B);
  static const labelPublic = Color(0xFF059669);
  static const labelProduction = Color(0xFF0891B2);
  static const labelStaging = Color(0xFF475569);
  static const labelDevelopment = Color(0xFFD97706);
  static const labelTest = Color(0xFF7C3AED);
  static const labelFavorite = Color(0xFFF59E0B);
  static const labelDraft = Color(0xFF8B5CF6);
  static const labelReview = Color(0xFFF97316);
  static const labelDeprecated = Color(0xFFCA8A04);
  static const labelQuarantine = Color(0xFFEF4444);
  static const labelArchived = Color(0xFF94A3B8);
  static const labelDelete = Color(0xFFDC2626);
  static const labelFallback = slate;

  // ---------------------------------------------------------------------
  // 5) Utilidades de contraste WCAG (antes privadas en AppTheme) — color
  //    puro, sin conocimiento de ThemeData.
  // ---------------------------------------------------------------------
  static double contrastRatio(Color a, Color b) {
    final lighter = math.max(a.computeLuminance(), b.computeLuminance());
    final darker = math.min(a.computeLuminance(), b.computeLuminance());
    return (lighter + 0.05) / (darker + 0.05);
  }

  static Color onAccent(Color background) =>
      contrastRatio(background, black) >= contrastRatio(background, white)
      ? black
      : white;

  static Color accessibleAccent(Color accentColor, Color surface) {
    if (contrastRatio(accentColor, surface) >= 4.5) return accentColor;
    final target = surface.computeLuminance() > 0.5 ? black : white;
    for (var step = 1; step <= 100; step++) {
      final candidate = Color.lerp(accentColor, target, step / 100)!;
      if (contrastRatio(candidate, surface) >= 4.5) return candidate;
    }
    return target;
  }

  /// Variante de [color] que supera 4.5:1 contra [surface], para colores de
  /// estado que se pintan como texto/icono sobre `scheme.surface` en vez de
  /// vivir en el `ColorScheme`.
  static Color statusColor(Color color, Color surface) =>
      accessibleAccent(color, surface);

  // ---------------------------------------------------------------------
  // 6) Superficies fijas de ThemeData por brightness (antes literales
  //    sueltos en AppTheme.light()/dark())
  // ---------------------------------------------------------------------
  static const outlineLight = Color(0xFF2A2A2A);
  static const pageBackgroundLight = Color(0xFFF5F5F7);
  static const surfaceAltLight = Color(0xFFF0F0F2);
  static const dividerLineLight = Color(0x14000000);
  static const dividerLight = Color(0xFFD4D4D4);
  static const hintTextLight = Color(0x8A000000);

  static const outlineDark = Color(0xFFB8B8B8);
  static const cardDark = Color(0xFF141414);
  static const surfaceAltDark = Color(0xFF1C1C1C);
  static const dividerLineDark = Color(0x14FFFFFF);
  static const hintTextDark = Color(0x8AFFFFFF);

  // ---------------------------------------------------------------------
  // 7) Helpers CONTEXTUALES (derivados de ColorScheme, nunca estáticos) —
  //    absorbe la lógica de _SidebarTokens y patrones "surface + alphaBlend"
  //    repetidos sueltos en varios widgets.
  // ---------------------------------------------------------------------
  static Color surfaceMuted(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    return Color.alphaBlend(
      (isDark ? Colors.white : Colors.black).withValues(
        alpha: isDark ? 0.03 : 0.02,
      ),
      scheme.surface,
    );
  }

  static Color borderSubtle(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08);
  static Color textMuted(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.60);
  static Color hoverOverlay(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05);
  static Color selectedOverlay(BuildContext context) =>
      Theme.of(context).colorScheme.primary.withValues(alpha: 0.13);

  // ---------------------------------------------------------------------
  // 8) Equivalentes exactos de colores con nombre de Material (Colors.*)
  //    usados por widgets que necesitaban ese tono concreto, para que el
  //    resto de la app nunca importe `Colors.*` directamente. Se exponen
  //    como los swatches originales (MaterialColor/MaterialAccentColor)
  //    para conservar el acceso a variantes exactas (`.shade700`, `[400]`).
  // ---------------------------------------------------------------------
  static const MaterialColor materialRed = Colors.red;
  static const MaterialColor materialGreen = Colors.green;
  static const MaterialColor materialGrey = Colors.grey;
  static const MaterialColor materialOrange = Colors.orange;
  static const MaterialColor materialAmber = Colors.amber;
  static const MaterialColor materialBlue = Colors.blue;
  static const MaterialAccentColor materialRedAccent = Colors.redAccent;
  static const MaterialAccentColor materialOrangeAccent = Colors.orangeAccent;
  static const MaterialAccentColor materialGreenAccent = Colors.greenAccent;

  /// Negro puro de Material — distinto de [black] (negro de marca, con
  /// tinte cálido `0xFF0B0B0B`). No confundir ambos al migrar `Colors.black`.
  static const materialBlack = Color(0xFF000000);

  // ---------------------------------------------------------------------
  // 9) Grises y tonos adicionales encontrados fuera de la escala base —
  //    nombrados por su hex para trazabilidad exacta durante la migración.
  //    Candidatos a consolidarse en una escala neutral con menos pasos en
  //    una limpieza posterior (igual que la escala de tamaños de fuente).
  // ---------------------------------------------------------------------
  static const gray050505 = Color(0xFF050505);
  static const gray070707 = Color(0xFF070707);
  static const gray0E0E0E = Color(0xFF0E0E0E);
  static const gray0F0F0F = Color(0xFF0F0F0F);
  static const gray101010 = Color(0xFF101010);
  static const gray111111 = Color(0xFF111111);
  static const gray121212 = Color(0xFF121212);
  static const gray151515 = Color(0xFF151515);
  static const gray161616 = Color(0xFF161616);
  static const gray171717 = Color(0xFF171717);
  static const gray2B2B2B = Color(0xFF2B2B2B);
  static const gray333333 = Color(0xFF333333);
  static const gray3A3A3A = Color(0xFF3A3A3A);
  static const gray5A5A5A = Color(0xFF5A5A5A);
  static const gray6B7280 = Color(0xFF6B7280);
  static const grayD0D0D0 = Color(0xFFD0D0D0);
  static const grayD3D3D3 = Color(0xFFD3D3D3);
  static const grayD6D6D6 = Color(0xFFD6D6D6);
  static const grayD8D8D8 = Color(0xFFD8D8D8);
  static const grayD9D9D9 = Color(0xFFD9D9D9);
  static const grayE0E0E0 = Color(0xFFE0E0E0);
  static const grayE2E2E2 = Color(0xFFE2E2E2);
  static const grayE8E8E8 = Color(0xFFE8E8E8);

  // Tonos de marca en otras intensidades (variantes Material de referencia
  // usadas puntualmente en algún widget, no forman parte de la paleta base).
  static const materialRed800 = Color(0xFFC62828);
  static const materialOrange800 = Color(0xFFEF6C00);
  static const materialGreen800 = Color(0xFF2E7D32);
  static const lime600 = Color(0xFF65A30D);
  static const indigo600 = Color(0xFF4F46E5);
  static const pinkAccentSoft = Color(0xFFFF667A);
  static const forestGreenDeep = Color(0xFF27845A);
  static const maroonTint = Color(0xFF2A1014);

  // Overlays con alpha explícito encontrados sueltos en widgets.
  static const overlayWhite40 = Color(0x66FFFFFF);
  static const overlayRedAccent40 = Color(0x66D90429);
  static const overlayMaroon40 = Color(0x667A0C1C);
  static const overlayRedAccent20 = Color(0x33D90429);
}
