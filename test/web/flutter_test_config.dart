import 'dart:async';

// Estas pruebas usan datos locales y pueden ejecutarse en VM y navegador.
// No heredan el lector de traducciones con dart:io del resto de la suite.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await testMain();
}
