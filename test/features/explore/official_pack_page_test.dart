import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/explore/pages/official_pack_page.dart';
import 'package:app_flutter/features/explore/repositories/explore_repository.dart';
import 'package:app_flutter/models/explore/explore_models.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:app_flutter/utils/i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/i18n_de_prueba.dart';

const _pack = ExploreOfficialPack(
  sourceId: 'source-1',
  name: 'Pack grande',
  description: 'Descripción',
  repositoryUrl: 'https://github.com/example/large',
  repositoryOwner: 'example',
  repositoryName: 'large',
  provider: 'github',
  license: 'MIT',
  commitSha: 'abc',
  counts: {'skill': 500},
  matchingCount: 500,
  totalCount: 500,
  linkedCount: 0,
  linkState: 'none',
  ownedByRequester: false,
);

Map<String, dynamic> _detail(int count) => {
  'pack': {
    'source_id': 'source-1',
    'name': 'Pack grande',
    'description': 'Descripción',
    'repository_url': 'https://github.com/example/large',
    'repository_owner': 'example',
    'repository_name': 'large',
    'provider': 'github',
    'license': 'MIT',
    'commit_sha': 'abc',
    'counts': {'skill': count},
    'matching_count': count,
    'total_count': count,
    'linked_count': 0,
    'link_state': 'none',
    'owned_by_requester': false,
  },
  'components': [
    for (var index = 0; index < count; index++)
      {
        'component_key': 'component-$index',
        'resource_type': 'skill',
        'resource_id': 'skill-$index',
        'name': 'Componente $index',
        'description': 'Descripción $index',
        'dependencies': index == 1 ? ['component-0'] : <String>[],
        'selectable': true,
        'linked': false,
      },
  ],
};

void main() {
  setUp(cargarTraduccionesDePrueba);

  TestWidgetsFlutterBinding.ensureInitialized();

  Future<int Function()> pumpPage(
    WidgetTester tester, {
    int count = 500,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final backend = await BackendController.bootstrap();
    var graphRequests = 0;
    final client = ApiClient(
      backend,
      client: MockClient((request) async {
        if (request.url.path.endsWith('/graph')) {
          graphRequests++;
          return http.Response('{}', 500);
        }
        return http.Response(
          jsonEncode(_detail(count)),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.close);
    await tester.pumpWidget(
      MaterialApp(
        home: OfficialPackPage(
          pack: _pack,
          repository: ExploreRepository(apiClient: client),
          token: 'token',
          tx: tr,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return () => graphRequests;
  }

  testWidgets('construye de forma perezosa un pack grande', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpPage(tester);

    final rendered = find.byType(CheckboxListTile).evaluate().length;
    expect(rendered, greaterThan(0));
    expect(rendered, lessThan(500));
    expect(find.text('500 seleccionados'), findsOneWidget);

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Componente 0'));
    await tester.pump();
    expect(find.text('498 seleccionados'), findsOneWidget);
  });

  testWidgets('construye el grafo con el detalle ya cargado', (tester) async {
    final graphRequests = await pumpPage(tester, count: 3);

    await tester.tap(find.byIcon(Icons.account_tree_outlined));
    await tester.pump();

    expect(graphRequests(), 0);
    expect(find.text('Grafo del pack'), findsOneWidget);
  });
}
