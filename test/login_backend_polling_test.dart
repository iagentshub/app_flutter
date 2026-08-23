import 'package:app_flutter/app/theme/app_theme.dart';
import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/auth/pages/login_page.dart';
import 'package:app_flutter/features/auth/repositories/auth_repository.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:app_flutter/shared/state/locale_controller.dart';
import 'package:app_flutter/shared/state/session_controller.dart';
import 'package:app_flutter/shared/state/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/memory_secure_store.dart';

/// Backend de mentira cuyo estado se cambia desde el test.
class _SwitchableAuthRepository extends AuthRepository {
  _SwitchableAuthRepository(super.apiClient);

  bool caido = false;
  String temaPorDefecto = 'dark-red';
  int llamadas = 0;

  @override
  Future<Map<String, dynamic>> platformPublic() async {
    llamadas++;
    if (caido) throw Exception('sin conexión');
    return {
      'registration': 'open',
      'billing_enabled': false,
      'guest_enabled': true,
      'default_theme': temaPorDefecto,
    };
  }
}

Future<({Widget arbol, _SwitchableAuthRepository repo, ThemeController tema})>
_montar() async {
  SharedPreferences.setMockInitialValues({});
  final backendController = await BackendController.bootstrap();
  final sessionController = await SessionController.bootstrap(
    secureStore: MemorySecureStore(),
  );
  final localeController = await LocaleController.bootstrap();
  final themeController = await ThemeController.bootstrap();
  final repo = _SwitchableAuthRepository(ApiClient(backendController));

  return (
    arbol: ThemeControllerScope(
      controller: themeController,
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: LoginPage(
          backendController: backendController,
          sessionController: sessionController,
          localeController: localeController,
          authRepository: repo,
        ),
      ),
    ),
    repo: repo,
    tema: themeController,
  );
}

void main() {
  testWidgets('el login vuelve a preguntar por el backend cada diez segundos', (
    tester,
  ) async {
    final m = await _montar();
    m.repo.caido = true;

    await tester.pumpWidget(m.arbol);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final trasArranque = m.repo.llamadas;
    expect(trasArranque, greaterThan(0), reason: 'no hubo chequeo inicial');

    // Con el servidor caído nadie más habla con él: sin sondeo, el indicador
    // se quedaba en esta foto para siempre.
    m.repo.caido = false;
    await tester.pump(const Duration(seconds: 10));
    await tester.pump();

    expect(
      m.repo.llamadas,
      greaterThan(trasArranque),
      reason: 'el login no volvió a preguntar tras diez segundos',
    );

    // Y al volver, el estado se reaplica: `_applyPlatformResult` reabre los
    // flags que la caída había cerrado (invitado, registro, oauth). Sin eso el
    // indicador se pondría verde con los botones aún escondidos.
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('el sondeo no vuelve a imponer el tema del servidor', (
    tester,
  ) async {
    final m = await _montar();
    m.repo.temaPorDefecto = 'dark-blue';

    await tester.pumpWidget(m.arbol);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(m.tema.themeId, 'dark-blue', reason: 'no aplicó el tema inicial');

    // El usuario elige otro tema desde esta misma pantalla.
    await m.tema.syncFromBackend('light-red');
    expect(m.tema.themeId, 'light-red');

    // Tres ciclos de sondeo. Si el poll reaplicara el resultado completo, el
    // tema del servidor volvería a pisar al elegido cada diez segundos.
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 10));
      await tester.pump();
    }

    expect(
      m.tema.themeId,
      'light-red',
      reason: 'el sondeo pisó el tema que el usuario acababa de elegir',
    );
  });
}
