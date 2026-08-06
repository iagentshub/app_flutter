import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Fuente única de verdad para toda tipografía usada en la app. Nada fuera
/// de este archivo debe declarar un `fontFamily:` o `fontSize:` numérico
/// literal — siempre una constante de aquí.
///
/// - Texto con un rol Material natural (título, cuerpo, etiqueta) usa
///   `Theme.of(context).textTheme.X`, que hereda la familia Inter aplicada
///   por [textTheme] y reacciona al color del tema activo automáticamente.
/// - `FncFonts.X` (estático) se usa para: construir `ThemeData` en
///   `app_theme.dart` (sin `BuildContext`), los roles con nombre que no
///   tienen slot Material (`badge`/`overline`/`code*`), y cualquier
///   `fontSize` suelto que no calce en un rol completo (vía la escala
///   numérica `sizeNN`).
abstract final class FncFonts {
  static const String monospace = 'monospace';

  /// Usado únicamente por AppTheme.light()/dark() para construir ThemeData.
  static TextTheme textTheme(Brightness brightness) {
    final base = brightness == Brightness.dark
        ? ThemeData.dark(useMaterial3: true).textTheme
        : ThemeData.light(useMaterial3: true).textTheme;
    return GoogleFonts.interTextTheme(base);
  }

  // -----------------------------------------------------------------------
  // Escala numérica 1:1 con los tamaños reales encontrados en el código.
  // Sin redondear ni consolidar valores cercanos (18 vs 19 vs 20) para que
  // la migración sea un swap exacto sin diff visual. Consolidar a menos
  // pasos es limpieza de diseño legítima para después.
  // -----------------------------------------------------------------------
  static const double size9 = 9;
  static const double size10 = 10;
  static const double size11 = 11;
  static const double size12 = 12;
  static const double size12_5 = 12.5;
  static const double size13 = 13;
  static const double size14 = 14;
  static const double size15 = 15;
  static const double size16 = 16;
  static const double size18 = 18;
  static const double size19 = 19;
  static const double size20 = 20;
  static const double size22 = 22;
  static const double size24 = 24;
  static const double size28 = 28;
  static const double size32 = 32;
  static const double size38 = 38;
  static const double size40 = 40;

  // -----------------------------------------------------------------------
  // Roles completos con nombre para patrones que se repiten literalmente en
  // varios sitios (badges, overline, texto de código) — se usan tal cual en
  // vez de componer TextStyle(fontSize: FncFonts.sizeXX) a mano.
  // -----------------------------------------------------------------------
  static const TextStyle overline = TextStyle(
    fontSize: size10,
    letterSpacing: 0.4,
  );
  static const TextStyle badge = TextStyle(
    fontSize: size11,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle code = TextStyle(
    fontFamily: monospace,
    fontSize: size12,
  );
  static const TextStyle codeSmall = TextStyle(
    fontFamily: monospace,
    fontSize: size11,
  );
  static const TextStyle codeMicro = TextStyle(
    fontFamily: monospace,
    fontSize: size10,
  );
}
