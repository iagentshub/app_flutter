import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/router/route_names.dart';
import '../../core/navigation/public_site_uri.dart';
import '../../core/network/api_client.dart';
import '../../features/auth/repositories/auth_repository.dart';
import '../../models/dashboard/dashboard_widget_config.dart';
import '../../models/dashboard/dashboard_widget_registry.dart';
import '../i18n/locale_loader.dart';
import '../navigation/shell_navigation.dart';
import '../state/dashboard_edit_state.dart';
import '../state/locale_controller.dart';
import '../state/session_controller.dart';
import '../state/theme_controller.dart';
import 'brand_icon.dart';
import 'terminal_view_transition.dart';

part 'shell/app_shell_navigation.dart';
part 'shell/app_sidebar_footer.dart';
part 'shell/app_sidebar_rail.dart';
part 'shell/sidebar_tokens.dart';
part 'shell/widget_picker_drawer.dart';

/// En viewports estrechos la navegación vive en un drawer; desde 960 px se
/// convierte en un sidebar persistente para aprovechar el espacio web.
const _wideNavBreakpoint = 960.0;
const _sidebarWidth = 276.0;

/// Ancho contraído. El sidebar no desaparece: queda un rail de iconos, así la
/// navegación sigue a un clic en vez de esconderse tras la barra superior.
const _railWidth = 72.0;
const _drawerWidth = 304.0;

class AppShell extends StatefulWidget {
  const AppShell({
    required this.sessionController,
    required this.authRepository,
    required this.dashboardEditState,
    required this.localeController,
    required this.apiClient,
    required this.contentNavigatorKey,
    required this.location,
    required this.child,
    super.key,
  });

  final SessionController sessionController;
  final AuthRepository authRepository;
  final DashboardEditState dashboardEditState;
  final LocaleController localeController;
  final ApiClient apiClient;
  final GlobalKey<NavigatorState> contentNavigatorKey;
  final String location;
  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  Map<String, dynamic> _texts = const {};
  bool _sidebarCollapsed = false;

  bool _billingEnabled = false;
  Timer? _platformFlagsTimer;

