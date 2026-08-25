import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/admin/repositories/admin_platform_repository.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:app_flutter/shared/state/upload_limits.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    UploadLimits.updateFromPlatform({'max_request_bytes': 0});
  });

  test('guardar el configurador actualiza el único límite de subida', () async {
    final backend = await BackendController.bootstrap();
    final client = ApiClient(
      backend,
      client: MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/settings/platform');
        expect(jsonDecode(request.body), {'max_request_bytes': 8 * 1024});
        return http.Response(
          jsonEncode({'max_request_bytes': 8 * 1024}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.close);

    await AdminPlatformRepository(apiClient: client)
        .updatePlatformSettings('token', {'max_request_bytes': 8 * 1024});

    expect(UploadLimits.maxRequestBytes, 8 * 1024);
    expect(UploadLimits.exceeds(8 * 1024 + 1), isTrue);
  });
}
