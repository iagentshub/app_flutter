import 'dart:convert';

import 'package:app_flutter/app/app.dart';
import 'package:app_flutter/features/agents/pages/agents_page.dart';
import 'package:app_flutter/features/auth/pages/vscode_auth_page.dart';
import 'package:app_flutter/features/dashboard/pages/dashboard_page.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:app_flutter/shared/state/boot_platform_cache.dart';
import 'package:app_flutter/shared/state/locale_controller.dart';
import 'package:app_flutter/shared/state/session_controller.dart';
import 'package:app_flutter/shared/state/theme_controller.dart';
import 'package:app_flutter/shared/widgets/buttons/app_buttons.dart';
import 'package:app_flutter/shared/widgets/iagents_loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/memory_secure_store.dart';

void main() {
  // Dos formas de entrar con destino: el enlace que abre la extensión de VS
  // Code y una pestaña que el navegador restauró en una sección interna. Las
  // dos pasan por `/login?redirect=…` y ninguna termina en el panel, que es el
  // único que sabe apagar la espera por su cuenta.
  const destinos = <({String nombre, String ruta, Type pantalla})>[
    (
      nombre: 'el enlace de VS Code',
      ruta:
          '/vscode-auth?state=a0d1c6b3-c41e-4826-ab4f-ea8c437d013f'
          '&callback=vscode://iagentshub.iagentshub/auth?windowId=1',
      pantalla: VsCodeAuthPage,
    ),
    (nombre: 'una sección interna', ruta: '/agents', pantalla: AgentsPage),
  ];

  for (final destino in destinos) {
    testWidgets('el overlay del login se apaga al volver a ${destino.nombre}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({'app_language': 'es'});
      BootPlatformCache.set(
        platform: const {'registration': 'open', 'guest_enabled': false},
        reachable: true,
      );
      final backend = await BackendController.bootstrap();
      final session = await SessionController.bootstrap(
        secureStore: MemorySecureStore(),
      );
      final locale = await LocaleController.bootstrap();
      final theme = await ThemeController.bootstrap();

      final client = MockClient((request) {
        switch ((request.method, request.url.path)) {
          case ('POST', '/api/auth/login'):
            return Future.value(
              http.Response(
                jsonEncode({'ok': true, 'username': 'ada'}),
                200,
                headers: {
                  'content-type': 'application/json',
                  'set-cookie': 'ga_token=user-token; Path=/; HttpOnly',
                },
              ),
            );
          case ('GET', '/api/auth/me'):
            return Future.value(
              http.Response(
                jsonEncode({'username': 'ada', 'role': 'user'}),
                200,
                headers: {'content-type': 'application/json'},
              ),
            );
          default:
            return Future.value(
              http.Response(
                '{}',
                200,
                headers: {'content-type': 'application/json'},
              ),
            );
        }
      });

      await tester.pumpWidget(
        ThemeControllerScope(
          controller: theme,
          child: App(
            backendController: backend,
            sessionController: session,
            localeController: locale,
            themeController: theme,
            httpClient: client,
            initialLocation: destino.ruta,
          ),
        ),
      );
      await tester.pump();
      for (var attempt = 0; attempt < 40; attempt += 1) {
        await tester.pump(const Duration(milliseconds: 25));
        final boton = find.widgetWithText(PrimaryButton, 'Entrar');
        if (boton.evaluate().isEmpty) continue;
        if (tester.widget<PrimaryButton>(boton).onPressed != null) break;
      }

      final campos = find.byType(TextFormField);
      await tester.enterText(campos.at(0), 'ada');
      await tester.enterText(campos.at(1), 'secreto');
      await tester.pump();
      tester
          .widget<PrimaryButton>(find.widgetWithText(PrimaryButton, 'Entrar'))
          .onPressed!();
      await tester.pump();

      for (var attempt = 0; attempt < 60; attempt += 1) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(session.isLoggedIn, isTrue);
      // Que llegue al destino —y no de vuelta al login o al panel— es parte de
      // lo que se comprueba: el `redirect` viaja codificado y el callback de VS
      // Code lleva su propio `?` dentro.
      expect(
        find.byType(destino.pantalla),
        findsOneWidget,
        reason: 'el redirect tiene que llevar al destino pedido',
      );
      expect(
        find.byType(DashboardPage),
        findsNothing,
        reason: 'el panel es el único que sabe apagar la espera por su cuenta',
      );
      // El overlay envuelve siempre a la aplicación; lo que no puede quedarse
      // encendido es su espera.
      expect(
        tester
            .widget<IAgentsLoadingOverlay>(
              find.byKey(const Key('login-dashboard-loading-overlay')),
            )
            .loading,
        isFalse,
        reason: 'la espera del login no puede sobrevivir al destino',
      );
      expect(find.byType(IAgentsLoadingIndicator), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      locale.dispose();
      theme.dispose();
      session.dispose();
    });
  }
}
