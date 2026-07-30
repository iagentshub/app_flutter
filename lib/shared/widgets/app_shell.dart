import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_names.dart';
import '../../core/network/api_client.dart';
import '../../features/auth/repositories/auth_repository.dart';
import '../../models/dashboard/dashboard_widget_config.dart';
import '../i18n/locale_loader.dart';
import '../state/dashboard_edit_state.dart';
import '../state/locale_controller.dart';
import '../state/session_controller.dart';
import 'terminal_view_transition.dart';

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

/// Contenido de navegación compartido entre el Drawer (móvil) y el sidebar
/// fijo (tablet/desktop): igual estructura, solo cambia si cierra el drawer
/// al navegar.
class _NavContent extends StatelessWidget {
  const _NavContent({
    required this.isAdmin,
    required this.location,
    required this.username,
    required this.role,
    required this.tx,
    required this.closeDrawerOnTap,
    required this.onLogout,
  });

  final bool isAdmin;
  final String location;
  final String username;
  final String role;
  final String Function(String key, String fallback) tx;
  final bool closeDrawerOnTap;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              ListTile(
                title: Text(username),
                subtitle: Text(role),
                leading: const Icon(Icons.account_circle_outlined),
              ),
              const Divider(),
              ..._mainItems.map(
                (item) => _NavItemTile(
                  icon: item.icon,
                  label: tx(item.labelKey, item.labelKey),
                  route: item.route,
                  selected: location == item.route,
                  closeDrawerOnTap: closeDrawerOnTap,
                ),
              ),
              const Divider(),
              ..._secondaryItems.map(
                (item) => _NavItemTile(
                  icon: item.icon,
                  label: tx(item.labelKey, item.labelKey),
                  route: item.route,
                  selected: location == item.route,
                  closeDrawerOnTap: closeDrawerOnTap,
                ),
              ),
              if (isAdmin) const Divider(),
              if (isAdmin)
                ..._adminItems.map(
                  (item) => _NavItemTile(
                    icon: item.icon,
                    label: tx(item.labelKey, item.labelKey),
                    route: item.route,
                    selected: location == item.route,
                    closeDrawerOnTap: closeDrawerOnTap,
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.logout),
          title: Text(tx('logout', 'Cerrar sesión')),
          onTap: onLogout,
        ),
      ],
    );
  }
}

/// Aviso persistente cuando el backend seleccionado deja de responder, para
/// que un fallo de conexión no pase inadvertido en el resto de la app.
class _ConnectionIssueBanner extends StatelessWidget {
  const _ConnectionIssueBanner({required this.apiClient, required this.tx});

  final ApiClient apiClient;
  final String Function(String key, String fallback) tx;

  @override
  Widget build(BuildContext context) {
    final backendController = apiClient.backendController;
    final error = backendController.lastConnectionError;
    if (error == null) return const SizedBox.shrink();

    return Material(
      color: Colors.red.shade700,
      child: InkWell(
        onTap: () => context.push(RouteNames.backendConfig),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.wifi_off, color: Colors.white, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tx(
                        'backend_connection_issue',
                        "No se pudo conectar con {backend}: {error}",
                      )
                      .replaceAll(
                        '{backend}',
                        backendController.selectedOption.label,
                      )
                      .replaceAll('{error}', error),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                tx('backend_connection_action', 'Cambiar backend'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItemTile extends StatelessWidget {
  const _NavItemTile({
    required this.icon,
    required this.label,
    required this.route,
    required this.selected,
    this.closeDrawerOnTap = false,
  });

  final IconData icon;
  final String label;
  final String route;
  final bool selected;
  final bool closeDrawerOnTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      selected: selected,
      onTap: () {
        if (closeDrawerOnTap) Navigator.of(context).pop();
        context.go(route);
      },
    );
  }
}

class _NavItem {
  const _NavItem(this.route, this.labelKey, this.icon);

  final String route;
  final String labelKey;
  final IconData icon;
}

// Mismos 6 items primarios que frontend_react/frontend_vanilla (main-nav).
// Memory y Skills viven dentro de Knowledge (son pestañas, no nav propio);
// Manager no aparece en el nav web (se llega desde Profile > Workspaces).
const _mainItems = [
  _NavItem(RouteNames.dashboard, 'dashboard', Icons.dashboard_outlined),
  _NavItem(RouteNames.explore, 'explore', Icons.travel_explore_outlined),
  _NavItem(RouteNames.agents, 'agents', Icons.smart_toy_outlined),
  _NavItem(RouteNames.orchestrations, 'workflows', Icons.hub_outlined),
  _NavItem(RouteNames.knowledge, 'knowledge', Icons.school_outlined),
  _NavItem(RouteNames.connections, 'connections', Icons.cable_outlined),
];

// Accesos que en web viven en la fila de iconos del footer / avatar del nav,
// no en la lista principal.
const _secondaryItems = [
  _NavItem(RouteNames.labels, 'labels', Icons.label_outline),
  _NavItem(RouteNames.profile, 'profile', Icons.person_outline),
];

const _adminItems = [
  _NavItem(RouteNames.admin, 'admin', Icons.admin_panel_settings_outlined),
  _NavItem(
    RouteNames.adminMetadata,
    'admin_metadata',
    Icons.table_rows_outlined,
  ),
  _NavItem(RouteNames.adminCentinel, 'admin_centinel', Icons.security_outlined),
];

String _titleForLocation(String location, Map<String, dynamic> t) {
  for (final item in [..._mainItems, ..._secondaryItems, ..._adminItems]) {
    if (location == item.route)
      return LocaleLoader.text(t, item.labelKey, fallback: item.labelKey);
  }
  if (location.startsWith(RouteNames.publicProfilePrefix)) {
    return LocaleLoader.text(t, 'public_profile', fallback: 'Public Profile');
  }
  return LocaleLoader.text(t, 'app_title', fallback: 'iAgents Hub');
}

/// Sustituye la navegación normal del drawer mientras el dashboard está en
/// modo "Personalizar": aquí se listan los widgets todavía no añadidos.
class _WidgetPickerDrawerContent extends StatelessWidget {
  const _WidgetPickerDrawerContent({required this.state, required this.t});

  final DashboardEditState state;
  final Map<String, dynamic> t;

  String _dashboardTx(String key, String fallback) =>
      LocaleLoader.text(t, 'dashboard_$key', fallback: fallback);

  @override
  Widget build(BuildContext context) {
    final missing = state.missing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            LocaleLoader.text(
              t,
              'customize_dashboard',
              fallback: 'Personalizar dashboard',
            ),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            LocaleLoader.text(
              t,
              'customize_hint',
              fallback: 'Toca un widget para añadirlo al dashboard.',
            ),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: missing.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    LocaleLoader.text(
                      t,
                      'customize_empty',
                      fallback: 'Ya has añadido todos los widgets disponibles.',
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: missing.map((id) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => state.addWidget(id),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  dashboardWidgetTitle(id, _dashboardTx),
                                ),
                              ),
                              Chip(
                                label: Text(
                                  dashboardWidgetSizeLabel(id, _dashboardTx),
                                ),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.add, size: 18),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}
