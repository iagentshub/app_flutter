part of '../app_shell.dart';

class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter({
    required this.visibleName,
    required this.accountDetail,
    required this.initial,
    required this.languageCode,
    required this.billingEnabled,
    required this.tx,
    required this.onOpenPublicRoute,
    required this.onLogout,
  });

  final String visibleName;
  final String accountDetail;
  final String initial;
  final String languageCode;
  final bool billingEnabled;
  final String Function(String key) tx;
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
                    message: tr(item.labelKey),
                    child: IconButton(
                      onPressed: () => onOpenPublicRoute(
                        item.route(languageCode: languageCode),
                      ),
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
                message: tx('logout'),
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
    required this.ruta,
    required this.labelKey,
    required this.icon,
  });

  /// Ruta en el idioma base. Las demás se derivan.
  final String ruta;
  final String labelKey;
  final IconData icon;

  /// El sitio público sirve el idioma base en la raíz y los demás bajo su
  /// código: `/docs` y `/en/docs`.
  ///
  /// Antes había un campo por idioma —`esRoute`, `enRoute`— y un
  /// `languageCode == 'en' ? enRoute : esRoute`. Con un tercer idioma eso no
  /// falla de forma visible: manda al español y nadie se entera. Derivarla del
  /// código es lo que hace que un idioma nuevo funcione sin volver aquí a
  /// añadir un campo por cada entrada del menú.
  String route({required String languageCode}) =>
      languageCode == LocaleController.fallbackLanguageCode
      ? ruta
      : '/$languageCode$ruta';
}

const _publicItems = [
  _PublicNavItem(
    ruta: ExternalRoutes.home,
    labelKey: 'public_home',
    icon: Icons.home_outlined,
  ),
  _PublicNavItem(
    ruta: '${ExternalRoutes.pricing}/',
    labelKey: 'public_pricing',
    icon: Icons.sell_outlined,
  ),
  _PublicNavItem(
    ruta: ExternalRoutes.docs,
    labelKey: 'public_docs',
    icon: Icons.menu_book_outlined,
  ),
  _PublicNavItem(
    ruta: ExternalRoutes.support,
    labelKey: 'public_support',
    icon: Icons.support_agent_outlined,
  ),
  _PublicNavItem(
    ruta: ExternalRoutes.about,
    labelKey: 'public_about',
    icon: Icons.info_outline_rounded,
  ),
];
