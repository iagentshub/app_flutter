import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../features/admin/pages/admin_page.dart';
import '../../features/admin/pages/centinel_page.dart';
import '../../features/admin/pages/metadata_page.dart';
import '../../features/agents/pages/agents_page.dart';
import '../../features/auth/pages/forgot_password_page.dart';
import '../../features/auth/pages/backend_config_page.dart';
import '../../features/auth/pages/login_page.dart';
import '../../features/auth/pages/register_page.dart';
import '../../features/auth/pages/reset_password_page.dart';
import '../../features/auth/pages/verify_page.dart';
import '../../features/auth/pages/vscode_auth_page.dart';
import '../../features/connections/pages/connections_page.dart';
import '../../features/auth/repositories/auth_repository.dart';
import '../../features/dashboard/pages/dashboard_page.dart';
import '../../features/dashboard/repositories/dashboard_repository.dart';
import '../../features/explore/pages/explore_page.dart';
import '../../features/knowledge/pages/knowledge_page.dart';
import '../../features/labels/pages/labels_page.dart';
import '../../features/manager/pages/manager_page.dart';
import '../../features/memory/pages/memory_page.dart';
import '../../features/profile/pages/profile_page.dart';
import '../../features/public/pages/public_profile_page.dart';
import '../../features/workflows/pages/workflows_page.dart';
import '../../shared/state/backend_controller.dart';
import '../../shared/state/dashboard_edit_state.dart';
import '../../shared/state/locale_controller.dart';
import '../../shared/state/session_controller.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/terminal_view_transition.dart';
import '../../utils/safe_redirect.dart';
import 'not_found_page.dart';
import 'route_names.dart';

