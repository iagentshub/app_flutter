part of '../app_shell.dart';

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
// Manager no aparece en el nav web (se llega desde Profile > Groups).
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
    if (location == item.route) {
      return LocaleLoader.text(t, item.labelKey, fallback: item.labelKey);
    }
  }
  if (location.startsWith(RouteNames.publicProfilePrefix)) {
    return LocaleLoader.text(t, 'public_profile', fallback: 'Public Profile');
  }
  return LocaleLoader.text(t, 'app_title', fallback: 'iAgents');
}

/// Sustituye la navegación normal del drawer mientras el dashboard está en
/// modo "Personalizar": aquí se listan los widgets todavía no añadidos.
