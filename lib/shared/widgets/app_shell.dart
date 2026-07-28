import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_names.dart';
import '../state/session_controller.dart';
import 'terminal_view_transition.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    required this.sessionController,
    required this.location,
    required this.child,
    super.key,
  });

  final SessionController sessionController;
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isAdmin = sessionController.user?.role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: Text(_titleForLocation(location)),
      ),
      drawer: Drawer(
        child: SafeArea(
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
                  label: item.label,
                  route: item.route,
                  selected: location == item.route,
                ),
              ),
              const Divider(),
              ..._secondaryItems.map(
                (item) => _NavItemTile(
                  icon: item.icon,
                  label: item.label,
                  route: item.route,
                  selected: location == item.route,
                ),
              ),
              if (isAdmin) const Divider(),
              if (isAdmin)
                ..._adminItems.map(
                  (item) => _NavItemTile(
                    icon: item.icon,
                    label: item.label,
                    route: item.route,
                    selected: location == item.route,
                  ),
                ),
            ],
          ),
        ),
      ),
      body: TerminalViewTransition(
        key: ValueKey(location),
        child: child,
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
  const _NavItem(this.route, this.label, this.icon);

  final String route;
  final String label;
  final IconData icon;
}

// Mismos 6 items primarios que frontend_react/frontend_vanilla (main-nav).
// Memory y Skills viven dentro de Knowledge (son pestañas, no nav propio);
// Manager no aparece en el nav web (se llega desde Profile > Workspaces).
const _mainItems = [
  _NavItem(RouteNames.dashboard, 'Dashboard', Icons.dashboard_outlined),
  _NavItem(RouteNames.explore, 'Explore', Icons.travel_explore_outlined),
  _NavItem(RouteNames.agents, 'Agents', Icons.smart_toy_outlined),
  _NavItem(RouteNames.orchestrations, 'Workflows', Icons.hub_outlined),
  _NavItem(RouteNames.knowledge, 'Knowledge', Icons.school_outlined),
  _NavItem(RouteNames.connections, 'Connections', Icons.cable_outlined),
];

// Accesos que en web viven en la fila de iconos del footer / avatar del nav,
// no en la lista principal.
const _secondaryItems = [
  _NavItem(RouteNames.labels, 'Labels', Icons.label_outline),
  _NavItem(RouteNames.profile, 'Profile', Icons.person_outline),
];

const _adminItems = [
  _NavItem(RouteNames.admin, 'Admin', Icons.admin_panel_settings_outlined),
  _NavItem(RouteNames.adminMetadata, 'Metadata', Icons.table_rows_outlined),
  _NavItem(RouteNames.adminCentinel, 'Centinel', Icons.security_outlined),
  _NavItem(RouteNames.adminLogs, 'Logs', Icons.receipt_long_outlined),
];

String _titleForLocation(String location) {
  for (final item in [..._mainItems, ..._secondaryItems, ..._adminItems]) {
    if (location == item.route) return item.label;
  }
  if (location.startsWith(RouteNames.publicProfilePrefix)) return 'Public Profile';
  return 'iAgents Hub';
}
