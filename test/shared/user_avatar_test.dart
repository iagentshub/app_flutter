import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:app_flutter/shared/widgets/user_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// El mismo avatar estaba escrito a mano en tres pantallas, y no eran copias
/// idénticas: dos pasaban ruta relativa y una URL absoluta, que el cliente
/// volvía a prefijar. Ese avatar no se vio nunca. Estos tests fijan lo que el
/// widget único garantiza.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BackendController backendController;
  late ApiClient apiClient;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    backendController = await BackendController.bootstrap();
    apiClient = ApiClient(
      backendController,
      client: MockClient((_) async => http.Response('', 404)),
    );
    addTearDown(apiClient.close);
  });

  Widget montar(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('sin foto pinta la inicial del nombre', (tester) async {
    await tester.pumpWidget(
      montar(
        UserAvatar(
          username: 'alice',
          avatarUrl: null,
          apiClient: apiClient,
          size: 64,
        ),
      ),
    );

    expect(find.text('A'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('un nombre vacío no revienta: cae a la interrogación', (
    tester,
  ) async {
    await tester.pumpWidget(
      montar(
        UserAvatar(
          username: '   ',
          avatarUrl: null,
          apiClient: apiClient,
          size: 40,
        ),
      ),
    );

    expect(find.text('?'), findsOneWidget);
  });

  testWidgets('el círculo mide lo que se le pide, con y sin foto', (
    tester,
  ) async {
    for (final url in <String?>[null, '/api/users/alice/avatar?v=abc']) {
      await tester.pumpWidget(
        montar(
          UserAvatar(
            username: 'alice',
            avatarUrl: url,
            apiClient: apiClient,
            size: 72,
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.getSize(find.byType(UserAvatar)),
        const Size(72, 72),
        reason: 'con avatarUrl=$url',
      );
    }
  });

  testWidgets('una imagen que no carga cae a la inicial, no a un hueco', (
    tester,
  ) async {
    // Es lo que llevaba pasando en el perfil: la petición fallaba y el respaldo
    // tapaba el fallo sin decir nada. El respaldo tiene que seguir ahí —es la
    // experiencia correcta— aunque el fallo ya no exista.
    await tester.pumpWidget(
      montar(
        UserAvatar(
          username: 'bob',
          avatarUrl: '/api/users/bob/avatar?v=abc',
          apiClient: apiClient,
          size: 48,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('el mismo widget sirve para cualquier tamaño del shell', (
    tester,
  ) async {
    // El sidebar desplegado y el colapsado pintan al mismo usuario a tamaños
    // distintos. Antes cada uno tenía su CircleAvatar con su fontSize a mano,
    // y ninguno de los dos llegó a enseñar nunca la foto.
    for (final medida in <double>[28, 30, 32, 40, 64, 72]) {
      await tester.pumpWidget(
        montar(
          UserAvatar(
            username: 'alice',
            avatarUrl: null,
            apiClient: apiClient,
            size: medida,
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(UserAvatar)),
        Size(medida, medida),
        reason: 'a $medida px',
      );
      expect(find.text('A'), findsOneWidget, reason: 'a $medida px');
    }
  });
}
