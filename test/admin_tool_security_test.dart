import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/admin/repositories/admin_resources_repository.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Admin cambia el estado de seguridad usando las labels existentes',
    () async {
      SharedPreferences.setMockInitialValues({});
      final backend = await BackendController.bootstrap();
      final client = ApiClient(
        backend,
        client: MockClient((request) async {
          expect(request.method, 'PUT');
          expect(request.url.path, '/api/admin/tools/tool-1/security');
          expect(jsonDecode(request.body), {'state': 'approved'});
          return http.Response(
            jsonEncode({
              'id': 'tool-1',
              'labels': ['private'],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.close);

      await AdminResourcesRepository(apiClient: client)
          .setAdminToolSecurity('token', 'tool-1', 'approved');
    },
  );
}
