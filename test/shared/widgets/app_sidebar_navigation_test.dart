import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_flutter/app/router/internal_router.dart';
import 'package:app_flutter/shared/services/native_app_icon_service.dart';
import 'package:app_flutter/shared/state/brand_icon_controller.dart';
import 'package:app_flutter/shared/widgets/app_shell.dart';
import 'package:app_flutter/shared/widgets/brand_icon.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BrandIconController brandIconController;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel(NativeAppIconService.channelName),
          (_) async => null,
        );
    brandIconController = await BrandIconController.bootstrap();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel(NativeAppIconService.channelName),
          null,
        );
  });

  const translations = <String, String>{
    'workspace': 'Espacio de trabajo',
    'organization': 'Organización',
    'administration': 'Administración',
    'dashboard': 'Dashboard',
    'explore': 'Explorar',
    'agents': 'Agentes',
    'workflows': 'Orquestación',
    'knowledge': 'Conocimiento',
    'connections': 'Conexiones',
    'labels': 'Etiquetas',
    'profile': 'Perfil',
    'admin': 'Admin',
    'admin_metadata': 'Sistema',
    'admin_centinel': 'Centinel',
    'logout': 'Cerrar sesión',
    'public_home': 'Inicio',
    'public_pricing': 'Precios',
    'public_docs': 'Documentación',
    'public_support': 'Soporte',
    'public_about': 'Acerca de',
  };

  String tx(String key, String fallback) => translations[key] ?? fallback;

  Widget buildNavigation({
    required bool isAdmin,
    required ValueChanged<String> onNavigate,
    ValueChanged<String>? onOpenPublicRoute,
    String? role,
    bool isEnglish = false,
    bool billingEnabled = true,
    double width = 304,
    VoidCallback? onCollapse,
    VoidCallback? onLogout,
  }) {
    return BrandIconScope(
      controller: brandIconController,
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            child: AppSidebarNavigation(
              isAdmin: isAdmin,
              location: InternalRoutes.dashboard,
              username: 'jariv',
              displayName: 'Javier',
              email: 'javier@example.com',
              role: role ?? (isAdmin ? 'admin' : 'user'),
              isEnglish: isEnglish,
              billingEnabled: billingEnabled,
              tx: tx,
              showCloseButton: false,
              onCollapse: onCollapse,
              onNavigate: onNavigate,
              onOpenPublicRoute: onOpenPublicRoute ?? (_) {},
              onLogout: onLogout ?? () {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('agrupa la navegación y abre la ruta seleccionada', (
    tester,
  ) async {
    String? selectedRoute;
    await tester.pumpWidget(
      buildNavigation(
        isAdmin: false,
        onNavigate: (route) => selectedRoute = route,
      ),
    );

    expect(find.text('ESPACIO DE TRABAJO'), findsOneWidget);
    expect(find.text('ORGANIZACIÓN'), findsOneWidget);
    expect(find.text('ADMINISTRACIÓN'), findsNothing);
    expect(find.text('Javier'), findsOneWidget);
    expect(find.text('javier@example.com'), findsNothing);

    await tester.longPress(find.text('Javier'));
    await tester.pump();
    expect(find.text('javier@example.com'), findsOneWidget);

    await tester.tap(find.text('Agentes'));
    expect(selectedRoute, InternalRoutes.agents);
  });

  testWidgets('Tab recorre la navegación principal y Enter la activa', (
    tester,
  ) async {
    String? selectedRoute;
    await tester.pumpWidget(
      buildNavigation(
        isAdmin: false,
        onNavigate: (route) => selectedRoute = route,
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(selectedRoute, InternalRoutes.dashboard);

    selectedRoute = null;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(selectedRoute, InternalRoutes.explore);

    selectedRoute = null;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(selectedRoute, InternalRoutes.agents);
  });

  testWidgets('abre las páginas públicas de React en español', (tester) async {
    final openedRoutes = <String>[];
    await tester.pumpWidget(
      buildNavigation(
        isAdmin: false,
        onNavigate: (_) {},
        onOpenPublicRoute: openedRoutes.add,
      ),
    );

    final tooltips = tester
        .widgetList<Tooltip>(find.byType(Tooltip))
        .map((tooltip) => tooltip.message);
    expect(
      tooltips,
      containsAll([
        'Inicio',
        'Precios',
        'Documentación',
        'Soporte',
        'Acerca de',
      ]),
    );

    for (final icon in const [
      Icons.home_outlined,
      Icons.sell_outlined,
      Icons.menu_book_outlined,
      Icons.support_agent_outlined,
      Icons.info_outline_rounded,
    ]) {
      await tester.tap(find.byIcon(icon));
    }

    expect(openedRoutes, ['/', '/pricing/', '/docs', '/support', '/about']);
  });

  testWidgets('abre las variantes inglesas de las páginas públicas', (
    tester,
  ) async {
    final openedRoutes = <String>[];
    await tester.pumpWidget(
      buildNavigation(
        isAdmin: false,
        isEnglish: true,
        onNavigate: (_) {},
        onOpenPublicRoute: openedRoutes.add,
      ),
    );

    for (final icon in const [
      Icons.home_outlined,
      Icons.sell_outlined,
      Icons.menu_book_outlined,
      Icons.support_agent_outlined,
      Icons.info_outline_rounded,
    ]) {
      await tester.tap(find.byIcon(icon));
    }

    expect(openedRoutes, [
      '/en/',
      '/en/pricing/',
      '/en/docs',
      '/en/support',
      '/en/about',
    ]);
  });

  testWidgets('mantiene disponible el cierre de sesión', (tester) async {
    var loggedOut = false;
    await tester.pumpWidget(
      buildNavigation(
        isAdmin: false,
        onNavigate: (_) {},
        onLogout: () => loggedOut = true,
      ),
    );

    await tester.tap(find.byIcon(Icons.logout_rounded));

    expect(loggedOut, isTrue);
  });

  testWidgets('el pie compacto cabe en el sidebar de escritorio', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildNavigation(isAdmin: false, width: 276, onNavigate: (_) {}),
    );

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    expect(find.byIcon(Icons.logout_rounded), findsOneWidget);
  });

  testWidgets('muestra las herramientas administrativas solo a admins', (
    tester,
  ) async {
    await tester.pumpWidget(buildNavigation(isAdmin: true, onNavigate: (_) {}));
    await tester.scrollUntilVisible(
      find.text('ADMINISTRACIÓN'),
      250,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('ADMINISTRACIÓN'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
    expect(find.text('Sistema'), findsOneWidget);
    expect(find.text('Centinel'), findsOneWidget);
  });

  testWidgets('oculta Workflows en el sidebar cuando la sesión es invitado', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildNavigation(isAdmin: false, role: 'guest', onNavigate: (_) {}),
    );

    expect(find.text('Orquestación'), findsNothing);
    expect(find.text('Dashboard'), findsOneWidget);
  });

  testWidgets(
    'oculta el icono de Precios cuando los planes de suscripción están desactivados',
    (tester) async {
      await tester.pumpWidget(
        buildNavigation(
          isAdmin: false,
          onNavigate: (_) {},
          billingEnabled: false,
        ),
      );

      expect(find.byIcon(Icons.sell_outlined), findsNothing);
      expect(find.text('Precios'), findsNothing);
      expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    },
  );

  testWidgets('permite contraer el menú lateral de escritorio', (tester) async {
    var collapsed = false;
    await tester.pumpWidget(
      buildNavigation(
        isAdmin: false,
        onNavigate: (_) {},
        onCollapse: () => collapsed = true,
      ),
    );

    await tester.tap(find.byIcon(Icons.keyboard_double_arrow_left_rounded));

    expect(collapsed, isTrue);
  });

  Widget buildRail({
    required bool isAdmin,
    required ValueChanged<String> onNavigate,
    String role = 'user',
    VoidCallback? onExpand,
    VoidCallback? onLogout,
  }) {
    return BrandIconScope(
      controller: brandIconController,
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 72,
            child: AppSidebarRail(
              isAdmin: isAdmin,
              role: role,
              location: InternalRoutes.dashboard,
              initial: 'J',
              tx: tx,
              onNavigate: onNavigate,
              onExpand: onExpand ?? () {},
              onLogout: onLogout ?? () {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('el rail rotula cada icono con su etiqueta traducida', (
    tester,
  ) async {
    await tester.pumpWidget(buildRail(isAdmin: false, onNavigate: (_) {}));

    final tooltips = tester
        .widgetList<Tooltip>(find.byType(Tooltip))
        .map((tooltip) => tooltip.message);
    expect(
      tooltips,
      containsAll([
        'Dashboard',
        'Explorar',
        'Agentes',
        'Orquestación',
        'Conocimiento',
        'Conexiones',
        'Etiquetas',
        'Perfil',
      ]),
    );
  });

  testWidgets('el rail navega a la ruta del icono pulsado', (tester) async {
    String? selectedRoute;
    await tester.pumpWidget(
      buildRail(isAdmin: false, onNavigate: (route) => selectedRoute = route),
    );

    await tester.tap(find.byIcon(Icons.smart_toy_outlined));

    expect(selectedRoute, InternalRoutes.agents);
  });

  testWidgets('el rail ofrece expandir el menú', (tester) async {
    var expanded = false;
    await tester.pumpWidget(
      buildRail(
        isAdmin: false,
        onNavigate: (_) {},
        onExpand: () => expanded = true,
      ),
    );

    await tester.tap(find.byIcon(Icons.keyboard_double_arrow_right_rounded));

    expect(expanded, isTrue);
  });

  testWidgets('el rail incluye las herramientas administrativas de un admin', (
    tester,
  ) async {
    await tester.pumpWidget(buildRail(isAdmin: true, onNavigate: (_) {}));
    await tester.scrollUntilVisible(
      find.byIcon(Icons.security_outlined),
      250,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.byIcon(Icons.admin_panel_settings_outlined), findsOneWidget);
    expect(find.byIcon(Icons.table_rows_outlined), findsOneWidget);
    expect(find.byIcon(Icons.security_outlined), findsOneWidget);
  });

  testWidgets('oculta Workflows en el rail cuando la sesión es invitado', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildRail(isAdmin: false, role: 'guest', onNavigate: (_) {}),
    );

    expect(find.byIcon(Icons.hub_outlined), findsNothing);
    expect(find.byIcon(Icons.dashboard_outlined), findsOneWidget);
  });
}
