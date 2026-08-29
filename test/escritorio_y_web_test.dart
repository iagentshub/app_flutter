import 'dart:convert';
import 'dart:io';

import 'package:app_flutter/core/network/session_image.dart';
import 'package:app_flutter/features/profile/pages/profile_page.dart';
import 'package:app_flutter/shared/i18n/locale_loader.dart';
import 'package:app_flutter/shared/state/brand_icon_controller.dart';
import 'package:app_flutter/shared/state/locale_controller.dart';
import 'package:app_flutter/shared/state/theme_controller.dart';
import 'package:app_flutter/utils/i18n.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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

  testWidgets('un desplegable dentro de una lista abre al hacer clic', (
    tester,
  ) async {
    // Habilitar `PointerDeviceKind.mouse` en `dragDevices` parecía la forma de
    // que el ratón arrastrara las tiras horizontales y disparara los
    // `RefreshIndicator`. El precio, medido, es que rompe **cualquier** tap
    // dentro de un scrollable: para el ratón el umbral de arrastre es de 1 px,
    // así que el arrastre gana la arena de gestos y el tap se cancela. Con un
    // ratón real es casi imposible pulsar sin mover esos píxeles, y el
    // desplegable de tema de Perfil dejó de abrirse: clic y nada.
    //
    // De ahí que Flutter deje el ratón fuera por defecto. Las tiras
    // horizontales se resuelven con `Scrollbar`, no con esto.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              const SizedBox(height: 400),
              DropdownButtonFormField<String>(
                initialValue: 'a',
                items: const [
                  DropdownMenuItem(value: 'a', child: Text('opcion-a')),
                  DropdownMenuItem(value: 'b', child: Text('opcion-b')),
                ],
                onChanged: (_) {},
              ),
              const SizedBox(height: 800),
            ],
          ),
        ),
      ),
    );

    // Un clic de ratón con el temblor de tres píxeles que tiene cualquier mano.
    final gesto = await tester.startGesture(
      tester.getCenter(find.byType(DropdownButtonFormField<String>)),
      kind: PointerDeviceKind.mouse,
    );
    await gesto.moveBy(const Offset(0, 3));
    await gesto.up();
    await tester.pumpAndSettle();

    expect(
      find.text('opcion-b'),
      findsWidgets,
      reason: 'el desplegable no se ha abierto: ¿el ratón arrastra listas?',
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
    // `common` lo pinta el cargador de marca al restaurar sesión, `auth` el
    // login —la primera pantalla sin sesión— y `nav` el menú lateral con su
    // campana, que sale en todas las demás. Cargarlos después del primer frame
    // no rompe nada: lo que se pinta es el identificador —«headline_1»,
    // «hero_sub», «notifications»— y luego se corrige solo.
    final fuente = File('lib/main.dart').readAsStringSync();
    for (final namespace in const ['common', 'auth', 'nav']) {
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

  test('en web, sin cookie legible no hay sesión', () {
    // Las tres cookies de sesión son `SameSite=Lax`, así que con un backend en
    // **otro sitio** —un túnel de desarrollo frente a `localhost`— el navegador
    // descarta el `Set-Cookie` entero. Medido con Chrome: el login responde 200
    // y la petición siguiente llega sin ninguna cookie, o sea «No autenticado»,
    // y nada apuntaba a la causa porque el cliente daba la sesión por buena.
    //
    // `extractGaToken` es quien lo nota: `ga_csrf` viaja en el mismo
    // `Set-Cookie` y es la única sin `HttpOnly`, así que su ausencia significa
    // que no se guardó ninguna.
    final fuente = File('lib/core/network/api_client.dart').readAsStringSync();
    expect(
      fuente,
      contains('readCsrfToken() == null ? null : browserCookieSessionToken'),
      reason: 'en web la sesión se da por buena sin comprobar que se guardó',
    );
  });

  test('el error de sesión descartada se traduce al pintarlo', () {
    // Un `ApiError` resuelve su texto en el `throw`, así que guardarlo tal cual
    // congela el idioma: cambiar de idioma con el error en pantalla lo dejaba
    // en el anterior. El código estable vive en `errors.json` y la vista lo
    // traduce en cada repintado.
    for (final idioma in const ['es', 'en']) {
      final catalogo = jsonDecode(
        File('assets/locales/$idioma/errors.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(
        catalogo['session_cookie_discarded'],
        isA<String>(),
        reason: 'falta el código en $idioma/errors.json',
      );
    }
    expect(
      File('lib/features/auth/pages/login_page.dart').readAsStringSync(),
      contains('trErrorOr(_errorCode, _errorMessage!)'),
      reason: 'el login vuelve a congelar el texto del error',
    );
  });

  test('el recorte del avatar no usa una API que web no tiene', () {
    // `ui.ImageDescriptor` lee el tamaño sin decodificar, que es justo lo que
    // quiere la vista previa — pero en web `descriptor.width` lanza
    // `UnsupportedError`, medido en Chrome. El diálogo se quedaba en negro con
    // «no se pudo actualizar la foto» y el `catch` mudo hacía que un formato
    // ilegible y una API inexistente se vieran exactamente igual.
    final fuente = File('lib/features/profile/dialogs/avatar_crop_dialog.dart')
        .readAsStringSync();
    expect(
      fuente,
      isNot(contains('ui.ImageDescriptor.encoded(')),
      reason: 'ImageDescriptor.width no existe en web',
    );
    expect(fuente, contains('ui.instantiateImageCodec'));
    expect(
      fuente,
      contains('debugPrint'),
      reason: 'el fallo de decodificación tiene que dejar rastro',
    );
  });

  test('el avatar se descarga con el cliente de la sesión', () async {
    // `NetworkImage` no pide credenciales en web, así que la cookie solo
    // viajaba sola same-origin: con la app en un puerto y el backend en otro,
    // el backend respondía 401 —visto en sus logs— y la foto caía al respaldo
    // de iniciales, que es idéntico a no tener foto. Por eso no lo nota nadie.
    final bytes = base64Decode(_pngDePrueba);
    var pedidas = 0;
    final mock = MockClient((req) async {
      pedidas += 1;
      return http.Response.bytes(bytes, 200);
    });

    final provider = SessionImage(
      'http://backend/api/users/a/avatar',
      client: mock,
    );
    final imagenes = <ImageInfo>[];
    final stream = provider.resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener((info, _) => imagenes.add(info));
    stream.addListener(listener);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    stream.removeListener(listener);

    expect(pedidas, 1, reason: 'no pasó por el cliente de la sesión');
    expect(imagenes, isNotEmpty, reason: 'no llegó a decodificar la imagen');
    expect(imagenes.first.image.width, 512);
  });
}

/// Un PNG real de 512x512, de los iconos de marca del propio repositorio.
const _pngDePrueba =
    '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';
