import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_names.dart';
import '../../core/network/api_client.dart';
import '../../features/auth/repositories/auth_repository.dart';
import '../../models/dashboard/dashboard_widget_config.dart';
import '../../models/dashboard/dashboard_widget_registry.dart';
import '../i18n/locale_loader.dart';
import '../state/dashboard_edit_state.dart';
import '../state/locale_controller.dart';
import '../state/session_controller.dart';
import 'terminal_view_transition.dart';

part 'shell/app_shell_navigation.dart';
part 'shell/widget_picker_drawer.dart';

/// Por debajo de este ancho el nav vive en un Drawer con hamburguesa
/// (móvil); por encima, un sidebar fijo siempre visible (tablet/desktop/web
/// ancho) — igual que el sidebar persistente de 232px de frontend_vanilla,
/// que solo colapsa a hamburguesa por debajo de 768px CSS.
const _wideNavBreakpoint = 900.0;
const _sidebarWidth = 240.0;

class AppShell extends StatefulWidget {
  const AppShell({
    required this.sessionController,
    required this.authRepository,
    required this.dashboardEditState,
    required this.localeController,
    required this.apiClient,
    required this.location,
    required this.child,
    super.key,
  });

  final SessionController sessionController;
  final AuthRepository authRepository;
  final DashboardEditState dashboardEditState;
  final LocaleController localeController;
  final ApiClient apiClient;
  final String location;
  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  Map<String, dynamic> _texts = const {};

  @override
  void initState() {
    super.initState();
    _loadTexts();
    widget.localeController.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    widget.localeController.removeListener(_onLocaleChanged);
    super.dispose();
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

  Future<void> _logout(BuildContext context) async {
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
    if (!context.mounted) return;
    context.go(RouteNames.login);
  }

  @override
  Widget build(BuildContext context) {
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
                : _NavContent(
                    isAdmin: isAdmin,
                    location: location,
                    username:
                        widget.sessionController.user?.username ?? 'Usuario',
                    role: widget.sessionController.user?.role ?? 'user',
                    tx: _tx,
                    closeDrawerOnTap: !wide,
                    onLogout: () => _logout(context),
                  );

            final body = ListenableBuilder(
              listenable: widget.apiClient.backendController,
              builder: (context, _) => Column(
                children: [
                  _ConnectionIssueBanner(apiClient: widget.apiClient, tx: _tx),
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
              return Scaffold(
                appBar: AppBar(
                  title: Text(_titleForLocation(location, _texts)),
                  automaticallyImplyLeading: false,
                ),
                body: Row(
                  children: [
                    SizedBox(
                      width: _sidebarWidth,
                      child: Material(
                        elevation: 1,
                        child: SafeArea(right: false, child: navContent),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: body),
                  ],
                ),
              );
            }

            return Scaffold(
              appBar: AppBar(title: Text(_titleForLocation(location, _texts))),
              drawer: Drawer(child: SafeArea(child: navContent)),
              body: body,
            );
          },
        );
      },
    );
  }
}
