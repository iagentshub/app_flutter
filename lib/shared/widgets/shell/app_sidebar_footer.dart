part of '../app_shell.dart';

class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter({
    required this.visibleName,
    required this.accountDetail,
    required this.initial,
    required this.isEnglish,
    required this.tx,
    required this.onOpenPublicRoute,
    required this.onLogout,
  });

  final String visibleName;
  final String accountDetail;
  final String initial;
  final bool isEnglish;
  final String Function(String key, String fallback) tx;
  final ValueChanged<String> onOpenPublicRoute;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Column(
        children: [
          const Divider(height: 1),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final item in _publicItems)
                Tooltip(
                  message: tx(item.labelKey, item.fallback),
                  child: IconButton(
                    onPressed: () =>
                        onOpenPublicRoute(item.route(isEnglish: isEnglish)),
                    constraints: const BoxConstraints.tightFor(
                      width: 40,
                      height: 40,
                    ),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(item.icon, size: 19),
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Tooltip(
                  message: accountDetail,
                  child: Semantics(
                    label: '$visibleName, $accountDetail',
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: scheme.primary,
                          foregroundColor: scheme.onPrimary,
                          child: Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            visibleName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Tooltip(
                message: tx('logout', 'Cerrar sesión'),
                child: IconButton(
                  onPressed: onLogout,
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PublicNavItem {
  const _PublicNavItem({
    required this.esRoute,
    required this.enRoute,
    required this.labelKey,
    required this.fallback,
    required this.icon,
  });

  final String esRoute;
  final String enRoute;
  final String labelKey;
  final String fallback;
  final IconData icon;

  String route({required bool isEnglish}) => isEnglish ? enRoute : esRoute;
}

const _publicItems = [
  _PublicNavItem(
    esRoute: RouteNames.home,
    enRoute: '${RouteNames.homeEn}/',
    labelKey: 'public_home',
    fallback: 'Inicio',
    icon: Icons.home_outlined,
  ),
  _PublicNavItem(
    esRoute: '${RouteNames.pricing}/',
    enRoute: '${RouteNames.pricingEn}/',
    labelKey: 'public_pricing',
    fallback: 'Precios',
    icon: Icons.sell_outlined,
  ),
  _PublicNavItem(
    esRoute: RouteNames.docs,
    enRoute: RouteNames.docsEn,
    labelKey: 'public_docs',
    fallback: 'Documentación',
    icon: Icons.menu_book_outlined,
  ),
  _PublicNavItem(
    esRoute: RouteNames.support,
    enRoute: RouteNames.supportEn,
    labelKey: 'public_support',
    fallback: 'Soporte',
    icon: Icons.support_agent_outlined,
  ),
  _PublicNavItem(
    esRoute: RouteNames.about,
    enRoute: RouteNames.aboutEn,
    labelKey: 'public_about',
    fallback: 'Acerca de',
    icon: Icons.info_outline_rounded,
  ),
];
