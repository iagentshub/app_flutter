import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/router/external_router.dart';
import '../../app/router/internal_router.dart';
import '../../app/router/router.dart';
import '../../app/theme/fnc_colors.dart';
import '../../app/theme/fnc_fonts.dart';
import '../../core/network/api_client.dart';
import '../../features/auth/repositories/auth_repository.dart';
import '../../models/dashboard/dashboard_widget_config.dart';
import '../../models/dashboard/dashboard_widget_registry.dart';
import '../../utils/i18n.dart';
import '../i18n/translated_texts.dart';
import '../navigation/shell_navigation.dart';
import '../state/app_services_scope.dart';
import '../state/dashboard_edit_state.dart';
import '../state/locale_controller.dart';
import '../state/theme_controller.dart';
import 'brand_icon.dart';
import 'motion/app_modal.dart';
import 'user_avatar.dart';

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
    required this.authRepository,
    required this.dashboardEditState,
    required this.contentNavigatorKey,
    required this.location,
    required this.child,
    super.key,
  });

  final AuthRepository authRepository;
  final DashboardEditState dashboardEditState;
  final GlobalKey<NavigatorState> contentNavigatorKey;
  final String location;
  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  /// Servicios globales (cliente HTTP, sesión, idioma): los aporta el
  /// AppServicesScope montado en App, no el router.
  late final _services = AppServicesScope.of(context);

  /// `TranslatedTexts` se escribió precisamente para no repetir aquí el
  /// «_loadTexts en initState + listener de cambio de idioma», pero el
  /// AppShell —el fichero que dio nombre al problema— se había quedado con el
  /// patrón antiguo. Además es el widget más persistente de la app: cada
  /// cambio de idioma hacía un setState sobre todo el layout en lugar de
  /// repintar el ListenableBuilder acotado que da el helper.
  late final TranslatedTexts _t;
  bool _sidebarCollapsed = false;

  bool _billingEnabled = false;
  Timer? _platformFlagsTimer;

  @override
  void initState() {
    super.initState();
    _t = TranslatedTexts(
      localeController: _services.localeController,
      namespace: 'nav',
    );
    _loadPlatformFlags();
    // billing_enabled lo puede cambiar un admin en cualquier momento durante
    // una sesión ya abierta — sin este refresco periódico, un usuario con la
    // app abierta desde antes no vería el cambio hasta recargar.
    _platformFlagsTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _loadPlatformFlags(),
    );
  }

  @override
  void dispose() {
    _platformFlagsTimer?.cancel();
    _t.dispose();
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

  String _tx(String key) => _t.text(key);

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
    AppRouter.go(context, route);
  }

  Future<void> _logout(BuildContext context) async {
    final themeController = ThemeControllerScope.of(context, listen: false);
    final confirm = await showAppDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_tx('logout_confirm_title')),
        content: Text(_tx('logout_confirm_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_tx('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_tx('logout')),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final token = _services.sessionController.gaToken;
    if (token != null && token.isNotEmpty) {
      await widget.authRepository.logout(token);
    }
    await _services.sessionController.logout();
    _services.apiClient.invalidateCache();
    try {
      final platform = await widget.authRepository.platformPublic();
      await themeController.syncFromBackend(
        platform['default_theme'] as String?,
      );
    } catch (_) {
      // Sin red se conserva el último tema efectivo hasta reconectar.
    }
    if (!context.mounted) return;
    AppRouter.toLogin(context);
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
      // Los textos van en la misma escucha que la sesión: al cambiar de
      // idioma solo se repinta este subárbol.
      listenable: Listenable.merge([_services.sessionController, _t]),
      builder: (context, _) {
        final isAdmin = _services.sessionController.user?.role == 'admin';
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
                        tx: _tx,
                      )
                    : AppSidebarNavigation(
                        isAdmin: isAdmin,
                        location: location,
                        username:
                            _services.sessionController.user?.username ??
                            'Usuario',
                        displayName:
                            _services.sessionController.user?.displayName,
                        avatarUrl:
                            _services.sessionController.user?.avatarUrl,
                        apiClient: _services.apiClient,
                        gaToken: _services.sessionController.gaToken,
                        email: _services.sessionController.user?.email,
                        role: _services.sessionController.user?.role ?? 'user',
                        languageCode: _services.localeController.languageCode,
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
                  listenable: _services.apiClient.backendController,
                  builder: (context, _) => Column(
                    children: [
                      _ConnectionIssueBanner(
                        apiClient: _services.apiClient,
                        tx: _tx,
                      ),
                      // El contenido va tal cual: `widget.child` es el
                      // Navigator del ShellRoute y lleva GlobalKey, así que
                      // envolverlo en un switcher —que mantiene la vista
                      // saliente y la entrante a la vez— lo pone en dos sitios
                      // del árbol. En debug eso es «Duplicate GlobalKey»; en
                      // release no hay aserción y la pantalla simplemente no
                      // se pinta hasta que algo fuerza un frame. La transición
                      // entre secciones la hace el router, dentro del
                      // Navigator: ver internal_router.dart.
                      Expanded(child: widget.child),
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
                                      username: _services.sessionController.user?.username ?? '',
                                      avatarUrl: _services.sessionController.user?.avatarUrl,
                                      apiClient: _services.apiClient,
                                      gaToken: _services.sessionController.gaToken,
                                      initial: sidebarAvatarInitial(
                                        sidebarVisibleName(
                                          _services
                                                  .sessionController
                                                  .user
                                                  ?.username ??
                                              'Usuario',
                                          _services
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
                                title: _titleForLocation(location, _tx),
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
                      _titleForLocation(location, _tx),
                      style: const TextStyle(
                        fontSize: FncFonts.size18,
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
