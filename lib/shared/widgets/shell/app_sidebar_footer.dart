part of '../app_shell.dart';

class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter({
    required this.visibleName,
    required this.accountDetail,
    required this.initial,
    required this.isEnglish,
    required this.billingEnabled,
    required this.tx,
    required this.onOpenPublicRoute,
    required this.onLogout,
  });

  final String visibleName;
  final String accountDetail;
  final String initial;
  final bool isEnglish;
  final bool billingEnabled;
  final String Function(String key, String fallback) tx;
  final ValueChanged<String> onOpenPublicRoute;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = _SidebarTokens.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Column(
        children: [
          Container(height: 1, color: tokens.border),
          const SizedBox(height: 8),
          // Centrados y con hueco fijo: repartirlos con `spaceBetween` los
          // lanzaba contra los bordes, y el hueco cambiaba al ocultar Precios.
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            children: [
              // El link de Precios solo tiene sentido si hay planes de
              // suscripción activos — se oculta cuando el admin desactiva
              // "Activar planes de suscripción" (billing_enabled).
              for (final item in _publicItems)
                if (item.labelKey != 'public_pricing' || billingEnabled)
                  Tooltip(
                    message: tx(item.labelKey, item.fallback),
                    child: IconButton(
                      onPressed: () =>
                          onOpenPublicRoute(item.route(isEnglish: isEnglish)),
                      constraints: const BoxConstraints.tightFor(
                        width: 38,
                        height: 38,
                      ),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(item.icon, size: 18),
                      color: tokens.muted,
                    ),
                  ),
            ],
          ),
          const SizedBox(height: 6),
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
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            visibleName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
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
                    width: 38,
                    height: 38,
                  ),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.logout_rounded, size: 19),
                  color: tokens.muted,
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
