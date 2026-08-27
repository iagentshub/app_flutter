import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../core/network/api_client.dart';
import '../core/network/api_error.dart';
import '../features/auth/repositories/auth_repository.dart';
import '../features/dashboard/repositories/dashboard_repository.dart';
import '../features/executions/controllers/resource_executions_controller.dart';
import '../features/workflows/controllers/workflow_runs_controller.dart';
import '../shared/i18n/translated_texts.dart';
import '../shared/state/app_services_scope.dart';
import '../shared/state/backend_controller.dart';
import '../shared/state/dashboard_edit_state.dart';
import '../shared/state/locale_controller.dart';
import '../shared/state/session_controller.dart';
import '../shared/state/theme_controller.dart';
import '../shared/widgets/iagents_loading_indicator.dart';
import 'app_scroll_behavior.dart';
import 'router/router.dart';
import 'theme/app_theme.dart';

class App extends StatefulWidget {
  const App({
    required this.backendController,
    required this.sessionController,
    required this.localeController,
    required this.themeController,
    this.initialLocation,
    this.httpClient,
    this.requestTimeout = const Duration(seconds: 30),
    this.sessionValidationTimeout = const Duration(seconds: 5),
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

  /// Puntos de inyección para verificar el arranque sin tráfico real.
  final http.Client? httpClient;
  final Duration requestTimeout;

  /// Tiempo máximo que el arranque espera a `/api/auth/me` antes de ofrecer
  /// reintento o cambio de backend. No reduce el timeout de otras operaciones.
  final Duration sessionValidationTimeout;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final GoRouter _router;
  late final ApiClient _apiClient;
  late final AuthRepository _authRepository;
  late final DashboardRepository _dashboardRepository;
  late final DashboardEditState _dashboardEditState;
  late final WorkflowRunsController _workflowRunsController;
  late final ResourceExecutionsController _resourceExecutionsController;
  late final TranslatedTexts _errorTexts;
  bool _sessionValidationInFlight = false;
  bool _loginDashboardHandoff = false;

  @override
  void initState() {
    super.initState();
    // Catálogo global de códigos de API/SSE. Se mantiene separado de los
    // namespaces de página porque cualquier petición puede fallar antes de
    // que la vista concreta termine de cargar sus textos.
    _errorTexts = TranslatedTexts(
      localeController: widget.localeController,
      namespace: 'errors',
    );
    _apiClient = ApiClient(
      widget.backendController,
      client: widget.httpClient,
      requestTimeout: widget.requestTimeout,
      onUnauthorized: _handleUnauthorized,
      onSessionRenewed: (token) =>
          unawaited(widget.sessionController.renewAccessToken(token)),
      onRefreshTokenSeen: (token) =>
          unawaited(widget.sessionController.rememberRefreshToken(token)),
      refreshTokenProvider: () => widget.sessionController.refreshToken,
      sessionIdentity: () => widget.sessionController.cacheIdentity,
    );
    _authRepository = AuthRepository(_apiClient);
    _dashboardRepository = DashboardRepository(_apiClient);
    _dashboardEditState = DashboardEditState();
    _workflowRunsController = WorkflowRunsController(
      apiClient: _apiClient,
      sessionController: widget.sessionController,
    );
    _resourceExecutionsController = ResourceExecutionsController(
      apiClient: _apiClient,
      sessionController: widget.sessionController,
    );
    _router = AppRouter.create(
      backendController: widget.backendController,
      sessionController: widget.sessionController,
      localeController: widget.localeController,
      authRepository: _authRepository,
      dashboardRepository: _dashboardRepository,
      apiClient: _apiClient,
      dashboardEditState: _dashboardEditState,
      onLoginLoadingChanged: _setLoginDashboardHandoff,
      hasLoginDashboardHandoff: () => _loginDashboardHandoff,
      onDashboardReady: _finishLoginDashboardHandoff,
      onRetrySession: _revalidatePersistedSession,
      onUseAnotherAccount: _discardPersistedSession,
    );
    _router.routeInformationProvider.addListener(_onRouteChanged);
    final initialLocation = widget.initialLocation;
    if (initialLocation != null &&
        initialLocation !=
            _router.routeInformationProvider.value.uri.toString()) {
      _router.go(initialLocation);
    }
    _revalidatePersistedSession();
  }

  void _setLoginDashboardHandoff(bool loading) {
    if (!mounted || _loginDashboardHandoff == loading) return;
    setState(() => _loginDashboardHandoff = loading);
  }

  void _finishLoginDashboardHandoff() {
    _setLoginDashboardHandoff(false);
  }

  void _onRouteChanged() {
    if (!_loginDashboardHandoff) return;
    final path = _router.routeInformationProvider.value.uri.path;
    if (path == '/dashboard') return;
    if (path == '/login' && widget.sessionController.isLoggedIn) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _finishLoginDashboardHandoff();
    });
  }

  Future<void> _revalidatePersistedSession() async {
    if (_sessionValidationInFlight) return;
    final token = widget.sessionController.gaToken;
    if (token == null || token.isEmpty) {
      await _syncPublicTheme();
      return;
    }
    _sessionValidationInFlight = true;
    widget.sessionController.beginRevalidation();
    try {
      final user = await _authRepository.me(
        token,
        timeout: widget.sessionValidationTimeout,
      );
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
      // El callback global ya inicia el cierre en un 401; se espera también
      // aquí para que la transición de arranque sea determinista. Un 403
      // (p. ej. cuenta desactivada) exige igualmente volver a login.
      if (error.statusCode == 401 || error.statusCode == 403) {
        await widget.sessionController.logout();
        _apiClient.invalidateCache();
      } else {
        widget.sessionController.markBackendUnavailable();
      }
    } catch (_) {
      widget.sessionController.markBackendUnavailable();
    } finally {
      _sessionValidationInFlight = false;
    }
  }

  Future<void> _discardPersistedSession() async {
    await widget.sessionController.logout();
    _apiClient.invalidateCache();
    await _syncPublicTheme();
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
    _router.routeInformationProvider.removeListener(_onRouteChanged);
    _router.dispose();
    _errorTexts.dispose();
    _dashboardEditState.dispose();
    _workflowRunsController.dispose();
    _resourceExecutionsController.dispose();
    _apiClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Escucha también al idioma: sin `locale` ni `localizationsDelegates`,
    // Flutter caía en DefaultMaterialLocalizations —inglés fijo— y todo lo
    // que la app no dibuja a mano (Cut/Copy/Paste, selectores de fecha,
    // «Show menu» de los PopupMenuButton, VoiceOver/TalkBack) salía en
    // inglés aunque la app estuviera en español.
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.themeController,
        widget.localeController,
      ]),
      builder: (context, _) => AppServicesScope(
        apiClient: _apiClient,
        sessionController: widget.sessionController,
        localeController: widget.localeController,
        workflowRunsController: _workflowRunsController,
        resourceExecutionsController: _resourceExecutionsController,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          scrollBehavior: const AppScrollBehavior(),
          title: 'iAgents',
          theme: AppTheme.light(widget.themeController.themeId),
          darkTheme: AppTheme.dark(widget.themeController.themeId),
          themeMode: AppTheme.mode(widget.themeController.themeId),
          locale: widget.localeController.locale,
          supportedLocales: LocaleController.supportedLanguageCodes.map(
            Locale.new,
          ),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          routerConfig: _router,
          builder: (context, child) => Material(
            type: MaterialType.transparency,
            child: IAgentsLoadingOverlay(
              key: const Key('login-dashboard-loading-overlay'),
              loading: _loginDashboardHandoff,
              localeController: widget.localeController,
              logoSize: 96,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}
