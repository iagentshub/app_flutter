import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_flutter/app/router/route_names.dart';
import 'package:app_flutter/shared/widgets/app_shell.dart';

void main() {
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
  };

  String tx(String key, String fallback) => translations[key] ?? fallback;

  Widget buildNavigation({
    required bool isAdmin,
    required ValueChanged<String> onNavigate,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 304,
          child: AppSidebarNavigation(
            isAdmin: isAdmin,
            location: RouteNames.dashboard,
            username: 'jariv',
            displayName: 'Javier',
            email: 'javier@example.com',
            role: isAdmin ? 'admin' : 'user',
            tx: tx,
            showCloseButton: false,
            onNavigate: onNavigate,
            onLogout: () {},
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
    expect(find.text('javier@example.com'), findsOneWidget);

    await tester.tap(find.text('Agentes'));
    expect(selectedRoute, RouteNames.agents);
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
}
