part of '../app_shell.dart';

/// Versión contraída del sidebar: solo iconos, con la etiqueta en el tooltip.
///
/// Los enlaces públicos del pie no caben aquí sin un menú desplegable; se
/// recuperan al expandir.
class AppSidebarRail extends StatelessWidget {
  const AppSidebarRail({
    super.key,
    required this.isAdmin,
    required this.role,
    required this.location,
    required this.initial,
    required this.tx,
    required this.onNavigate,
    required this.onExpand,
    required this.onLogout,
  });

  final bool isAdmin;
  final String role;
  final String location;
  final String initial;
  final String Function(String key, String fallback) tx;
  final ValueChanged<String> onNavigate;
  final VoidCallback onExpand;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = _SidebarTokens.of(context);
    final expandTooltip = tx('sidebar_show', 'Mostrar menú');
    final groups = <List<_NavItem>>[
      _visibleMainItems(role),
      _secondaryItems,
      if (isAdmin) _adminItems,
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
          child: Tooltip(
            message: expandTooltip,
            child: InkWell(
              onTap: onExpand,
              borderRadius: BorderRadius.circular(10),
              child: const BrandIcon(size: 34, borderRadius: 10),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 12),
            children: [
              for (var group = 0; group < groups.length; group++) ...[
                if (group > 0) _RailDivider(color: tokens.border),
                for (final item in groups[group])
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 2,
                    ),
                    child: _RailButton(
                      icon: item.icon,
                      tooltip: tx(item.labelKey, item.labelKey),
                      selected: location == item.route,
                      onTap: () => onNavigate(item.route),
                    ),
                  ),
              ],
            ],
          ),
        ),
        _RailDivider(color: tokens.border),
        CircleAvatar(
          radius: 15,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          child: Text(
            initial,
            style: const TextStyle(
              fontSize: FncFonts.size12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Tooltip(
          message: tx('logout', 'Cerrar sesión'),
          child: IconButton(
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded, size: 20),
            color: tokens.muted,
          ),
        ),
        Tooltip(
          message: expandTooltip,
          child: IconButton(
            onPressed: onExpand,
            icon: const Icon(Icons.keyboard_double_arrow_right_rounded),
            color: tokens.muted,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = _SidebarTokens.of(context);
    return Tooltip(
      message: tooltip,
      child: Semantics(
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
              height: 44,
              decoration: BoxDecoration(
                color: selected ? tokens.selectedBg : FncColors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: selected ? scheme.primary : tokens.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RailDivider extends StatelessWidget {
  const _RailDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
    child: Container(height: 1, color: color),
  );
}
