import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/admin/widgets/official_packages_admin_tab.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('edita cards sin mostrar ids y sincroniza la selección', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final backend = await BackendController.bootstrap();
    String? editedPath;
    Map<String, dynamic>? editedBody;
    final syncedPaths = <String>[];
    final packages = [
      {
        'id': 'hidden-package-a',
        'name': 'Package Alpha',
        'description': 'Alpha description',
        'repository_url': 'https://github.com/example/alpha',
        'tracking_mode': 'release',
        'tracking_ref': 'main',
        'license': 'MIT',
        'versions': <Object>[],
      },
      {
        'id': 'hidden-package-b',
        'name': 'Package Beta',
        'description': 'Beta description',
        'repository_url': 'https://github.com/example/beta',
        'tracking_mode': 'branch',
        'tracking_ref': 'stable',
        'license': 'Apache-2.0',
        'versions': <Object>[],
      },
    ];
    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/admin/official-packages') {
        return _json(packages);
      }
      if (request.method == 'PUT') {
        editedPath = request.url.path;
        editedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return _json(editedBody!);
      }
      if (request.method == 'POST' && request.url.path.endsWith('/sync')) {
        syncedPaths.add(request.url.path);
        return _json({});
      }
      return _json({}, statusCode: 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OfficialPackagesAdminTab(
            apiClient: ApiClient(backend, client: client),
            token: 'admin-token',
            tx: (_, fallback) => fallback,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Package Alpha'), findsOneWidget);
    expect(find.text('Package Beta'), findsOneWidget);
    expect(find.text('hidden-package-a'), findsNothing);
    expect(find.text('hidden-package-b'), findsNothing);

    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Alpha edited');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(editedPath, '/api/admin/official-packages/hidden-package-a');
    expect(editedBody?['name'], 'Alpha edited');
    expect(editedBody?.containsKey('id'), isFalse);

    await tester.tap(find.text('Sincronizar'));
    await tester.pumpAndSettle();
    expect(find.text('Elegir paquetes para sincronizar'), findsOneWidget);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Package Beta'));
    await tester.pump();
    await tester.tap(find.text('Sincronizar seleccionados'));
    await tester.pumpAndSettle();

    expect(syncedPaths, ['/api/admin/official-packages/hidden-package-a/sync']);
  });
}

http.Response _json(Object body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}
