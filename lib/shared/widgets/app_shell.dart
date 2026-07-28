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

class AppShell extends StatelessWidget {
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

  Future<void> _logout(BuildContext context, Map<String, dynamic> t) async {
    Navigator.of(context).pop();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LocaleLoader.text(t, 'logout_confirm_title', fallback: 'Cerrar sesión')),
        content: Text(
          LocaleLoader.text(t, 'logout_confirm_body', fallback: '¿Seguro que quieres cerrar sesión?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(LocaleLoader.text(t, 'cancel', fallback: 'Cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(LocaleLoader.text(t, 'logout', fallback: 'Cerrar sesión')),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final token = sessionController.gaToken;
    if (token != null && token.isNotEmpty) {
      await authRepository.logout(token);
    }
    await sessionController.logout();
    apiClient.invalidateCache();
    if (!context.mounted) return;
    context.go(RouteNames.login);
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = sessionController.user?.role == 'admin';

    return ListenableBuilder(
      listenable: Listenable.merge([dashboardEditState, localeController]),
      builder: (context, _) {
        return FutureBuilder<Map<String, dynamic>>(
          future: LocaleLoader.load(isEnglish: localeController.isEnglish, namespace: 'nav'),
          builder: (context, snapshot) {
            final t = snapshot.data ?? const <String, dynamic>{};
            String tx(String key, String fallback) => LocaleLoader.text(t, key, fallback: fallback);

            return Scaffold(
              appBar: AppBar(title: Text(_titleForLocation(location, t))),
              drawer: Drawer(
                child: SafeArea(
                  child: dashboardEditState.editing
                      ? _WidgetPickerDrawerContent(state: dashboardEditState, t: t)
                      : Column(
                          children: [
                            Expanded(
                              child: ListView(
                                children: [
                                  ListTile(
                                    title: Text(sessionController.user?.username ?? 'Usuario'),
                                    subtitle: Text(sessionController.user?.role ?? 'user'),
                                    leading: const Icon(Icons.account_circle_outlined),
                                  ),
                                  const Divider(),
                                  ..._mainItems.map(
                                    (item) => _NavItemTile(
                                      icon: item.icon,
                                      label: tx(item.labelKey, item.labelKey),
                                      route: item.route,
                                      selected: location == item.route,
                                    ),
                                  ),
                                  const Divider(),
                                  ..._secondaryItems.map(
                                    (item) => _NavItemTile(
                                      icon: item.icon,
                                      label: tx(item.labelKey, item.labelKey),
                                      route: item.route,
                                      selected: location == item.route,
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
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.logout),
                              title: Text(tx('logout', 'Cerrar sesión')),
                              onTap: () => _logout(context, t),
                            ),
                          ],
                        ),
                ),
              ),
              body: TerminalViewTransition(key: ValueKey(location), child: child),
            );
          },
        );
      },
    );
  }
}

class _NavItemTile extends StatelessWidget {
  const _NavItemTile({
    required this.icon,
    required this.label,
    required this.route,
    required this.selected,
  });

  final IconData icon;
  final String label;
  final String route;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      selected: selected,
      onTap: () {
        Navigator.of(context).pop();
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
  _NavItem(RouteNames.adminMetadata, 'admin_metadata', Icons.table_rows_outlined),
  _NavItem(RouteNames.adminCentinel, 'admin_centinel', Icons.security_outlined),
  _NavItem(RouteNames.adminLogs, 'admin_logs', Icons.receipt_long_outlined),
];

String _titleForLocation(String location, Map<String, dynamic> t) {
  for (final item in [..._mainItems, ..._secondaryItems, ..._adminItems]) {
    if (location == item.route) return LocaleLoader.text(t, item.labelKey, fallback: item.labelKey);
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

  @override
  Widget build(BuildContext context) {
    final missing = state.missing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            LocaleLoader.text(t, 'customize_dashboard', fallback: 'Personalizar dashboard'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            LocaleLoader.text(t, 'customize_hint', fallback: 'Toca un widget para añadirlo al dashboard.'),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: missing.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    LocaleLoader.text(t, 'customize_empty', fallback: 'Ya has añadido todos los widgets disponibles.'),
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
                              Expanded(child: Text(dashboardWidgetTitle(id))),
                              Chip(
                                label: Text(dashboardWidgetSizeLabel(id)),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
