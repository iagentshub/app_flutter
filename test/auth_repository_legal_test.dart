import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/auth/repositories/auth_repository.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'el registro envía el contrato legal exacto cuando está publicado',
    () async {
      SharedPreferences.setMockInitialValues({});
      final backend = await BackendController.bootstrap();
      Map<String, dynamic>? sent;
      final repository = AuthRepository(
        ApiClient(
          backend,
          client: MockClient((request) async {
            sent = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              '{"ok":true}',
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );
      final acceptance = {
        'accepted': true,
        'locale': 'es',
        'documents': <Object>[],
      };

      await repository.register(
        username: 'Alice',
        email: 'ALICE@EXAMPLE.COM',
        password: 'pass1234',
        legalAcceptance: acceptance,
      );

      expect(sent?['username'], 'alice');
      expect(sent?['email'], 'alice@example.com');
      expect(sent?['legal_acceptance'], acceptance);
    },
  );
}
