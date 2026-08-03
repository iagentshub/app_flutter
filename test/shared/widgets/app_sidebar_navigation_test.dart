import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_flutter/app/router/route_names.dart';
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
    bool isEnglish = false,
    bool landingEnabled = true,
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
              location: RouteNames.dashboard,
              username: 'jariv',
              displayName: 'Javier',
              email: 'javier@example.com',
              role: isAdmin ? 'admin' : 'user',
              isEnglish: isEnglish,
              landingEnabled: landingEnabled,
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
    expect(selectedRoute, RouteNames.agents);
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

  testWidgets('oculta el icono de Precios cuando landing está desactivado', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildNavigation(
        isAdmin: false,
        onNavigate: (_) {},
        landingEnabled: false,
      ),
    );

    expect(find.byIcon(Icons.sell_outlined), findsNothing);
    expect(find.text('Precios'), findsNothing);
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
  });

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
}
