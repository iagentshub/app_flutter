import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../features/admin/pages/admin_page.dart';
import '../../features/admin/pages/centinel_page.dart';
import '../../features/admin/pages/metadata_page.dart';
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
import '../../features/public/pages/checkout_page.dart';
import '../../features/public/pages/public_profile_page.dart';
import '../../features/workflows/pages/workflows_page.dart';
import '../../shared/state/backend_controller.dart';
import '../../shared/state/dashboard_edit_state.dart';
import '../../shared/state/locale_controller.dart';
import '../../shared/state/session_controller.dart';
import '../../shared/widgets/app_shell.dart';

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
  required SessionController sessionController,
  required AuthRepository authRepository,
  required DashboardRepository dashboardRepository,
  required ApiClient apiClient,
  required DashboardEditState dashboardEditState,
  required LocaleController localeController,
}) {
  return ShellRoute(
    navigatorKey: shellNavigatorKey,
    builder: (context, state, child) => AppShell(
      sessionController: sessionController,
      authRepository: authRepository,
      dashboardEditState: dashboardEditState,
      localeController: localeController,
      apiClient: apiClient,
      contentNavigatorKey: shellNavigatorKey,
      location: state.matchedLocation,
      child: child,
    ),
    routes: [
      GoRoute(
        path: InternalRoutes.dashboard,
        pageBuilder: (context, state) => NoTransitionPage(
          child: DashboardPage(
            backendController: backendController,
            sessionController: sessionController,
            authRepository: authRepository,
            dashboardRepository: dashboardRepository,
            apiClient: apiClient,
            dashboardEditState: dashboardEditState,
            localeController: localeController,
          ),
        ),
      ),
      GoRoute(
        path: InternalRoutes.agents,
        pageBuilder: (context, state) => NoTransitionPage(
          child: AgentsPage(
            apiClient: apiClient,
            sessionController: sessionController,
            localeController: localeController,
          ),
        ),
      ),
      GoRoute(
        path: InternalRoutes.orchestrations,
        pageBuilder: (context, state) => NoTransitionPage(
          child: WorkflowsPage(
            apiClient: apiClient,
            sessionController: sessionController,
            localeController: localeController,
          ),
        ),
      ),
      GoRoute(
        path: InternalRoutes.workflowsLegacy,
        redirect: (context, state) => InternalRoutes.orchestrations,
      ),
      GoRoute(
        path: InternalRoutes.connections,
        pageBuilder: (context, state) => NoTransitionPage(
          child: ConnectionsPage(
            apiClient: apiClient,
            sessionController: sessionController,
            localeController: localeController,
          ),
        ),
      ),
      GoRoute(
        path: InternalRoutes.memory,
        pageBuilder: (context, state) => NoTransitionPage(
          child: MemoryPage(
            apiClient: apiClient,
            sessionController: sessionController,
            localeController: localeController,
          ),
        ),
      ),
      GoRoute(
        path: InternalRoutes.knowledge,
        pageBuilder: (context, state) => NoTransitionPage(
          child: KnowledgePage(
            apiClient: apiClient,
            sessionController: sessionController,
            localeController: localeController,
          ),
        ),
      ),
      GoRoute(
        path: InternalRoutes.explore,
        pageBuilder: (context, state) => NoTransitionPage(
          child: ExplorePage(
            apiClient: apiClient,
            sessionController: sessionController,
            localeController: localeController,
          ),
        ),
      ),
      GoRoute(
        path: InternalRoutes.labels,
        pageBuilder: (context, state) => NoTransitionPage(
          child: LabelsPage(
            apiClient: apiClient,
            sessionController: sessionController,
            localeController: localeController,
          ),
        ),
      ),
      GoRoute(
        path: InternalRoutes.manager,
        pageBuilder: (context, state) => NoTransitionPage(
          child: ManagerPage(
            apiClient: apiClient,
            sessionController: sessionController,
            localeController: localeController,
          ),
        ),
      ),
      GoRoute(
        path: InternalRoutes.profile,
        pageBuilder: (context, state) => NoTransitionPage(
          child: ProfilePage(
            apiClient: apiClient,
            sessionController: sessionController,
            localeController: localeController,
          ),
        ),
      ),
      GoRoute(
        path: InternalRoutes.checkout,
        pageBuilder: (context, state) => NoTransitionPage(
          child: CheckoutPage(
            apiClient: apiClient,
            queryParameters: state.uri.queryParameters,
          ),
        ),
      ),
      GoRoute(
        path: InternalRoutes.vscodeAuth,
        pageBuilder: (context, state) => NoTransitionPage(
          child: VsCodeAuthPage(
            authRepository: authRepository,
            sessionController: sessionController,
            localeController: localeController,
            state: state.uri.queryParameters['state'],
            callback: state.uri.queryParameters['callback'],
          ),
        ),
      ),
      GoRoute(
        path: InternalRoutes.admin,
        pageBuilder: (context, state) => NoTransitionPage(
          child: AdminPage(
            apiClient: apiClient,
            sessionController: sessionController,
            localeController: localeController,
          ),
        ),
      ),
      GoRoute(
        path: InternalRoutes.adminMetadata,
        pageBuilder: (context, state) => NoTransitionPage(
          child: MetadataPage(
            apiClient: apiClient,
            sessionController: sessionController,
            localeController: localeController,
          ),
        ),
      ),
      GoRoute(
        path: InternalRoutes.adminCentinel,
        pageBuilder: (context, state) => NoTransitionPage(
          child: CentinelPage(
            apiClient: apiClient,
            sessionController: sessionController,
            localeController: localeController,
          ),
        ),
      ),
      GoRoute(
        path: InternalRoutes.adminLogs,
        redirect: (context, state) => InternalRoutes.adminMetadata,
      ),
      GoRoute(
        path: '${InternalRoutes.publicProfilePrefix}:username',
        pageBuilder: (context, state) => NoTransitionPage(
          child: PublicProfilePage(
            username: state.pathParameters['username'] ?? '',
            apiClient: apiClient,
            sessionController: sessionController,
            localeController: localeController,
          ),
        ),
      ),
    ],
  );
}
