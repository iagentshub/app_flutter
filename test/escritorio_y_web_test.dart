import 'dart:io';

import 'package:app_flutter/app/app_scroll_behavior.dart';
import 'package:app_flutter/features/profile/pages/profile_page.dart';
import 'package:app_flutter/shared/i18n/locale_loader.dart';
import 'package:app_flutter/shared/state/brand_icon_controller.dart';
import 'package:app_flutter/shared/state/locale_controller.dart';
import 'package:app_flutter/shared/state/theme_controller.dart';
import 'package:app_flutter/utils/i18n.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lo que se rompe solo en escritorio y en web.
///
/// Los tres casos que cubre este fichero fallaron a la vez y ninguno dio la
/// cara: el móvil seguía bien, la suite seguía verde y en escritorio se pulsaba
/// y no pasaba nada.
void main() {
  group('macOS puede abrir y guardar ficheros', () {
    // Con el sandbox activado —y lo está en los dos perfiles— cualquier
    // selector de ficheros responde `ENTITLEMENT_NOT_FOUND` sin este permiso, y
    // el `PlatformException` sube sin tocar la interfaz. Se llevaba por delante
    // la foto de perfil, importar agentes, subir documentos y packs de
    // conocimiento, el `desktop_drop` de esas mismas pantallas y todos los
    // `FilePicker.saveFile` — de ahí que haga falta la mitad de escritura.
    const permiso = 'com.apple.security.files.user-selected.read-write';

    for (final perfil in const [
      'macos/Runner/DebugProfile.entitlements',
      'macos/Runner/Release.entitlements',
    ]) {
      test('$perfil declara el permiso de ficheros', () {
        final fichero = File(perfil);
        expect(fichero.existsSync(), isTrue, reason: 'falta $perfil');
        expect(
          fichero.readAsStringSync(),
          contains(permiso),
          reason:
              'Sin <key>$permiso</key> el selector de ficheros de macOS falla '
              'con ENTITLEMENT_NOT_FOUND en todas las pantallas que suben o '
              'descargan algo.',
        );
      });
    }
  });

  test('el ratón y el trackpad pueden arrastrar una lista', () {
    // Flutter deja el ratón fuera por defecto. Aquí eso dejaba las tiras
    // horizontales quietas —el selector de icono de marca del perfil, entre
    // otras— y los `RefreshIndicator`, que son el único modo de recargar esas
    // pantallas, sin forma de dispararse con un ratón.
    const comportamiento = AppScrollBehavior();
    expect(comportamiento.dragDevices, contains(PointerDeviceKind.mouse));
    expect(comportamiento.dragDevices, contains(PointerDeviceKind.trackpad));
    expect(comportamiento.dragDevices, contains(PointerDeviceKind.touch));
  });

  test('MaterialApp declara el comportamiento de scroll de la app', () {
    expect(
      File('lib/app/app.dart').readAsStringSync(),
      contains('scrollBehavior: const AppScrollBehavior()'),
      reason:
          'Sin declararlo en el MaterialApp el comportamiento no se aplica a '
          'ninguna lista, y el fallo no se ve en móvil.',
    );
  });

  test('macOS compone la ruta del asset desde bundleURL', () {
    // `FlutterDartProject.lookupKey(forAsset:)` devuelve en macOS la ruta desde
    // la raíz de Bundle.main —«Contents/Frameworks/App.framework/Resources/
    // flutter_assets/assets/…»—, no una clave relativa a Resources. Por eso
    // fallan las dos formas que parecen naturales: `path(forResource:)` mira
    // dentro de Contents/Resources, donde los assets de Flutter no están, y
    // componerla sobre `resourceURL` duplica el tramo que la clave ya trae. Los
    // nueve iconos fallaban siempre, con el error atrapado en un debugPrint.
    final fuente = File('macos/Runner/MainFlutterWindow.swift')
        .readAsStringSync();
    expect(
      fuente,
      contains('Bundle.main.bundleURL.appendingPathComponent(assetKey)'),
      reason: 'la clave de lookupKey se compone sobre bundleURL',
    );
    expect(
      fuente,
      isNot(contains('path(forResource: assetKey')),
      reason: 'pathForResource no alcanza los assets de Flutter en macOS',
    );
  });

  testWidgets('sincronizar el tema durante un build no rompe el frame', (
    tester,
  ) async {
    // La caché de arranque resuelve sin `await`, así que el login aplica el
    // tema del backend dentro de su `initState`. Notificar ahí ensuciaba el
    // `ThemeControllerScope` que el framework estaba construyendo y la
    // excepción se llevaba el frame: «setState() called during build».
    SharedPreferences.setMockInitialValues({});
    final controlador = await ThemeController.bootstrap();
    addTearDown(controlador.dispose);

    await tester.pumpWidget(
      ThemeControllerScope(
        controller: controlador,
        child: Builder(
          builder: (context) {
            controlador.syncFromBackend('ocean');
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    await tester.pump();
    expect(controlador.themeId, 'ocean');
  });

  testWidgets('cargar un bundle lo deja disponible para tr()', (tester) async {
    // El login carga su namespace con `LocaleLoader.load` a secas, sin pasar
    // por `TranslatedTexts`. Si el registro solo ocurriera ahí, `auth` nunca
    // llegaría a `I18n` y `tr('auth.identifier_required')` —el aviso del campo
    // de usuario vacío— saldría como identificador crudo en pantalla.
    I18n.limpiar();
    addTearDown(I18n.limpiar);

    await LocaleLoader.load(
      languageCode: LocaleController.fallbackLanguageCode,
      namespace: 'auth',
    );

    expect(tr('auth.identifier_required'), isNot('auth.identifier_required'));
  });

  test('el arranque precarga los namespaces del primer frame', () {
    // `common` lo pinta el cargador de marca al restaurar sesión y `auth` el
    // login, que es la primera pantalla sin sesión. Cargarlos después del
    // primer frame no rompe nada: el titular sale un instante como
    // identificador —«headline_1», «hero_sub»— y luego se corrige solo.
    final fuente = File('lib/main.dart').readAsStringSync();
    for (final namespace in const ['common', 'auth']) {
      expect(
        fuente,
        contains("'$namespace'"),
        reason: 'main.dart debe precargar el namespace $namespace',
      );
    }
    expect(fuente, contains('LocaleLoader.load'));
  });

  testWidgets('la barra de la tira de iconos no cruza los iconos', (
    tester,
  ) async {
    // La barra se pinta sobre el borde inferior del viewport, y un ListView
    // horizontal impone su altura al hijo: cualquier sobrante entre la tira y
    // el icono estira el icono hasta ese borde y la barra le queda cruzada por
    // encima. Fue exactamente lo que pasó al añadirla.
    final scroll = ScrollController();
    addTearDown(scroll.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: BrandIconChoice.alturaTira,
              child: Scrollbar(
                controller: scroll,
                thumbVisibility: true,
                child: ListView.builder(
                  controller: scroll,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(
                    bottom: BrandIconChoice.carrilBarra,
                  ),
                  itemCount: 4,
                  itemBuilder: (_, _) => Align(
                    alignment: Alignment.topCenter,
                    child: BrandIconChoice(
                      variant: BrandIconVariant.values.first,
                      label: 'icono',
                      selected: false,
                      onSelected: (_) {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final icono = tester.getRect(find.byType(BrandIconChoice).first);
    final tira = tester.getRect(find.byType(Scrollbar));
    expect(
      icono.height,
      BrandIconChoice.lado,
      reason: 'el icono se ha estirado dentro del carril de la barra',
    );
    expect(
      tira.bottom - icono.bottom,
      greaterThanOrEqualTo(BrandIconChoice.carrilBarra),
      reason: 'no queda hueco bajo el icono para la barra',
    );

    // Y que la tira real siga usando ese mecanismo: el layout de arriba es el
    // que lo demuestra, esto es lo que ata el widget a él.
    final fuente = File('lib/features/profile/widgets/brand_icon_selector.dart')
        .readAsStringSync();
    expect(
      fuente,
      contains('Alignment.topCenter'),
      reason: 'el Align del itemBuilder es lo que impide el estiramiento',
    );
    expect(fuente, contains('BrandIconChoice.alturaTira'));
    expect(fuente, contains('bottom: BrandIconChoice.carrilBarra'));
  });
}
