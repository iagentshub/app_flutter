import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../features/admin/pages/admin_page.dart';
import '../../features/admin/pages/centinel_page.dart';
import '../../features/admin/pages/logs_page.dart';
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
import '../../shared/state/session_controller.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/terminal_view_transition.dart';
import '../../utils/safe_redirect.dart';
import 'route_names.dart';

GoRouter createRouter({
  required BackendController backendController,
  required SessionController sessionController,
  required AuthRepository authRepository,
  required DashboardRepository dashboardRepository,
  required ApiClient apiClient,
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
    errorBuilder: (context, state) => const TerminalViewTransition(child: _NotFoundPage()),
    redirect: (context, state) {
      final location = state.matchedLocation;
      final public = isPublicPath(location);

      if (!sessionController.isLoggedIn && !public) {
        final redirect = Uri.encodeComponent(state.uri.toString());
        return '${RouteNames.login}?redirect=$redirect';
      }

      if (sessionController.isLoggedIn && (location == RouteNames.login || location == RouteNames.home)) {
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
            authRepository: authRepository,
            redirectTo: state.uri.queryParameters['redirect'],
          ),
        ),
      ),
      GoRoute(
        path: RouteNames.homeEn,
        redirect: (context, state) => RouteNames.home,
      ),
      GoRoute(path: RouteNames.about, redirect: (context, state) => RouteNames.home),
      GoRoute(path: RouteNames.aboutEn, redirect: (context, state) => RouteNames.home),
      GoRoute(path: RouteNames.docs, redirect: (context, state) => RouteNames.home),
      GoRoute(path: RouteNames.docsEn, redirect: (context, state) => RouteNames.home),
      GoRoute(path: RouteNames.support, redirect: (context, state) => RouteNames.home),
      GoRoute(path: RouteNames.supportEn, redirect: (context, state) => RouteNames.home),
      GoRoute(path: RouteNames.pricing, redirect: (context, state) => RouteNames.home),
      GoRoute(path: RouteNames.pricingEn, redirect: (context, state) => RouteNames.home),
      GoRoute(path: RouteNames.checkout, redirect: (context, state) => RouteNames.home),
      GoRoute(
        path: RouteNames.login,
        builder: (context, state) => TerminalViewTransition(
          child: LoginPage(
            backendController: backendController,
            sessionController: sessionController,
            authRepository: authRepository,
            redirectTo: state.uri.queryParameters['redirect'],
          ),
        ),
      ),
      GoRoute(
        path: RouteNames.register,
        builder: (context, state) => TerminalViewTransition(
          child: RegisterPage(authRepository: authRepository),
        ),
      ),
      GoRoute(
        path: RouteNames.forgotPassword,
        builder: (context, state) => TerminalViewTransition(
          child: ForgotPasswordPage(authRepository: authRepository),
        ),
      ),
      GoRoute(
        path: RouteNames.resetPassword,
        builder: (context, state) => TerminalViewTransition(
          child: ResetPasswordPage(authRepository: authRepository, token: state.uri.queryParameters['token']),
        ),
      ),
      GoRoute(
        path: RouteNames.verify,
        builder: (context, state) => TerminalViewTransition(
          child: VerifyPage(
            authRepository: authRepository,
            sessionController: sessionController,
            token: state.uri.queryParameters['token'],
          ),
        ),
      ),
      GoRoute(
        path: RouteNames.backendConfig,
        builder: (context, state) => TerminalViewTransition(
          child: BackendConfigPage(backendController: backendController),
        ),
      ),

      ShellRoute(
        builder: (context, state, child) => AppShell(
          sessionController: sessionController,
          authRepository: authRepository,
          location: state.matchedLocation,
          child: child,
        ),
        routes: [
          GoRoute(
            path: RouteNames.dashboard,
            builder: (context, state) => DashboardPage(
              backendController: backendController,
              sessionController: sessionController,
              authRepository: authRepository,
              dashboardRepository: dashboardRepository,
              apiClient: apiClient,
            ),
          ),
          GoRoute(
            path: RouteNames.agents,
            builder: (context, state) => AgentsPage(
              apiClient: apiClient,
              sessionController: sessionController,
            ),
          ),
          GoRoute(
            path: RouteNames.orchestrations,
            builder: (context, state) => WorkflowsPage(
              apiClient: apiClient,
              sessionController: sessionController,
            ),
          ),
          GoRoute(path: RouteNames.workflowsLegacy, redirect: (context, state) => RouteNames.orchestrations),
          GoRoute(
            path: RouteNames.connections,
            builder: (context, state) => ConnectionsPage(
              apiClient: apiClient,
              sessionController: sessionController,
            ),
          ),
          GoRoute(
            path: RouteNames.memory,
            builder: (context, state) => MemoryPage(
              apiClient: apiClient,
              sessionController: sessionController,
            ),
          ),
          GoRoute(
            path: RouteNames.knowledge,
            builder: (context, state) => KnowledgePage(
              apiClient: apiClient,
              sessionController: sessionController,
            ),
          ),
          GoRoute(
            path: RouteNames.explore,
            builder: (context, state) => ExplorePage(
              apiClient: apiClient,
              sessionController: sessionController,
            ),
          ),
          GoRoute(
            path: RouteNames.labels,
            builder: (context, state) => LabelsPage(
              apiClient: apiClient,
              sessionController: sessionController,
            ),
          ),
          GoRoute(
            path: RouteNames.manager,
            builder: (context, state) => ManagerPage(
              apiClient: apiClient,
              sessionController: sessionController,
            ),
          ),
          GoRoute(
            path: RouteNames.profile,
            builder: (context, state) => ProfilePage(
              apiClient: apiClient,
              sessionController: sessionController,
            ),
          ),
          GoRoute(
            path: RouteNames.vscodeAuth,
            builder: (context, state) => VsCodeAuthPage(
              authRepository: authRepository,
              sessionController: sessionController,
              state: state.uri.queryParameters['state'],
              callback: state.uri.queryParameters['callback'],
            ),
          ),
          GoRoute(
            path: RouteNames.admin,
            builder: (context, state) => AdminPage(
              apiClient: apiClient,
              sessionController: sessionController,
            ),
          ),
          GoRoute(
            path: RouteNames.adminMetadata,
            builder: (context, state) => MetadataPage(
              apiClient: apiClient,
              sessionController: sessionController,
            ),
          ),
          GoRoute(
            path: RouteNames.adminCentinel,
            builder: (context, state) => CentinelPage(
              apiClient: apiClient,
              sessionController: sessionController,
            ),
          ),
          GoRoute(
            path: RouteNames.adminLogs,
            builder: (context, state) => LogsPageView(
              apiClient: apiClient,
              sessionController: sessionController,
            ),
          ),
          GoRoute(
            path: '${RouteNames.publicProfilePrefix}:username',
            builder: (context, state) => PublicProfilePage(
              username: state.pathParameters['username'] ?? '',
              apiClient: apiClient,
              sessionController: sessionController,
            ),
          ),
        ],
      ),
    ],
  );
}

class _NotFoundPage extends StatelessWidget {
  const _NotFoundPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Página no encontrada'),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => context.go(RouteNames.login),
                child: const Text('Ir al inicio'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
