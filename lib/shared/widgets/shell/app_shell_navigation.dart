part of '../app_shell.dart';

/// Navegación principal compartida por el sidebar de escritorio y el drawer.
class AppSidebarNavigation extends StatelessWidget {
  const AppSidebarNavigation({
    required this.isAdmin,
    required this.location,
    required this.username,
    required this.displayName,
    required this.email,
    required this.role,
    required this.tx,
    required this.showCloseButton,
    this.onCollapse,
    required this.onNavigate,
    required this.onLogout,
    super.key,
  });

  final bool isAdmin;
  final String location;
  final String username;
  final String? displayName;
  final String? email;
  final String role;
  final String Function(String key, String fallback) tx;
  final bool showCloseButton;
  final VoidCallback? onCollapse;
  final ValueChanged<String> onNavigate;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final visibleName = displayName?.trim().isNotEmpty == true
        ? displayName!.trim()
        : username;
    final accountDetail = email?.trim().isNotEmpty == true
        ? email!.trim()
        : role == 'admin'
        ? tx('role_admin', 'Administrador')
        : tx('role_user', 'Usuario');
    final initial = visibleName.trim().isEmpty
        ? 'U'
        : visibleName.trimLeft().substring(0, 1).toUpperCase();

    return Column(
      children: [
        _SidebarBrand(
          showCloseButton: showCloseButton,
          onCollapse: onCollapse,
          collapseTooltip: tx('sidebar_hide', 'Ocultar menú'),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            children: [
              _NavigationSection(
                label: tx('workspace', 'Espacio de trabajo'),
                items: _mainItems,
                location: location,
                tx: tx,
                onNavigate: onNavigate,
              ),
              const SizedBox(height: 18),
              _NavigationSection(
                label: tx('organization', 'Organización'),
                items: _secondaryItems,
                location: location,
                tx: tx,
                onNavigate: onNavigate,
              ),
              if (isAdmin) ...[
                const SizedBox(height: 18),
                _NavigationSection(
                  label: tx('administration', 'Administración'),
                  items: _adminItems,
                  location: location,
                  tx: tx,
                  onNavigate: onNavigate,
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    child: Text(
                      initial,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          visibleName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          accountDetail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tooltip(
                    message: tx('logout', 'Cerrar sesión'),
                    child: IconButton(
                      onPressed: onLogout,
                      icon: const Icon(Icons.logout_rounded, size: 20),
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SidebarBrand extends StatelessWidget {
  const _SidebarBrand({
    required this.showCloseButton,
    required this.onCollapse,
    required this.collapseTooltip,
  });

  final bool showCloseButton;
  final VoidCallback? onCollapse;
  final String collapseTooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(11),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.22),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Text(
              'iA',
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onPrimary,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'iAgentsHub',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'AI workspace',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          if (showCloseButton)
            IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close_rounded),
              color: scheme.onSurfaceVariant,
            ),
          if (!showCloseButton && onCollapse != null)
            IconButton(
              tooltip: collapseTooltip,
              onPressed: onCollapse,
              icon: const Icon(Icons.keyboard_double_arrow_left_rounded),
              color: scheme.onSurfaceVariant,
            ),
        ],
      ),
    );
  }
}

class _NavigationSection extends StatelessWidget {
  const _NavigationSection({
    required this.label,
    required this.items,
    required this.location,
    required this.tx,
    required this.onNavigate,
  });

  final String label;
  final List<_NavItem> items;
  final String location;
  final String Function(String key, String fallback) tx;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 7),
          child: Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
        ),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: _NavItemTile(
              icon: item.icon,
              label: tx(item.labelKey, item.labelKey),
              selected: location == item.route,
              onTap: () => onNavigate(item.route),
            ),
          ),
        ),
      ],
    );
  }
}

class _ShellTopBar extends StatelessWidget {
  const _ShellTopBar({
    required this.title,
    required this.openMenuTooltip,
    this.onOpenMenu,
  });

  final String title;
  final String openMenuTooltip;
  final VoidCallback? onOpenMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          if (onOpenMenu != null) ...[
            IconButton(
              tooltip: openMenuTooltip,
              onPressed: onOpenMenu,
              icon: const Icon(Icons.keyboard_double_arrow_right_rounded),
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
          ],
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Aviso persistente cuando el backend seleccionado deja de responder.
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
                        'No se pudo conectar con {backend}: {error}',
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

/// Aviso informativo de mantenimiento programado — no bloquea la app, solo
/// avisa. Descartable por sesión (ver _AppShellState._maintenanceDismissedKey);
/// vuelve a aparecer si el admin cambia el mensaje o la fecha.
class _MaintenanceBanner extends StatelessWidget {
  const _MaintenanceBanner({
    required this.message,
    required this.at,
    required this.onDismiss,
  });

  final String message;
  final DateTime? at;
  final VoidCallback onDismiss;

  String _fmtAt(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final text = at == null ? message : '$message (${_fmtAt(at!)})';
    return Material(
      color: Colors.amber.shade800,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.build_outlined, color: Colors.white, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: onDismiss,
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItemTile extends StatelessWidget {
  const _NavItemTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = selected ? scheme.primary : scheme.onSurfaceVariant;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            constraints: const BoxConstraints(minHeight: 46),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.10)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? scheme.primary.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 20, color: foreground),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: selected ? scheme.primary : scheme.onSurface,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 160),
                  opacity: selected ? 1 : 0,
                  child: Container(
                    width: 3,
                    height: 18,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.route, this.labelKey, this.icon);

  final String route;
  final String labelKey;
  final IconData icon;
}

const _mainItems = [
  _NavItem(RouteNames.dashboard, 'dashboard', Icons.dashboard_outlined),
  _NavItem(RouteNames.explore, 'explore', Icons.travel_explore_outlined),
  _NavItem(RouteNames.agents, 'agents', Icons.smart_toy_outlined),
  _NavItem(RouteNames.orchestrations, 'workflows', Icons.hub_outlined),
  _NavItem(RouteNames.knowledge, 'knowledge', Icons.school_outlined),
  _NavItem(RouteNames.connections, 'connections', Icons.cable_outlined),
];

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
