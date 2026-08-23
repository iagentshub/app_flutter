import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Las cinco importaciones `deferred as` de este fichero son la única puerta
// por la que su código entra en el bundle: admin (con Centinel), el editor de
// workflows y el checkout de Stripe se descargan al entrar en la ruta, no al
// abrir la app. Importar cualquiera de estas librerías sin `deferred` desde
// otro sitio devolvería su parte al bundle principal sin que nadie lo note —
// `test/deferred_routes_test.dart` vigila justo eso.
import '../../features/admin/pages/admin_page.dart' deferred as admin_page;
import '../../features/admin/pages/centinel_page.dart'
    deferred as centinel_page;
import '../../features/admin/pages/metadata_page.dart'
    deferred as metadata_page;
import '../../features/agents/pages/agents_page.dart';
import '../../features/auth/pages/vscode_auth_page.dart';
import '../../features/auth/repositories/auth_repository.dart';
import '../../features/connections/pages/connections_page.dart';
import '../../features/dashboard/pages/dashboard_page.dart';
import '../../features/dashboard/repositories/dashboard_repository.dart';
import '../../features/explore/pages/explore_page.dart';
import '../../features/knowledge/pages/knowledge_page.dart';
import '../../features/labels/pages/labels_page.dart';
import '../../features/manager/pages/manager_page.dart';
import '../../features/memory/pages/memory_page.dart';
import '../../features/profile/pages/profile_page.dart';
import '../../features/public/pages/checkout_page.dart'
    deferred as checkout_page;
import '../../features/public/pages/public_profile_page.dart';
import '../../features/workflows/pages/workflows_page.dart'
    deferred as workflows_page;
import '../../shared/state/backend_controller.dart';
import '../../shared/state/dashboard_edit_state.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/motion/app_route_pages.dart';
import 'deferred_page.dart';

/// Rutas que requieren sesión iniciada, servidas dentro del [AppShell].
abstract final class InternalRoutes {
  static const dashboard = '/dashboard';
  static const agents = '/agents';
  static const orchestrations = '/orchestrations';
  static const workflowsLegacy = '/workflows';
  static const connections = '/connections';
  static const memory = '/memory';
  static const knowledge = '/knowledge';
  static const explore = '/explore';
  static const labels = '/labels';
  static const manager = '/manager';
  static const profile = '/profile';
  static const checkout = '/checkout';
  static const vscodeAuth = '/vscode-auth';
  static const admin = '/admin';
  static const adminMetadata = '/admin/metadata';
  static const adminCentinel = '/admin/centinel';
  static const adminLogs = '/admin/logs';

  static const publicProfilePrefix = '/u/';
}

