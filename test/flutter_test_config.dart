import 'dart:async';

import 'support/i18n_de_prueba.dart';

/// Flutter ejecuta este fichero antes de cada suite de tests.
///
/// Aquí se registran los locales reales para que cualquier widget que se monte
/// en un test enseñe el texto que ve el usuario. Antes no hacía falta: el texto
/// venía del *fallback* escrito en la propia llamada, así que los tests pasaban
/// aunque el JSON dijera otra cosa —o aunque la clave no existiera—.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  cargarTraduccionesDePrueba();
  await testMain();
}
