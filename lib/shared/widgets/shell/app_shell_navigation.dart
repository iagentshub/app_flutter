part of '../app_shell.dart';

/// Nombre a mostrar en el pie y en el rail: el `displayName` si lo hay, si no
/// el usuario. Compartido para que ambas variantes muestren lo mismo.
String sidebarVisibleName(String username, String? displayName) =>
    displayName?.trim().isNotEmpty == true ? displayName!.trim() : username;

/// Inicial del avatar, derivada de [sidebarVisibleName].
String sidebarAvatarInitial(String visibleName) => visibleName.trim().isEmpty
    ? 'U'
    : visibleName.trimLeft().substring(0, 1).toUpperCase();

/// Navegación principal compartida por el sidebar de escritorio y el drawer.
class AppSidebarNavigation extends StatelessWidget {
  const AppSidebarNavigation({
    required this.isAdmin,
    required this.location,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.apiClient,
    required this.gaToken,
    required this.email,
    required this.role,
    required this.languageCode,
    required this.billingEnabled,
    required this.tx,
    required this.showCloseButton,
    this.onCollapse,
    required this.onNavigate,
    required this.onOpenPublicRoute,
    required this.onLogout,
    super.key,
  });

  final bool isAdmin;
  final String location;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final ApiClient apiClient;
  final String? gaToken;
  final String? email;
  final String role;
  final String languageCode;
  final bool billingEnabled;
  final String Function(String key) tx;
  final bool showCloseButton;
  final VoidCallback? onCollapse;
  final ValueChanged<String> onNavigate;
  final ValueChanged<String> onOpenPublicRoute;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final visibleName = sidebarVisibleName(username, displayName);
    final accountDetail = email?.trim().isNotEmpty == true
        ? email!.trim()
        : role == 'admin'
        ? tx('role_admin')
        : tx('role_user');
    final initial = sidebarAvatarInitial(visibleName);

    return Column(
      children: [
        _SidebarBrand(
          showCloseButton: showCloseButton,
          onCollapse: onCollapse,
          collapseTooltip: tx('sidebar_hide'),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
            children: [
              _NavigationSection(
                label: tx('workspace'),
                // Sin filtrar por rol: aquí se ocultaba workflows al
                // invitado, porque su sesión vivía en memoria del backend y
                // cualquier llamada respondía 403. Hoy el invitado es un
                // usuario efímero y esa sección es suya como el resto.
                items: _mainItems,
                location: location,
                tx: tx,
                onNavigate: onNavigate,
              ),
              const SizedBox(height: 24),
              _NavigationSection(
                label: tx('organization'),
                items: _secondaryItems,
                location: location,
                tx: tx,
                onNavigate: onNavigate,
              ),
              if (isAdmin) ...[
                const SizedBox(height: 24),
                _NavigationSection(
                  label: tx('administration'),
                  items: _adminItems,
                  location: location,
                  tx: tx,
                  onNavigate: onNavigate,
                ),
              ],
            ],
          ),
        ),
        _SidebarFooter(
          visibleName: visibleName,
          accountDetail: accountDetail,
          initial: initial,
          username: username,
          avatarUrl: avatarUrl,
          apiClient: apiClient,
          gaToken: gaToken,
          languageCode: languageCode,
          billingEnabled: billingEnabled,
          tx: tx,
          onOpenPublicRoute: onOpenPublicRoute,
          onLogout: onLogout,
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
    final tokens = _SidebarTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
      child: Row(
        children: [
          const BrandIcon(size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'iAgents Hub',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (showCloseButton)
            IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close_rounded),
              color: tokens.muted,
            ),
          if (!showCloseButton && onCollapse != null)
            IconButton(
              tooltip: collapseTooltip,
              onPressed: onCollapse,
              icon: const Icon(Icons.keyboard_double_arrow_left_rounded),
              color: tokens.muted,
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
  final String Function(String key) tx;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = _SidebarTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          child: Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: tokens.muted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: _NavItemTile(
              icon: item.icon,
              label: trOr(item.labelKey, item.labelKey),
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
  const _ShellTopBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = _SidebarTokens.of(context);
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
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
              fontSize: FncFonts.size19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

/// Aviso persistente cuando el backend seleccionado deja de responder.
class _ConnectionIssueBanner extends StatelessWidget {
  const _ConnectionIssueBanner({required this.apiClient, required this.tx});

  final ApiClient apiClient;
  final String Function(String key) tx;

  @override
  Widget build(BuildContext context) {
    final backendController = apiClient.backendController;
    final error = backendController.lastConnectionError;
    if (error == null) return const SizedBox.shrink();

    return Material(
      color: FncColors.materialRed.shade700,
      child: InkWell(
        onTap: () => AppRouter.toBackendConfig(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.wifi_off, color: FncColors.white, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tx('backend_connection_issue')
                      .replaceAll(
                        '{backend}',
                        backendController.selectedOption.label,
                      )
                      .replaceAll('{error}', error),
                  style: const TextStyle(
                    color: FncColors.white,
                    fontSize: FncFonts.size12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                tx('backend_connection_action'),
                style: const TextStyle(
                  color: FncColors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: FncFonts.size12,
                ),
              ),
              const Icon(Icons.chevron_right, color: FncColors.white, size: 16),
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
    final tokens = _SidebarTokens.of(context);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: FncColors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          hoverColor: tokens.hover,
          focusColor: tokens.hover,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? tokens.selectedBg : FncColors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: selected ? scheme.primary : tokens.muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: selected ? scheme.primary : scheme.onSurface,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
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

/// Workflows queda cerrado al invitado en el backend (`require_auth`, sin
/// rama `is_guest`): se oculta aquí para no llevarlo a un 403.
const _mainItems = [
  _NavItem(InternalRoutes.dashboard, 'dashboard', Icons.dashboard_outlined),
  _NavItem(InternalRoutes.explore, 'explore', Icons.travel_explore_outlined),
  _NavItem(InternalRoutes.agents, 'agents', Icons.smart_toy_outlined),
  _NavItem(InternalRoutes.orchestrations, 'workflows', Icons.hub_outlined),
  _NavItem(InternalRoutes.knowledge, 'knowledge', Icons.school_outlined),
  _NavItem(InternalRoutes.connections, 'connections', Icons.cable_outlined),
];

const _secondaryItems = [
  _NavItem(InternalRoutes.labels, 'labels', Icons.label_outline),
  _NavItem(InternalRoutes.profile, 'profile', Icons.person_outline),
];

const _adminItems = [
  _NavItem(InternalRoutes.admin, 'admin', Icons.admin_panel_settings_outlined),
  _NavItem(
    InternalRoutes.adminMetadata,
    'admin_metadata',
    Icons.table_rows_outlined,
  ),
  _NavItem(
    InternalRoutes.adminCentinel,
    'admin_centinel',
    Icons.security_outlined,
  ),
];

String _titleForLocation(String location, String Function(String key) tx) {
  for (final item in [..._mainItems, ..._secondaryItems, ..._adminItems]) {
    if (location == item.route) return trOr(item.labelKey, item.labelKey);
  }
  if (location.startsWith(InternalRoutes.publicProfilePrefix)) {
    return tx('public_profile');
  }
  return tx('app_title');
}