/// Rama interna del router: un único [ShellRoute] con [AppShell] como layout
/// persistente y todas las páginas autenticadas como hijas.
ShellRoute buildShellRoute({
  required GlobalKey<NavigatorState> shellNavigatorKey,
  required BackendController backendController,
  required AuthRepository authRepository,
  required DashboardRepository dashboardRepository,
  required DashboardEditState dashboardEditState,
}) {
  return ShellRoute(
    navigatorKey: shellNavigatorKey,
    builder: (context, state, child) => AppShell(
      authRepository: authRepository,
      dashboardEditState: dashboardEditState,
      contentNavigatorKey: shellNavigatorKey,
      location: state.matchedLocation,
      child: child,
    ),
    routes: [
      GoRoute(
        path: InternalRoutes.dashboard,
        pageBuilder: (context, state) => fadeThroughPage(
          key: state.pageKey,
          child: DashboardPage(
            backendController: backendController,
            authRepository: authRepository,
            dashboardRepository: dashboardRepository,
            dashboardEditState: dashboardEditState,
          ),
        ),
      ),
      GoRoute(
        path: InternalRoutes.agents,
        pageBuilder: (context, state) =>
            fadeThroughPage(key: state.pageKey, child: const AgentsPage()),
      ),
      GoRoute(
        path: InternalRoutes.orchestrations,
        pageBuilder: (context, state) => fadeThroughPage(
          key: state.pageKey,
          child: DeferredPage(
            name: 'workflows_page',
            loader: workflows_page.loadLibrary,
            builder: (context) => workflows_page.WorkflowsPage(),
          ),
        ),
      ),
      GoRoute(
        path: InternalRoutes.workflowsLegacy,
        redirect: (context, state) => InternalRoutes.orchestrations,
      ),
      GoRoute(
        path: InternalRoutes.connections,
        pageBuilder: (context, state) =>
            fadeThroughPage(key: state.pageKey, child: const ConnectionsPage()),
      ),
      GoRoute(
        path: InternalRoutes.memory,
        pageBuilder: (context, state) =>
            fadeThroughPage(key: state.pageKey, child: const MemoryPage()),
      ),
      GoRoute(
        path: InternalRoutes.knowledge,
        pageBuilder: (context, state) =>
            fadeThroughPage(key: state.pageKey, child: const KnowledgePage()),
      ),
      GoRoute(
        path: InternalRoutes.explore,
        pageBuilder: (context, state) =>
            fadeThroughPage(key: state.pageKey, child: const ExplorePage()),
      ),
      GoRoute(
        path: InternalRoutes.labels,
        pageBuilder: (context, state) =>
            fadeThroughPage(key: state.pageKey, child: const LabelsPage()),
      ),
      GoRoute(
        path: InternalRoutes.manager,
        pageBuilder: (context, state) =>
            fadeThroughPage(key: state.pageKey, child: const ManagerPage()),
      ),
      GoRoute(
        path: InternalRoutes.profile,
        pageBuilder: (context, state) =>
            fadeThroughPage(key: state.pageKey, child: const ProfilePage()),
      ),
      GoRoute(
        path: InternalRoutes.checkout,
        pageBuilder: (context, state) => fadeThroughPage(
          key: state.pageKey,
          child: DeferredPage(
            name: 'checkout_page',
            loader: checkout_page.loadLibrary,
            builder: (context) => checkout_page.CheckoutPage(
              queryParameters: state.uri.queryParameters,
            ),
          ),
        ),
      ),
      GoRoute(
        path: InternalRoutes.vscodeAuth,
        pageBuilder: (context, state) => fadeThroughPage(
          key: state.pageKey,
          child: VsCodeAuthPage(
            authRepository: authRepository,
            state: state.uri.queryParameters['state'],
            callback: state.uri.queryParameters['callback'],
          ),
        ),
      ),
      GoRoute(
        path: InternalRoutes.admin,
        pageBuilder: (context, state) => fadeThroughPage(
          key: state.pageKey,
          child: DeferredPage(
            name: 'admin_page',
            loader: admin_page.loadLibrary,
            builder: (context) => admin_page.AdminPage(),
          ),
        ),
      ),
      GoRoute(
        path: InternalRoutes.adminMetadata,
        pageBuilder: (context, state) => fadeThroughPage(
          key: state.pageKey,
          child: DeferredPage(
            name: 'metadata_page',
            loader: metadata_page.loadLibrary,
            builder: (context) => metadata_page.MetadataPage(),
          ),
        ),
      ),
      GoRoute(
        path: InternalRoutes.adminCentinel,
        pageBuilder: (context, state) => fadeThroughPage(
          key: state.pageKey,
          child: DeferredPage(
            name: 'centinel_page',
            loader: centinel_page.loadLibrary,
            builder: (context) => centinel_page.CentinelPage(),
          ),
        ),
      ),
      GoRoute(
        path: InternalRoutes.adminLogs,
        redirect: (context, state) => InternalRoutes.adminMetadata,
      ),
      GoRoute(
        path: '${InternalRoutes.publicProfilePrefix}:username',
        pageBuilder: (context, state) => fadeThroughPage(
          key: state.pageKey,
          child: PublicProfilePage(
            username: state.pathParameters['username'] ?? '',
          ),
        ),
      ),
    ],
  );
}
