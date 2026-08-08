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
import '../shared/state/theme_controller.dart';
import 'router/router.dart';
import 'theme/app_theme.dart';

class App extends StatefulWidget {
  const App({
    required this.backendController,
    required this.sessionController,
    required this.localeController,
    required this.themeController,
    this.initialLocation,
    super.key,
  });

  final BackendController backendController;
  final SessionController sessionController;
  final LocaleController localeController;
  final ThemeController themeController;

  /// URL con la que cargó la pestaña originalmente (capturada en main.dart
  /// antes de que el splash la sobrescribiera). Si difiere de dónde arranca
  /// el router, se restaura en [initState].
  final String? initialLocation;

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
    _apiClient = ApiClient(
      widget.backendController,
      onUnauthorized: _handleUnauthorized,
      sessionIdentity: () => widget.sessionController.cacheIdentity,
    );
    _authRepository = AuthRepository(_apiClient);
    _dashboardRepository = DashboardRepository(_apiClient);
    _dashboardEditState = DashboardEditState();
    _router = AppRouter.create(
      backendController: widget.backendController,
      sessionController: widget.sessionController,
      localeController: widget.localeController,
      authRepository: _authRepository,
      dashboardRepository: _dashboardRepository,
      apiClient: _apiClient,
      dashboardEditState: _dashboardEditState,
    );
    final initialLocation = widget.initialLocation;
    if (initialLocation != null &&
        initialLocation != _router.routeInformationProvider.value.uri.toString()) {
      _router.go(initialLocation);
    }
    _revalidatePersistedSession();
  }

  Future<void> _revalidatePersistedSession() async {
    final token = widget.sessionController.gaToken;
    if (token == null || token.isEmpty) {
      await _syncPublicTheme();
      return;
    }
    try {
      final user = await _authRepository.me(token);
      await widget.sessionController.login(
        token: token,
        user: user,
        remember: true,
      );
      try {
        final settings = await _authRepository.getSettings(token);
        await widget.localeController.syncFromBackend(
          settings['language'] as String?,
        );
        await widget.themeController.syncFromBackend(
          settings['theme'] as String?,
        );
      } catch (_) {
        // Las preferencias visuales no deben invalidar una sesión válida.
      }
    } on ApiError catch (error) {
      // El 401 ya lo cierra _handleUnauthorized (callback global del
      // ApiClient); aquí solo falta cubrir el 403 (p. ej. cuenta
      // desactivada), que no es un token inválido pero igualmente exige
      // volver a login.
      if (error.statusCode == 403) {
        await widget.sessionController.logout();
        _apiClient.invalidateCache();
      }
    } catch (_) {
      // Sin red se conserva la sesión con rol mínimo. Nunca se confía en el
      // rol persistido hasta recibir una respuesta válida del backend.
    }
  }

  /// Callback global del [ApiClient]: cualquier petición autenticada que
  /// reciba un 401 (token caducado, revocado o inválido) cierra la sesión
  /// desde aquí, sin importar qué vista la haya disparado. El router
  /// (`refreshListenable: sessionController`) reacciona al cambio y
  /// redirige a login automáticamente.
  void _handleUnauthorized() {
    widget.sessionController.logout();
    _apiClient.invalidateCache();
  }

  Future<void> _syncPublicTheme() async {
    try {
      final platform = await _authRepository.platformPublic();
      await widget.themeController.syncFromBackend(
        platform['default_theme'] as String?,
      );
    } catch (_) {
      // Conserva el último tema efectivo cuando el backend no está disponible.
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
    return ListenableBuilder(
      listenable: widget.themeController,
      builder: (context, _) => MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'iAgents',
        theme: AppTheme.light(widget.themeController.themeId),
        darkTheme: AppTheme.dark(widget.themeController.themeId),
        themeMode: AppTheme.mode(widget.themeController.themeId),
        routerConfig: _router,
      ),
    );
  }
}
