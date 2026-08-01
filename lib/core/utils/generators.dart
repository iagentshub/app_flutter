/// Funciones de control centralizadas para generar valores de sistema en cliente.
///
/// Espejo de `app/utils/generators.py` del backend: todo id o fecha que se
/// genere en el cliente (p. ej. ids de nodos/aristas del canvas de workflows,
/// ids temporales optimistas) pasa por aquí, nunca inline.
library;

import 'dart:math';

const int _defaultIdLength = 12;
const String _hexAlphabet = '0123456789abcdef';
final Random _rng = Random();

/// Id alfanumérico único (hex), independiente del nombre del objeto.
String generateId({int length = _defaultIdLength}) {
  final buffer = StringBuffer();
  for (var i = 0; i < length; i++) {
    buffer.write(_hexAlphabet[_rng.nextInt(_hexAlphabet.length)]);
  }
  return buffer.toString();
}

/// Fecha-hora actual en ISO-8601 UTC, mismo formato que el backend.
String generateDate() => DateTime.now().toUtc().toIso8601String();