GoRouter createRouter({
  required BackendController backendController,
  required SessionController sessionController,
  required LocaleController localeController,
  required AuthRepository authRepository,
  required DashboardRepository dashboardRepository,
  required ApiClient apiClient,
  required DashboardEditState dashboardEditState,
}) {
  bool isPublicPath(String path) {
    const publicPaths = {
      RouteNames.home,
      RouteNames.login,
      RouteNames.register,
      RouteNames.forgotPassword,
      RouteNames.resetPassword,
      RouteNames.verify,
      RouteNames.backendConfig,
    };
    return publicPaths.contains(path);
  }

  return GoRouter(
    initialLocation: RouteNames.home,
    refreshListenable: sessionController,
    errorBuilder: (context, state) =>
        const TerminalViewTransition(child: NotFoundPage()),
    redirect: (context, state) {
      final location = state.matchedLocation;
      final public = isPublicPath(location);

      if (!sessionController.isLoggedIn && !public) {
        final redirect = Uri.encodeComponent(state.uri.toString());
        return '${RouteNames.login}?redirect=$redirect';
      }

      if (sessionController.isLoggedIn &&
          (location == RouteNames.login || location == RouteNames.home)) {
        return safeRedirect(state.uri.queryParameters['redirect']);
      }

      final isAdminRoute = location.startsWith(RouteNames.admin);
      final isAdmin = sessionController.user?.role == 'admin';
      if (isAdminRoute && !isAdmin) return RouteNames.dashboard;

      return null;
    },
    routes: [
      GoRoute(
        path: RouteNames.home,
        builder: (context, state) => TerminalViewTransition(
          child: LoginPage(
            backendController: backendController,
            sessionController: sessionController,
            localeController: localeController,
            authRepository: authRepository,
            redirectTo: state.uri.queryParameters['redirect'],
          ),
        ),
      ),
      for (final path in const [
        RouteNames.homeEn,
        RouteNames.about,
        RouteNames.aboutEn,
        RouteNames.docs,
        RouteNames.docsEn,
        RouteNames.support,
        RouteNames.supportEn,
        RouteNames.pricing,
        RouteNames.pricingEn,
        RouteNames.checkout,
      ])
        GoRoute(path: path, redirect: (context, state) => RouteNames.home),
      GoRoute(
        path: RouteNames.login,
        builder: (context, state) => TerminalViewTransition(
          child: LoginPage(
            backendController: backendController,
            sessionController: sessionController,
            localeController: localeController,
            authRepository: authRepository,
            redirectTo: state.uri.queryParameters['redirect'],
          ),
        ),
      ),
      GoRoute(
        path: RouteNames.register,
        builder: (context, state) => TerminalViewTransition(
          child: RegisterPage(
            authRepository: authRepository,
            localeController: localeController,
          ),
        ),
      ),
      GoRoute(
        path: RouteNames.forgotPassword,
        builder: (context, state) => TerminalViewTransition(
          child: ForgotPasswordPage(
            authRepository: authRepository,
            localeController: localeController,
          ),
        ),
      ),
      GoRoute(
        path: RouteNames.resetPassword,
        builder: (context, state) => TerminalViewTransition(
          child: ResetPasswordPage(
            authRepository: authRepository,
            localeController: localeController,
            token: state.uri.queryParameters['token'],
          ),
        ),
      ),
      GoRoute(
        path: RouteNames.verify,
        builder: (context, state) => TerminalViewTransition(
          child: VerifyPage(
            authRepository: authRepository,
            sessionController: sessionController,
            localeController: localeController,
            token: state.uri.queryParameters['token'],
          ),
        ),
      ),
      GoRoute(
        path: RouteNames.backendConfig,
        builder: (context, state) => TerminalViewTransition(
          child: BackendConfigPage(
            backendController: backendController,
            localeController: localeController,
          ),
        ),
      ),

      ShellRoute(
        builder: (context, state, child) => AppShell(
          sessionController: sessionController,
          authRepository: authRepository,
          dashboardEditState: dashboardEditState,
          localeController: localeController,
          apiClient: apiClient,
          location: state.matchedLocation,
          child: child,
        ),
        routes: [
          GoRoute(
            path: RouteNames.dashboard,
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
            path: RouteNames.agents,
            pageBuilder: (context, state) => NoTransitionPage(
              child: AgentsPage(
                apiClient: apiClient,
                sessionController: sessionController,
                localeController: localeController,
              ),
            ),
          ),
          GoRoute(
            path: RouteNames.orchestrations,
            pageBuilder: (context, state) => NoTransitionPage(
              child: WorkflowsPage(
                apiClient: apiClient,
                sessionController: sessionController,
                localeController: localeController,
              ),
            ),
          ),
          GoRoute(
            path: RouteNames.workflowsLegacy,
            redirect: (context, state) => RouteNames.orchestrations,
          ),
          GoRoute(
            path: RouteNames.connections,
            pageBuilder: (context, state) => NoTransitionPage(
              child: ConnectionsPage(
                apiClient: apiClient,
                sessionController: sessionController,
                localeController: localeController,
              ),
            ),
          ),
          GoRoute(
            path: RouteNames.memory,
            pageBuilder: (context, state) => NoTransitionPage(
              child: MemoryPage(
                apiClient: apiClient,
                sessionController: sessionController,
                localeController: localeController,
              ),
            ),
          ),
          GoRoute(
            path: RouteNames.knowledge,
            pageBuilder: (context, state) => NoTransitionPage(
              child: KnowledgePage(
                apiClient: apiClient,
                sessionController: sessionController,
                localeController: localeController,
              ),
            ),
          ),
          GoRoute(
            path: RouteNames.explore,
            pageBuilder: (context, state) => NoTransitionPage(
              child: ExplorePage(
                apiClient: apiClient,
                sessionController: sessionController,
                localeController: localeController,
              ),
            ),
          ),
          GoRoute(
            path: RouteNames.labels,
            pageBuilder: (context, state) => NoTransitionPage(
              child: LabelsPage(
                apiClient: apiClient,
                sessionController: sessionController,
                localeController: localeController,
              ),
            ),
          ),
          GoRoute(
            path: RouteNames.manager,
            pageBuilder: (context, state) => NoTransitionPage(
              child: ManagerPage(
                apiClient: apiClient,
                sessionController: sessionController,
                localeController: localeController,
              ),
            ),
          ),
          GoRoute(
            path: RouteNames.profile,
            pageBuilder: (context, state) => NoTransitionPage(
              child: ProfilePage(
                apiClient: apiClient,
                sessionController: sessionController,
                localeController: localeController,
              ),
            ),
          ),
          GoRoute(
            path: RouteNames.vscodeAuth,
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
            path: RouteNames.admin,
            pageBuilder: (context, state) => NoTransitionPage(
              child: AdminPage(
                apiClient: apiClient,
                sessionController: sessionController,
                localeController: localeController,
              ),
            ),
          ),
          GoRoute(
            path: RouteNames.adminMetadata,
            pageBuilder: (context, state) => NoTransitionPage(
              child: MetadataPage(
                apiClient: apiClient,
                sessionController: sessionController,
                localeController: localeController,
              ),
            ),
          ),
          GoRoute(
            path: RouteNames.adminCentinel,
            pageBuilder: (context, state) => NoTransitionPage(
              child: CentinelPage(
                apiClient: apiClient,
                sessionController: sessionController,
                localeController: localeController,
              ),
            ),
          ),
          GoRoute(
            path: RouteNames.adminLogs,
            redirect: (context, state) => RouteNames.adminMetadata,
          ),
          GoRoute(
            path: '${RouteNames.publicProfilePrefix}:username',
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
      ),
    ],
  );
}
