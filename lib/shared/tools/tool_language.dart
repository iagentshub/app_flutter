import 'package:flutter/material.dart';

/// Helpers de presentación del `language` de una Tool, compartidos entre dos
/// librerías Dart distintas: Knowledge (`knowledge_page.dart` y sus `part`)
/// y el formulario de Agente (`agent_form_dialog.dart` y sus `part`), de ahí
/// que vivan en `shared/` en vez de junto a `skillCategoryIcon`/
/// `skillCategoryLabel` (privados de `knowledge_page.dart`, sin uso fuera de
/// esa librería).

/// Icono según el lenguaje de la tool — sin texto, así que no necesita `tx`
/// (a diferencia de [toolLanguageLabel]).
IconData toolLanguageIcon(String language) {
  return switch (language) {
    'python' => Icons.code,
    'shell' => Icons.terminal,
    'cpp' => Icons.memory,
    _ => Icons.build_outlined,
  };
}

/// Etiqueta legible del lenguaje de una tool, siempre vía `tx` — a
/// diferencia de `skillCategoryLabel` (deuda técnica preexistente con texto
/// hardcodeado), este helper nunca fija un texto de UI en el código.
String toolLanguageLabel(
  String Function(String path, String fallback) tx,
  String language,
) {
  return switch (language) {
    'python' => tx('knowledge.language_python', 'Python'),
    'shell' => tx('knowledge.language_shell', 'Shell'),
    'cpp' => tx('knowledge.language_cpp', 'C++'),
    _ => language,
  };
}

/// Tamaño legible de un binario de tool (bytes → KB/MB), reutilizado por la
/// card y por el diálogo de edición en Knowledge.
String formatToolBinarySize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
