import 'dart:convert';
import 'dart:typed_data';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/knowledge/pages/knowledge_page.dart';
import 'package:app_flutter/models/auth/session_user.dart';
import 'package:app_flutter/models/tools/tool_models.dart';
import 'package:app_flutter/shared/state/app_services_scope.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:app_flutter/shared/state/locale_controller.dart';
import 'package:app_flutter/shared/state/session_controller.dart';
import 'package:app_flutter/shared/state/upload_limits.dart';
import 'package:app_flutter/shared/widgets/buttons/app_buttons.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/memory_secure_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => UploadLimits.updateFromPlatform({'max_request_bytes': 0}));

  testWidgets('el formulario usa el catálogo y exige binario para C++', (
    tester,
  ) async {
    await _openNewToolDialog(tester, onRequest: (_) => null);

    await tester.tap(find.byType(DropdownButtonFormField<ToolLanguage>));
    await tester.pumpAndSettle();

    expect(find.text('Python'), findsWidgets);
    expect(find.text('Shell'), findsOneWidget);
    expect(find.text('C++'), findsOneWidget);
    expect(find.byIcon(Icons.code), findsWidgets);
    expect(find.byIcon(Icons.terminal), findsOneWidget);
    expect(find.byIcon(Icons.memory), findsOneWidget);

    await tester.tap(find.text('C++'));
    await tester.pumpAndSettle();
    await _selectLinuxX64(tester);
    await tester.enterText(find.byType(TextFormField).first, 'Binaria');
    await tester.tap(find.widgetWithText(PrimaryButton, 'Guardar'));
    await tester.pump();

    expect(
      find.text('Selecciona un binario para esta herramienta antes de guardar'),
      findsOneWidget,
    );
  });

  testWidgets('el formulario serializa el código de lenguaje sin cambios', (
    tester,
  ) async {
    Map<String, dynamic>? savedPayload;
    await _openNewToolDialog(
      tester,
      onRequest: (request) {
        if (request.method == 'POST' &&
            request.url.path == '/api/tools/private') {
          savedPayload = jsonDecode(request.body) as Map<String, dynamic>;
          return _json({'id': 'tool-1', ...savedPayload!});
        }
        return null;
      },
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, 'Script');
    await tester.enterText(fields.last, 'print("ok")');
    await tester.tap(find.widgetWithText(PrimaryButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(savedPayload?['language'], ToolLanguage.python.apiValue);
    expect(savedPayload?['content'], 'print("ok")');
  });

  testWidgets('el formulario respeta el límite configurado por Admin', (
    tester,
  ) async {
    UploadLimits.updateFromPlatform({'max_request_bytes': 3});
    await _openNewToolDialog(tester, onRequest: (_) => null);

    final dropTarget = tester.widget<DropTarget>(find.byType(DropTarget));
    dropTarget.onDragDone?.call(
      DropDoneDetails(
        files: [
          DropItemFile.fromData(
            Uint8List.fromList([1, 2, 3, 4]),
            name: 'script.py',
          ),
        ],
        localPosition: Offset.zero,
        globalPosition: Offset.zero,
      ),
    );
    await tester.pump();

    expect(find.text('El archivo no puede superar 3 B'), findsOneWidget);
  });

  testWidgets('C++ guarda metadatos y transmite el binario por multipart', (
    tester,
  ) async {
    Map<String, dynamic>? metadata;
    http.Request? binaryRequest;
    await _openNewToolDialog(
      tester,
      onRequest: (request) {
        if (request.url.path == '/api/tools/private') {
          metadata = jsonDecode(request.body) as Map<String, dynamic>;
          return _json({'id': 'cpp-1', 'scope': 'private', ...metadata!});
        }
        if (request.url.path == '/api/tools/private/cpp-1/binary') {
          binaryRequest = request;
          return _json({
            'ok': true,
            'binary_sha256': 'hash',
            'labels': ['private', 'review'],
          });
        }
        return null;
      },
    );

    await tester.tap(find.byType(DropdownButtonFormField<ToolLanguage>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('C++'));
    await tester.pumpAndSettle();
    await _selectLinuxX64(tester);

    const binary = 'streamed-binary';
    tester
        .widget<DropTarget>(find.byType(DropTarget))
        .onDragDone
        ?.call(
          DropDoneDetails(
            files: [
              DropItemFile.fromData(
                Uint8List.fromList(utf8.encode(binary)),
                name: 'runner',
                path: 'runner',
              ),
            ],
            localPosition: Offset.zero,
            globalPosition: Offset.zero,
          ),
        );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Binaria');
    await tester.tap(find.widgetWithText(PrimaryButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(metadata?['language'], 'cpp');
    expect(metadata?['labels'], contains('review'));
    expect(metadata?.containsKey('content'), isFalse);
    expect(binaryRequest, isNotNull);
    expect(
      binaryRequest!.headers['content-type'],
      startsWith('multipart/form-data'),
    );
    expect(binaryRequest!.body, contains('filename="runner"'));
    expect(binaryRequest!.body, contains(binary));
  });
}

Future<void> _selectLinuxX64(WidgetTester tester) async {
  final targets = find.byType(DropdownButtonFormField<String>);
  await tester.tap(targets.first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Linux').last);
  await tester.pumpAndSettle();
  await tester.tap(targets.last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('x64').last);
  await tester.pumpAndSettle();
}

Future<void> _openNewToolDialog(
  WidgetTester tester, {
  required http.Response? Function(http.Request request) onRequest,
}) async {
  tester.view.physicalSize = const Size(1000, 900);
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
    token: 'tool-test-token',
    user: const SessionUser(id: 'user-1', username: 'ada', role: 'user'),
    remember: false,
  );
  final client = MockClient((request) async {
    final custom = onRequest(request);
    if (custom != null) return custom;
    if ({
      '/api/v2/skills',
      '/api/v2/prompts',
      '/api/v2/tools',
      '/api/v2/knowledge',
      '/api/v2/knowledge-packs',
    }.contains(request.url.path)) {
      return _json({
        'items': [],
        'page': {'has_more': false},
      });
    }
    return _json({});
  });

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AppServicesScope(
          apiClient: ApiClient(backend, client: client),
          sessionController: session,
          localeController: locale,
          child: const KnowledgePage(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Herramientas'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Nueva herramienta'));
  await tester.pumpAndSettle();
  expect(find.text('Nueva herramienta'), findsOneWidget);
}

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);
