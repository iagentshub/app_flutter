import 'dart:async';

import 'package:app_flutter/app/theme/app_theme.dart';
import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/auth/pages/login_page.dart';
import 'package:app_flutter/features/auth/repositories/auth_repository.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:app_flutter/shared/state/locale_controller.dart';
import 'package:app_flutter/shared/state/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/memory_secure_store.dart';

class _PendingAuthRepository extends AuthRepository {
  _PendingAuthRepository(super.apiClient);

  final _platformCompleter = Completer<Map<String, dynamic>>();

  @override
  Future<Map<String, dynamic>> platformPublic() => _platformCompleter.future;
}

Future<LoginPage> _buildLoginPage() async {
  SharedPreferences.setMockInitialValues({});
  final backendController = await BackendController.bootstrap();
  final sessionController = await SessionController.bootstrap(
    secureStore: MemorySecureStore(),
  );
  final localeController = await LocaleController.bootstrap();
  final authRepository = _PendingAuthRepository(ApiClient(backendController));

  return LoginPage(
    backendController: backendController,
    sessionController: sessionController,
    localeController: localeController,
    authRepository: authRepository,
  );
}

Future<void> _pumpLoginAt(
  WidgetTester tester,
  LoginPage loginPage,
  Size size,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(MaterialApp(theme: AppTheme.dark(), home: loginPage));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('equilibra hero y formulario en escritorio', (tester) async {
    final loginPage = await _buildLoginPage();
    await _pumpLoginAt(tester, loginPage, const Size(1600, 900));

    expect(find.byKey(const Key('login-desktop-layout')), findsOneWidget);
    expect(find.byKey(const Key('login-mobile-layout')), findsNothing);
    expect(find.byKey(const Key('login-desktop-hero')), findsOneWidget);
    expect(find.byKey(const Key('login-atmosphere-animated')), findsOneWidget);

    final heroRect = tester.getRect(
      find.byKey(const Key('login-desktop-hero')),
    );
    final formRect = tester.getRect(find.byKey(const Key('login-form-card')));
    final atmosphereRect = tester.getRect(
      find.byKey(const Key('login-atmosphere')),
    );

    expect(heroRect.center.dx, lessThan(formRect.center.dx));
    expect(formRect.width, inInclusiveRange(440, 480));
    expect(formRect.right, lessThan(1500));
    expect(atmosphereRect, const Rect.fromLTWH(0, 0, 1600, 900));
    expect(
      find.descendant(
        of: find.byKey(const Key('login-desktop-hero')),
        matching: find.byKey(const Key('login-atmosphere')),
      ),
      findsNothing,
    );
  });

  testWidgets('muestra todo el contenido en una columna desplazable en movil', (
    tester,
  ) async {
    final loginPage = await _buildLoginPage();
    await _pumpLoginAt(tester, loginPage, const Size(320, 568));

    expect(find.byKey(const Key('login-mobile-layout')), findsOneWidget);
    expect(find.byKey(const Key('login-desktop-layout')), findsNothing);
    expect(find.byKey(const Key('login-mobile-hero')), findsOneWidget);
    expect(find.byKey(const Key('login-form-card')), findsOneWidget);
    expect(
      tester.getRect(find.byKey(const Key('login-atmosphere'))),
      const Rect.fromLTWH(0, 0, 320, 568),
    );

    final backendSelector = find.byKey(const Key('login-backend-selector'));
    await tester.ensureVisible(backendSelector);
    await tester.pump(const Duration(milliseconds: 100));

    expect(backendSelector, findsOneWidget);
    expect(tester.getBottomRight(backendSelector).dy, lessThanOrEqualTo(568));
    expect(tester.takeException(), isNull);
  });

  testWidgets('detiene la atmósfera cuando se reduce el movimiento', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final loginPage = await _buildLoginPage();
    await _pumpLoginAt(tester, loginPage, const Size(1200, 800));

    expect(find.byKey(const Key('login-atmosphere-static')), findsOneWidget);
    expect(find.byKey(const Key('login-atmosphere-animated')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
