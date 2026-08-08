import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/admin/pages/admin_page.dart';
import 'package:app_flutter/models/auth/session_user.dart';
import 'package:app_flutter/shared/state/app_services_scope.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:app_flutter/shared/state/locale_controller.dart';
import 'package:app_flutter/shared/state/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/memory_secure_store.dart';

/// Registro de una llamada al backend, para afirmar sobre el método, la ruta
/// y el cuerpo sin depender del orden en que se resuelvan los Future.
typedef _Call = ({String method, String path, String body});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('pinta los banners existentes ordenados por fecha de inicio', (
    tester,
  ) async {
    final calls = <_Call>[];
    await _pumpConfigTab(tester, calls: calls, banners: _dosBanners);

    // El orden de llegada es el inverso al esperado: la tarjeta ordena por
    // start_at, no confía en el orden del backend.
    final tarjetas = tester
        .widgetList<Text>(find.textContaining('Aviso '))
        .map((text) => text.data)
        .toList();
    expect(tarjetas, ['Aviso primero', 'Aviso segundo']);
    // La hora concreta depende del huso del runner, así que solo se afirma
    // que cada tarjeta pinta su rango; el formato se prueba por el separador.
    expect(find.textContaining('→'), findsNWidgets(2));
  });

  testWidgets('muestra el vacío cuando no hay ningún banner', (tester) async {
    await _pumpConfigTab(tester, calls: [], banners: const []);

    expect(find.text('No hay banners creados.'), findsOneWidget);
  });

  testWidgets('no envía el formulario si falta algún mensaje', (tester) async {
    final calls = <_Call>[];
    await _pumpConfigTab(tester, calls: calls, banners: const []);

    await tester.tap(find.text('Crear banner de notificación'));
    await tester.pumpAndSettle();
    calls.clear();

    await tester.enterText(_campoEs, 'Solo en español');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('El mensaje es obligatorio'), findsOneWidget);
    // El validador corta antes de mirar las fechas: si se colara el POST,
    // el backend recibiría un banner a medias.
    expect(find.text('Elige fecha de inicio y fin'), findsNothing);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(calls, isEmpty);
  });

  testWidgets('exige elegir las dos fechas antes de guardar', (tester) async {
    final calls = <_Call>[];
    await _pumpConfigTab(tester, calls: calls, banners: const []);

    await tester.tap(find.text('Crear banner de notificación'));
    await tester.pumpAndSettle();
    calls.clear();

    await tester.enterText(_campoEs, 'Mensaje es');
    await tester.enterText(_campoEn, 'Mensaje en');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Elige fecha de inicio y fin'), findsOneWidget);
    expect(calls, isEmpty);
  });

  // El rango es la única regla de vigencia que vive en el cliente: el
  // servidor compara start_at/end_at contra "ahora", pero un rango invertido
  // crea un banner que jamás se mostraría y nadie sabría por qué.
  testWidgets('rechaza un rango invertido al editar', (tester) async {
    final calls = <_Call>[];
    await _pumpConfigTab(
      tester,
      calls: calls,
      banners: [
        _banner(
          id: 'banner-1',
          startAt: '2030-03-01T10:00:00Z',
          endAt: '2030-02-01T10:00:00Z',
        ),
      ],
    );

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    calls.clear();

    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(
      find.text('La fecha de fin debe ser posterior a la de inicio'),
      findsOneWidget,
    );
    expect(calls, isEmpty);
  });

  // Frontera exacta: fin == inicio es un rango de duración cero, tan inútil
  // como uno invertido. La comprobación es isAfter, no isBefore negado.
  testWidgets('rechaza un rango de duración cero', (tester) async {
    final calls = <_Call>[];
    await _pumpConfigTab(
      tester,
      calls: calls,
      banners: [
        _banner(
          id: 'banner-1',
          startAt: '2030-03-01T10:00:00Z',
          endAt: '2030-03-01T10:00:00Z',
        ),
      ],
    );

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    calls.clear();

    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(
      find.text('La fecha de fin debe ser posterior a la de inicio'),
      findsOneWidget,
    );
    expect(calls, isEmpty);
  });

  testWidgets('un minuto de rango ya es válido y se envía en UTC', (
    tester,
  ) async {
    final calls = <_Call>[];
    await _pumpConfigTab(
      tester,
      calls: calls,
      banners: [
        _banner(
          id: 'banner-1',
          startAt: '2030-03-01T10:00:00Z',
          endAt: '2030-03-01T10:01:00Z',
        ),
      ],
    );

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    calls.clear();

    await tester.enterText(_campoEs, 'Editado');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    final guardado = calls.firstWhere((call) => call.method == 'PUT');
    expect(guardado.path, '/api/settings/notification-banners/banner-1');
    final payload = jsonDecode(guardado.body) as Map<String, dynamic>;
    expect(payload['start_at'], '2030-03-01T10:00:00.000Z');
    expect(payload['end_at'], '2030-03-01T10:01:00.000Z');
    expect(payload['message'], {'es': 'Editado', 'en': 'Notice'});
    // Tras guardar se recarga: la lista no debe quedarse con el dato viejo.
    expect(calls.where((call) => call.method == 'GET'), isNotEmpty);
  });

  testWidgets('borra el banner solo tras confirmar', (tester) async {
    final calls = <_Call>[];
    await _pumpConfigTab(
      tester,
      calls: calls,
      banners: [_banner(id: 'banner-1')],
    );
    calls.clear();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar').last);
    await tester.pumpAndSettle();

    expect(
      calls.map((call) => '${call.method} ${call.path}'),
      contains('DELETE /api/settings/notification-banners/banner-1'),
    );
  });

  testWidgets('no edita ni borra un banner sin identificador válido', (
    tester,
  ) async {
    final calls = <_Call>[];
    await _pumpConfigTab(
      tester,
      calls: calls,
      banners: [
        {
          'start_at': '2030-03-01T10:00:00Z',
          'end_at': '2030-03-02T10:00:00Z',
          'message': {'es': 'Sin id', 'en': 'No id'},
        },
      ],
    );
    calls.clear();

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    expect(
      find.text('El banner no tiene un identificador válido.'),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsNothing);
    expect(calls, isEmpty);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(calls, isEmpty);
  });

  testWidgets('muestra el error del backend si el listado falla', (
    tester,
  ) async {
    await _pumpConfigTab(
      tester,
      calls: [],
      banners: const [],
      bannersError: 'Sin permisos',
    );

    expect(find.text('Sin permisos'), findsOneWidget);
    expect(find.text('No hay banners creados.'), findsNothing);
  });
}

