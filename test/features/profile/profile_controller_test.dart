import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/profile/controllers/profile_controller.dart';
import 'package:app_flutter/features/profile/repositories/profile_repository.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:app_flutter/shared/state/locale_controller.dart';
import 'package:app_flutter/shared/state/session_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/memory_secure_store.dart';

/// Un PNG mínimo pero decodificable, para probar el flujo real de
/// compresión sin depender de un asset externo.
List<int> _fakeImageBytes() =>
    img.encodePng(img.Image(width: 4, height: 4));

/// Devuelve el fallback tal cual: el controller no debe depender de que
/// haya locales cargados para producir sus mensajes.
String _tx(String path, String fallback) => fallback;

Map<String, dynamic> _session({
  String username = 'alice',
  bool isEmailPublic = false,
  String? email = 'alice@example.com',
}) => {
  'id': 'u1',
  'username': username,
  'role': 'user',
  'email': email,
  'is_email_public': isEmailPublic,
};

Map<String, dynamic> _settings({
  String theme = 'dark-red',
  String language = 'es',
  bool configurable = true,
}) => {
  'theme': theme,
  'language': language,
  'theme_configurable': configurable,
  'default_theme': 'dark-blue',
};

Map<String, dynamic> _social({
  String? github = 'https://github.com/alice',
  List<String> languages = const ['es'],
}) => {
  'username': 'alice',
  'bio': 'Hola',
  'github': github,
  'cv': '# CV',
  'languages': languages,
  'created_at': '2026-01-01',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BackendController backendController;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    backendController = await BackendController.bootstrap();
  });

  /// Sesión con token, o sin él si [token] es `null`.
  Future<SessionController> session({String? token = 'token'}) {
    SharedPreferences.setMockInitialValues(
      token == null
          ? {}
          : {
              'ga_token': token,
              'session_username': 'alice',
              'session_role': 'user',
            },
    );
    return SessionController.bootstrap(secureStore: MemorySecureStore());
  }

  /// Respuesta por defecto de cada endpoint del bundle. Los tests que
  /// necesiten otra cosa interceptan antes de llamar a este fallback.
  http.Response bundleResponse(
    http.BaseRequest request, {
    Map<String, dynamic>? settings,
    Map<String, dynamic>? sessionJson,
    Map<String, dynamic>? socialJson,
    bool deletionScheduled = false,
  }) {
    final path = request.url.path;
    if (path == '/api/auth/me') {
      return http.Response(jsonEncode(sessionJson ?? _session()), 200);
    }
    if (path == '/api/settings') {
      return http.Response(jsonEncode(settings ?? _settings()), 200);
    }
    if (path == '/api/auth/me/deletion-status') {
      return http.Response(
        jsonEncode({
          'scheduled': deletionScheduled,
          'deletion_date': deletionScheduled ? '2026-09-01' : null,
        }),
        200,
      );
    }
    if (path == '/api/billing/subscription') {
      return http.Response(jsonEncode({'tier': 'pro'}), 200);
    }
    if (path.startsWith('/api/users/')) {
      return http.Response(jsonEncode(socialJson ?? _social()), 200);
    }
    return http.Response('{}', 200);
  }

  /// Monta el controller sobre un [MockClient] y lo cierra al terminar.
  /// [themes] recoge lo que el controller manda a `syncTheme`.
  Future<ProfileController> build(
    Future<http.Response> Function(http.Request request) handler, {
    String? token = 'token',
    List<String>? themes,
    LocaleController? locale,
  }) async {
    final client = ApiClient(backendController, client: MockClient(handler));
    addTearDown(client.close);
    final controller = ProfileController(
      repository: ProfileRepository(apiClient: client),
      sessionController: await session(token: token),
      localeController: locale ?? await LocaleController.bootstrap(),
      syncTheme: (theme) async => themes?.add(theme),
      tx: _tx,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  group('conversión del campo GitHub', () {
    test('extrae el usuario de la URL que devuelve el backend', () {
      expect(githubUsernameFromUrl('https://github.com/alice'), 'alice');
      expect(githubUsernameFromUrl('https://GitHub.com/Bob/repo'), 'Bob');
      expect(githubUsernameFromUrl(null), '');
      // Un valor que no es una URL de GitHub se devuelve tal cual, para no
      // borrar en silencio lo que el usuario tenía guardado.
      expect(githubUsernameFromUrl('carol'), 'carol');
    });

    test('reconstruye la URL completa que exige el backend', () {
      expect(githubUrlFromUsername('alice'), 'https://github.com/alice');
      expect(githubUrlFromUsername(' @alice '), 'https://github.com/alice');
      expect(
        githubUrlFromUsername('https://github.com/alice'),
        'https://github.com/alice',
      );
      expect(githubUrlFromUsername('   '), isNull);
    });
  });

  test('load rellena el bundle y el borrador de los formularios', () async {
    final controller = await build(
      (request) async => bundleResponse(
        request,
        settings: _settings(theme: 'light', language: 'en'),
      ),
    );

    await controller.load();

    expect(controller.loading, isFalse);
    expect(controller.error, isNull);
    expect(controller.bundle?.session.username, 'alice');
    expect(controller.bundle?.license.tier, 'pro');
    expect(controller.theme, 'light');
    expect(controller.defaultTheme, 'dark-blue');
    expect(controller.language, 'en');
    expect(controller.bioController.text, 'Hola');
    // La URL de GitHub se muestra como usuario a secas.
    expect(controller.githubController.text, 'alice');
    expect(controller.cvController.text, '# CV');
    expect(controller.hasLanguage('es'), isTrue);
    expect(controller.hasLanguages, isTrue);
  });

  test('load sin sesión avisa en vez de llamar a la API', () async {
    var calls = 0;
    final controller = await build((request) async {
      calls++;
      return bundleResponse(request);
    }, token: null);

    await controller.load();

    expect(calls, 0);
    expect(controller.loading, isFalse);
    expect(controller.error, 'No hay sesión activa');
    expect(controller.bundle, isNull);
  });

  test('load propaga idioma y tema del backend a la app', () async {
    final themes = <String>[];
    final locale = await LocaleController.bootstrap();
    final controller = await build(
      (request) async => bundleResponse(
        request,
        settings: _settings(theme: 'light', language: 'en'),
      ),
      themes: themes,
      locale: locale,
    );

    await controller.load();

    expect(themes, ['light']);
    expect(locale.isEnglish, isTrue);
  });

  test('saveSettings omite el tema cuando lo fija el administrador', () async {
    Map<String, dynamic>? body;
    final controller = await build((request) async {
      if (request.method == 'PUT' && request.url.path == '/api/settings') {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(_settings(configurable: false)), 200);
      }
      return bundleResponse(request, settings: _settings(configurable: false));
    });
    await controller.load();
    expect(controller.themeConfigurable, isFalse);

    final result = await controller.saveSettings();

    expect(result?.isError, isFalse);
    expect(result?.message, 'Preferencias guardadas');
    expect(body!.containsKey('theme'), isFalse);
    expect(body!['language'], 'es');
  });

  test('saveSettings aplica lo que responde el backend, no el borrador', () async {
    final themes = <String>[];
    final controller = await build((request) async {
      if (request.method == 'PUT') {
        // El backend puede devolver algo distinto de lo enviado.
        return http.Response(jsonEncode(_settings(theme: 'light')), 200);
      }
      return bundleResponse(request);
    }, themes: themes);
    await controller.load();
    themes.clear();

    controller.setTheme('dark-blue');
    await controller.saveSettings();

    expect(controller.theme, 'light');
    expect(controller.savingSettings, isFalse);
    expect(themes, ['light']);
  });

  test('saveSettings informa del error del backend', () async {
    final controller = await build((request) async {
      if (request.method == 'PUT') {
        return http.Response(jsonEncode({'detail': 'Tema no permitido'}), 400);
      }
      return bundleResponse(request);
    });
    await controller.load();

    final result = await controller.saveSettings();

    expect(result?.isError, isTrue);
    expect(result?.message, contains('Tema no permitido'));
    expect(controller.savingSettings, isFalse);
  });

  test('savePublicProfile manda GitHub como URL completa', () async {
    Map<String, dynamic>? body;
    final controller = await build((request) async {
      if (request.url.path == '/api/auth/me/profile') {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{}', 200);
      }
      return bundleResponse(request);
    });
    await controller.load();

    controller.githubController.text = '@carol';
    controller.bioController.text = '  Hola  ';
    controller.setEmailPublic(true);
    controller.setLanguages({'es', 'en'});

    final result = await controller.savePublicProfile();

    expect(result?.isError, isFalse);
    expect(body!['github'], 'https://github.com/carol');
    expect(body!['bio'], 'Hola');
    expect(body!['is_email_public'], isTrue);
    expect(body!['languages'], containsAll(<String>['es', 'en']));
    expect(controller.savingProfile, isFalse);
  });

  test('changePassword valida antes de llamar a la API', () async {
    var calls = 0;
    final controller = await build((request) async {
      if (request.url.path == '/api/auth/change-password') calls++;
      return bundleResponse(request);
    });
    await controller.load();

    final empty = await controller.changePassword();
    expect(empty.isError, isTrue);
    expect(empty.message, 'Completa contraseña actual y nueva');

    controller.currentPasswordController.text = 'vieja';
    controller.newPasswordController.text = 'corta';
    final short = await controller.changePassword();
    expect(short.isError, isTrue);
    expect(
      short.message,
      'La nueva contraseña debe tener al menos 8 caracteres',
    );

    expect(calls, 0);
  });

  test('changePassword limpia los campos al terminar bien', () async {
    final controller = await build((request) async => bundleResponse(request));
    await controller.load();
    controller.currentPasswordController.text = 'vieja';
    controller.newPasswordController.text = 'nueva-larga';

    final result = await controller.changePassword();

    expect(result.isError, isFalse);
    expect(result.message, 'Contraseña actualizada');
    expect(controller.currentPasswordController.text, isEmpty);
    expect(controller.newPasswordController.text, isEmpty);
  });

  test(
    'uploadAvatar rechaza el archivo vacío y el que pasa el tope de entrada',
    () async {
      var uploads = 0;
      final controller = await build((request) async {
        if (request.url.path == '/api/auth/me/avatar') uploads++;
        return bundleResponse(request);
      });
      await controller.load();

      final empty = await controller.uploadAvatar(
        fileName: 'foto.png',
        fileBytes: const [],
      );
      expect(empty?.isError, isTrue);
      expect(empty?.message, 'No se pudo actualizar la foto');

      final huge = await controller.uploadAvatar(
        fileName: 'foto.png',
        fileBytes: List<int>.filled(
          ProfileController.maxAvatarInputBytes + 1,
          0,
        ),
      );
      expect(huge?.isError, isTrue);
      expect(huge?.message, 'La imagen original es demasiado grande');

      expect(uploads, 0);
      expect(controller.uploadingAvatar, isFalse);
    },
  );

  test('uploadAvatar rechaza bytes que no son una imagen decodificable', () async {
    final controller = await build((request) async => bundleResponse(request));
    await controller.load();

    final result = await controller.uploadAvatar(
      fileName: 'foto.png',
      fileBytes: const [1, 2, 3],
    );

    expect(result?.isError, isTrue);
    expect(result?.message, 'No se pudo actualizar la foto');
    expect(controller.uploadingAvatar, isFalse);
  });

  test('uploadAvatar comprime la imagen y rompe la caché al terminar', () async {
    final controller = await build((request) async => bundleResponse(request));
    await controller.load();
    final before = controller.avatarUrl;

    final result = await controller.uploadAvatar(
      fileName: 'foto.png',
      fileBytes: _fakeImageBytes(),
    );

    expect(result?.isError, isFalse);
    expect(before, contains('/api/users/alice/avatar?v=0'));
    expect(controller.avatarUrl, contains('v=1'));
    expect(controller.uploadingAvatar, isFalse);
  });

  test('requestDeletion devuelve el mensaje del backend', () async {
    final controller = await build((request) async {
      if (request.url.path == '/api/auth/me/request-deletion') {
        return http.Response(
          jsonEncode({'message': 'Eliminación programada para el 2026-09-01'}),
          200,
        );
      }
      return bundleResponse(request);
    });
    await controller.load();

    final result = await controller.requestDeletion();

    expect(result?.isError, isFalse);
    expect(result?.message, 'Eliminación programada para el 2026-09-01');
    expect(controller.requestingDeletion, isFalse);
  });

  test('canRequestDeletion es falso si ya está programada', () async {
    final controller = await build(
      (request) async => bundleResponse(request, deletionScheduled: true),
    );
    await controller.load();

    expect(controller.bundle?.deletion.scheduled, isTrue);
    expect(controller.canRequestDeletion, isFalse);
    expect(
      controller.deletionAlreadyScheduled.message,
      'La cuenta ya está programada para eliminación',
    );
  });

  test('no notifica después de dispose', () async {
    final client = ApiClient(
      backendController,
      client: MockClient((request) async => bundleResponse(request)),
    );
    addTearDown(client.close);
    final controller = ProfileController(
      repository: ProfileRepository(apiClient: client),
      sessionController: await session(),
      localeController: await LocaleController.bootstrap(),
      syncTheme: (_) async {},
      tx: _tx,
    );
    var notifications = 0;
    controller.addListener(() => notifications++);

    final pending = controller.load();
    controller.dispose();
    await pending;

    // La notificación de "cargando" llegó antes del dispose; ninguna después.
    expect(notifications, 1);
  });
}
