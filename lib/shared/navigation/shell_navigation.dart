import 'package:flutter/material.dart';

/// Cierra las rutas imperativas abiertas sobre una sección de GoRouter y
/// conserva la página declarativa que sirve de base al contenido del shell.
void closeShellOverlays(NavigatorState navigator) {
  navigator.popUntil((route) => route.settings is Page<dynamic>);
}