final _campoEs = find.widgetWithText(TextFormField, 'Mensaje (Español)');
final _campoEn = find.widgetWithText(TextFormField, 'Mensaje (English)');

Map<String, dynamic> _banner({
  required String id,
  String startAt = '2030-03-01T10:00:00Z',
  String endAt = '2030-03-02T10:00:00Z',
  String es = 'Aviso',
  String en = 'Notice',
}) {
  return {
    'id': id,
    'start_at': startAt,
    'end_at': endAt,
    'message': {'es': es, 'en': en},
  };
}

final _dosBanners = [
  _banner(id: 'banner-2', startAt: '2030-04-01T10:00:00Z', es: 'Aviso segundo'),
  _banner(id: 'banner-1', startAt: '2030-03-01T10:00:00Z', es: 'Aviso primero'),
];

/// Monta AdminPage, salta al tab de Configuración y deja a la vista la
/// tarjeta de banners. Devuelve con todo asentado.
Future<void> _pumpConfigTab(
  WidgetTester tester, {
  required List<_Call> calls,
  required List<Map<String, dynamic>> banners,
  String? bannersError,
}) async {
  tester.view.physicalSize = const Size(1600, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});

  final backend = await BackendController.bootstrap();
  final locale = await LocaleController.bootstrap();
  final session = await SessionController.bootstrap(
    secureStore: MemorySecureStore(),
  );
  await session.login(
    token: 'admin-token',
    user: const SessionUser(id: 'user-1', username: 'admin', role: 'admin'),
    remember: false,
  );

  final estado = [...banners];
  final client = MockClient((request) async {
    final path = request.url.path;
    calls.add((method: request.method, path: path, body: request.body));
    if (path == '/api/settings/notification-banners') {
      if (request.method == 'GET') {
        if (bannersError != null) {
          return _json({'detail': bannersError}, status: 403);
        }
        return _json(estado);
      }
      return _json({'id': 'nuevo'});
    }
    if (path.startsWith('/api/settings/notification-banners/')) {
      if (request.method == 'DELETE') return http.Response('', 204);
      return _json({'id': 'banner-1'});
    }
    if (path == '/api/admin/stats') return _json(const {});
    if (path == '/api/admin/explore') {
      return _json(const {'items': [], 'total': 0, 'counts': {}});
    }
    return _json(const {});
  });

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AppServicesScope(
          apiClient: ApiClient(backend, client: client),
          sessionController: session,
          localeController: locale,
          child: const AdminPage(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('Configuración'));
  await tester.pumpAndSettle();

  await tester.scrollUntilVisible(
    find.text('Banners de notificación'),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

http.Response _json(Object? body, {int status = 200}) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
}
