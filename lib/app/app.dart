import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/network/api_client.dart';
import '../core/network/api_error.dart';
import '../features/auth/repositories/auth_repository.dart';
import '../features/dashboard/repositories/dashboard_repository.dart';
import '../shared/state/backend_controller.dart';
import '../shared/state/dashboard_edit_state.dart';
import '../shared/state/locale_controller.dart';
import '../shared/state/session_controller.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class App extends StatefulWidget {
  const App({
    required this.backendController,
    required this.sessionController,
    required this.localeController,
    super.key,
  });

  final BackendController backendController;
  final SessionController sessionController;
  final LocaleController localeController;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final GoRouter _router;
  late final ApiClient _apiClient;
  late final AuthRepository _authRepository;
  late final DashboardRepository _dashboardRepository;
  late final DashboardEditState _dashboardEditState;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient(widget.backendController);
    _authRepository = AuthRepository(_apiClient);
    _dashboardRepository = DashboardRepository(_apiClient);
    _dashboardEditState = DashboardEditState();
    _router = createRouter(
      backendController: widget.backendController,
      sessionController: widget.sessionController,
      localeController: widget.localeController,
      authRepository: _authRepository,
      dashboardRepository: _dashboardRepository,
      apiClient: _apiClient,
      dashboardEditState: _dashboardEditState,
    );
    _revalidatePersistedSession();
  }

  Future<void> _revalidatePersistedSession() async {
    final token = widget.sessionController.gaToken;
    if (token == null || token.isEmpty) return;
    try {
      final userFuture = _authRepository.me(token);
      final languageFuture = _authRepository.getLanguage(token);
      final user = await userFuture;
      final language = await languageFuture;
      await widget.sessionController.login(
        token: token,
        user: user,
        remember: true,
      );
      await widget.localeController.syncFromBackend(language);
    } on ApiError catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await widget.sessionController.logout();
        _apiClient.invalidateCache();
      }
    } catch (_) {
      // Sin red se conserva la sesión con rol mínimo. Nunca se confía en el
      // rol persistido hasta recibir una respuesta válida del backend.
    }
  }

  @override
  void dispose() {
    _router.dispose();
    _dashboardEditState.dispose();
    _apiClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'iAgents',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      routerConfig: _router,
    );
  }
}
