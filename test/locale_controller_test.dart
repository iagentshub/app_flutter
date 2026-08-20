import 'package:app_flutter/app/app.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:app_flutter/shared/state/locale_controller.dart';
import 'package:app_flutter/shared/state/session_controller.dart';
import 'package:app_flutter/shared/state/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/memory_secure_store.dart';

/// El idioma se guardaba como `bool isEnglish` y ese booleano viajaba por
/// veinte ficheros: añadir un tercer idioma obligaba a tocar la firma de todo
/// lo que lo pasaba, con `assets/locales/<código>/` ya preparado para más.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('arranca en español cuando no hay preferencia guardada', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = await LocaleController.bootstrap();

    expect(controller.languageCode, 'es');
    expect(controller.locale, const Locale('es'));
  });

  test('recupera el idioma persistido', () async {
    SharedPreferences.setMockInitialValues({'app_language': 'en'});
    final controller = await LocaleController.bootstrap();

    expect(controller.languageCode, 'en');
    expect(controller.locale, const Locale('en'));
  });

  test('setLanguage persiste y avisa a quien escuche', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = await LocaleController.bootstrap();
    var avisos = 0;
    controller.addListener(() => avisos += 1);

    await controller.setLanguage('en');
    expect(controller.languageCode, 'en');
    expect(avisos, 1);

    // Repetir el mismo idioma no reemite ni reescribe.
    await controller.setLanguage('en');
    expect(avisos, 1);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_language'), 'en');
  });

  test(
    'normaliza variantes regionales y descarta idiomas sin bundle',
    () async {
      SharedPreferences.setMockInitialValues({});
      final controller = await LocaleController.bootstrap();

      // El backend puede devolver 'en-US' o 'es_ES'.
      await controller.setLanguage('en-US');
      expect(controller.languageCode, 'en');

      // Y un idioma que todavía no tiene traducciones no deja la app en blanco.
      await controller.setLanguage('fr');
      expect(controller.languageCode, LocaleController.fallbackLanguageCode);
    },
  );

  test('syncFromBackend ignora un valor vacío', () async {
    SharedPreferences.setMockInitialValues({'app_language': 'en'});
    final controller = await LocaleController.bootstrap();

    await controller.syncFromBackend(null);
    await controller.syncFromBackend('');
    expect(controller.languageCode, 'en');
  });

  /// MaterialApp.router no declaraba locale, supportedLocales ni
  /// localizationsDelegates, así que Flutter caía en
  /// DefaultMaterialLocalizations —inglés fijo— y el menú contextual de un
  /// campo de texto, los selectores de fecha y los anuncios de lector de
  /// pantalla salían en inglés con la app en español.
  testWidgets('los widgets de Material hablan el idioma de la app', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'app_language': 'es'});
    final backendController = await BackendController.bootstrap();
    final sessionController = await SessionController.bootstrap(
      secureStore: MemorySecureStore(),
    );
    final localeController = await LocaleController.bootstrap();
    final themeController = await ThemeController.bootstrap();

    await tester.pumpWidget(
      App(
        backendController: backendController,
        sessionController: sessionController,
        localeController: localeController,
        themeController: themeController,
      ),
    );
    await tester.pump();

    final context = tester.element(find.byType(Navigator).first);
    expect(MaterialLocalizations.of(context).cancelButtonLabel, 'Cancelar');

    // Y cambiar de idioma en caliente cambia también esos textos.
    await localeController.setLanguage('en');
    await tester.pump();
    final trasCambio = tester.element(find.byType(Navigator).first);
    expect(MaterialLocalizations.of(trasCambio).cancelButtonLabel, 'Cancel');
  });
}
