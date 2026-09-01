import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/auth/pages/legal_acceptance_page.dart';
import 'package:app_flutter/features/auth/repositories/auth_repository.dart';
import 'package:app_flutter/models/auth/session_user.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:app_flutter/shared/state/locale_controller.dart';
import 'package:app_flutter/shared/state/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/memory_secure_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('acepta la versión vigente y libera la sesión sin cerrarla', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final backend = await BackendController.bootstrap();
    final locale = await LocaleController.bootstrap();
    final session = await SessionController.bootstrap(
      secureStore: MemorySecureStore(),
    );
    await session.login(
      token: 'ga-token',
      user: const SessionUser(
        username: 'alice',
        role: 'standard',
        legalAcceptanceRequired: true,
      ),
      remember: false,
    );
    Map<String, dynamic>? accepted;
    final client = MockClient((request) async {
      if (request.url.path == '/api/settings/platform/public') {
        return _jsonResponse(_platformLegal());
      }
      if (request.url.path == '/api/auth/legal-acceptances') {
        accepted = jsonDecode(request.body) as Map<String, dynamic>;
        return _jsonResponse({'ok': true, 'legal_acceptance_required': false});
      }
      if (request.url.path == '/api/auth/me') {
        return _jsonResponse({
          'username': 'alice',
          'role': 'standard',
          'legal_acceptance_required': false,
        });
      }
      return _jsonResponse({}, statusCode: 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: LegalAcceptancePage(
          authRepository: AuthRepository(ApiClient(backend, client: client)),
          sessionController: session,
          localeController: locale,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Aceptar y continuar'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.ensureVisible(find.text('Aceptar y continuar'));
    await tester.pump();
    await tester.tap(find.text('Aceptar y continuar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(accepted?['locale'], 'es');
    expect(accepted?['documents'], hasLength(2));
    expect(session.gaToken, 'ga-token');
    expect(session.user?.legalAcceptanceRequired, isFalse);
  });
}

http.Response _jsonResponse(Object body, {int statusCode = 200}) =>
    http.Response(
      jsonEncode(body),
      statusCode,
      headers: {'content-type': 'application/json'},
    );

Map<String, dynamic> _platformLegal() => {
  'legal': {
    'required': true,
    'ready': true,
    'accept_url': '/app/legal-acceptance',
    'documents': {
      'terms': {
        'version': 'terms-v2',
        'locales': {
          'es': {'url': '/terms', 'sha256': 'a' * 64},
          'en': {'url': '/en/terms', 'sha256': 'b' * 64},
        },
      },
      'privacy': {
        'version': 'privacy-v3',
        'locales': {
          'es': {'url': '/privacy', 'sha256': 'c' * 64},
          'en': {'url': '/en/privacy', 'sha256': 'd' * 64},
        },
      },
    },
  },
};