  @override
  void initState() {
    super.initState();
    _loadTexts();
    _loadPlatformFlags();
    // billing_enabled lo puede cambiar un admin en cualquier momento durante
    // una sesión ya abierta — sin este refresco periódico, un usuario con la
    // app abierta desde antes no vería el cambio hasta recargar.
    _platformFlagsTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _loadPlatformFlags(),
    );
    widget.localeController.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    _platformFlagsTimer?.cancel();
    widget.localeController.removeListener(_onLocaleChanged);
    super.dispose();
  }

  Future<void> _loadPlatformFlags() async {
    try {
      final platform = await widget.authRepository.platformPublic();
      if (!mounted) return;
      setState(() {
        _billingEnabled = platform['billing_enabled'] == true;
      });
    } catch (_) {
      // Sin red se mantiene el último estado conocido.
    }
  }

  void _onLocaleChanged() => _loadTexts();

  Future<void> _loadTexts() async {
    final texts = await LocaleLoader.load(
      isEnglish: widget.localeController.isEnglish,
      namespace: 'nav',
    );
    if (!mounted) return;
    setState(() => _texts = texts);
  }

  String _tx(String key, String fallback) =>
      LocaleLoader.text(_texts, key, fallback: fallback);

  Future<void> _openPublicRoute(String path) async {
    await launchUrl(
      resolvePublicSiteUri(path: path, useSameOrigin: kIsWeb),
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_self',
    );
  }

  void _navigateTo(BuildContext context, String route, {required bool wide}) {
    if (!wide) Navigator.of(context).pop();

    // Los editores guiados se abren sobre GoRouter con MaterialPageRoute.
    // Los retiramos antes de cambiar de sección para que no queden visibles
    // encima del nuevo destino.
    final contentNavigator = widget.contentNavigatorKey.currentState;
    if (contentNavigator != null) closeShellOverlays(contentNavigator);
    context.go(route);
  }

  Future<void> _logout(BuildContext context) async {
    final themeController = ThemeControllerScope.of(context, listen: false);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_tx('logout_confirm_title', 'Cerrar sesión')),
        content: Text(
          _tx('logout_confirm_body', '¿Seguro que quieres cerrar sesión?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_tx('cancel', 'Cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_tx('logout', 'Cerrar sesión')),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final token = widget.sessionController.gaToken;
    if (token != null && token.isNotEmpty) {
      await widget.authRepository.logout(token);
    }
    await widget.sessionController.logout();
    widget.apiClient.invalidateCache();
    try {
      final platform = await widget.authRepository.platformPublic();
      await themeController.syncFromBackend(
        platform['default_theme'] as String?,
      );
    } catch (_) {
      // Sin red se conserva el último tema efectivo hasta reconectar.
    }
    if (!context.mounted) return;
    context.go(RouteNames.login);
  }

  @override
  Widget build(BuildContext context) {
    // El rol de sessionController.user puede revalidarse de forma asíncrona
    // después de este primer build (ver _AppState._revalidatePersistedSession
    // en app.dart) sin que cambie de ruta — sin este ListenableBuilder,
    // isAdmin/username/etc. quedarían congelados en su valor inicial hasta la
    // siguiente navegación, porque go_router solo repinta el árbol cuando
    // cambia el RouteMatchList, no cuando sessionController.notifyListeners()
    // se dispara estando en la misma pantalla.
    return ListenableBuilder(
      listenable: widget.sessionController,
      builder: (context, _) {
        final isAdmin = widget.sessionController.user?.role == 'admin';
        final location = widget.location;

        return ListenableBuilder(
          listenable: widget.dashboardEditState,
          builder: (context, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= _wideNavBreakpoint;
                final navContent = widget.dashboardEditState.editing
                    ? _WidgetPickerDrawerContent(
                        state: widget.dashboardEditState,
                        t: _texts,
                      )
                    : AppSidebarNavigation(
                        isAdmin: isAdmin,
                        location: location,
                        username:
                            widget.sessionController.user?.username ??
                            'Usuario',
                        displayName: widget.sessionController.user?.displayName,
                        email: widget.sessionController.user?.email,
                        role: widget.sessionController.user?.role ?? 'user',
                        isEnglish: widget.localeController.isEnglish,
                        billingEnabled: _billingEnabled,
                        tx: _tx,
                        showCloseButton: !wide,
                        onCollapse: wide
                            ? () => setState(() => _sidebarCollapsed = true)
                            : null,
                        onNavigate: (route) =>
                            _navigateTo(context, route, wide: wide),
                        onOpenPublicRoute: _openPublicRoute,
                        onLogout: () => _logout(context),
                      );

                final body = ListenableBuilder(
                  listenable: widget.apiClient.backendController,
                  builder: (context, _) => Column(
                    children: [
                      _ConnectionIssueBanner(
                        apiClient: widget.apiClient,
                        tx: _tx,
                      ),
                      Expanded(
                        child: TerminalViewTransition(
                          key: ValueKey(location),
                          child: widget.child,
                        ),
                      ),
                    ],
                  ),
                );

                if (wide) {
                  // Mientras se edita el dashboard el sidebar aloja el panel de
                  // widgets: ahí no cabe el rail, se fuerza expandido.
                  final collapsed =
                      _sidebarCollapsed && !widget.dashboardEditState.editing;
                  final tokens = _SidebarTokens.of(context);
                  return Scaffold(
                    body: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          width: collapsed ? _railWidth : _sidebarWidth,
                          decoration: BoxDecoration(
                            color: tokens.surface,
                            border: Border(
                              right: BorderSide(color: tokens.border),
                            ),
                          ),
                          child: ClipRect(
                            child: SafeArea(
                              right: false,
                              child: collapsed
                                  ? AppSidebarRail(
                                      isAdmin: isAdmin,
                                      location: location,
                                      initial: sidebarAvatarInitial(
                                        sidebarVisibleName(
                                          widget
                                                  .sessionController
                                                  .user
                                                  ?.username ??
                                              'Usuario',
                                          widget
                                              .sessionController
                                              .user
                                              ?.displayName,
                                        ),
                                      ),
                                      tx: _tx,
                                      onNavigate: (route) => _navigateTo(
                                        context,
                                        route,
                                        wide: wide,
                                      ),
                                      onExpand: () => setState(
                                        () => _sidebarCollapsed = false,
                                      ),
                                      onLogout: () => _logout(context),
                                    )
                                  : navContent,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              _ShellTopBar(
                                title: _titleForLocation(location, _texts),
                              ),
                              Expanded(child: body),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Scaffold(
                  appBar: AppBar(
                    toolbarHeight: 68,
                    titleSpacing: 4,
                    title: Text(
                      _titleForLocation(location, _texts),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  drawer: Drawer(
                    width: _drawerWidth,
                    elevation: 12,
                    surfaceTintColor: Colors.transparent,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.horizontal(
                        right: Radius.circular(24),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SafeArea(child: navContent),
                  ),
                  body: body,
                );
              },
            );
          },
        );
      },
    );
  }
}
