part of '../pages/profile_page.dart';

class _BrandIconSelector extends StatefulWidget {
  const _BrandIconSelector({required this.tx});

  final String Function(String path) tx;

  @override
  State<_BrandIconSelector> createState() => _BrandIconSelectorState();
}

class _BrandIconSelectorState extends State<_BrandIconSelector> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = BrandIconScope.watch(context);
    // La barra es lo único que dice, en escritorio, que hay más iconos a la
    // derecha: en un móvil se descubren deslizando, pero con ratón la tira
    // parecía terminar donde termina la ventana. El arrastre en sí lo habilita
    // `AppScrollBehavior`.
    return SizedBox(
      height: BrandIconChoice.alturaTira,
      child: Scrollbar(
        controller: _scroll,
        thumbVisibility: true,
        child: ListView.separated(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          // La barra se pinta sobre el borde inferior del viewport, así que el
          // carril tiene que ser hueco: sin este espacio queda cruzada por
          // encima de los iconos.
          padding: const EdgeInsets.only(bottom: BrandIconChoice.carrilBarra),
          itemCount: BrandIconVariant.values.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final variant = BrandIconVariant.values[index];
            // Un ListView horizontal impone su altura al hijo, y estirarlo se
            // comía el hueco de la barra. `Align` afloja esa restricción y deja
            // el icono en su tamaño, arriba.
            return Align(
              alignment: Alignment.topCenter,
              child: BrandIconChoice(
                variant: variant,
                label: _variantLabel(variant),
                selected: controller.selected == variant,
                onSelected: controller.select,
              ),
            );
          },
        ),
      ),
    );
  }

  String _variantLabel(BrandIconVariant variant) {
    final fallback = switch (variant) {
      BrandIconVariant.agentCoordinator => 'Agente coordinador',
      BrandIconVariant.coordinatorWhiteOnRed => 'Coordinador blanco sobre rojo',
      BrandIconVariant.coordinatorRedOnBlack => 'Coordinador rojo sobre negro',
      BrandIconVariant.coordinatorBlackOnRed => 'Coordinador negro sobre rojo',
      BrandIconVariant.coordinatorRedOnWhite => 'Coordinador rojo sobre blanco',
      BrandIconVariant.iaInterWhiteOnRed => 'iA Inter blanca sobre rojo',
      BrandIconVariant.iaInterRedOnBlack => 'iA Inter roja sobre negro',
      BrandIconVariant.iaInterBlackOnRed => 'iA Inter negra sobre rojo',
      BrandIconVariant.iaInterRedOnWhite => 'iA Inter roja sobre blanco',
    };
    return trOr('profile.app_icon_${variant.name}', fallback);
  }
}

class BrandIconChoice extends StatelessWidget {
  const BrandIconChoice({
    required this.variant,
    required this.label,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  /// Lado del cuadrado, en px.
  static const lado = 68.0;

  /// Hueco bajo los iconos para la barra de desplazamiento, que se pinta sobre
  /// el borde inferior del viewport. Sin él la barra queda cruzada por encima.
  static const carrilBarra = 16.0;

  /// Alto de la tira, la suma exacta de los dos anteriores.
  ///
  /// Un `ListView` horizontal impone su altura al hijo: con 90 y un carril de
  /// 12 el icono se estiraba a 78 —medido— y la barra le quedaba cruzada por
  /// encima. Lo que lo sostiene es el `Align` del `itemBuilder`, que afloja esa
  /// restricción; que la suma cuadre es la segunda red, por si el `Align`
  /// desaparece en una refactorización.
  static const alturaTira = lado + carrilBarra;

  final BrandIconVariant variant;
  final String label;
  final bool selected;
  final ValueChanged<BrandIconVariant> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      excludeSemantics: true,
      onTap: () => onSelected(variant),
      child: SizedBox(
        width: lado,
        height: lado,
        child: Material(
          color: selected
              ? colorScheme.primaryContainer.withValues(alpha: 0.35)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            excludeFromSemantics: true,
            onTap: () => onSelected(variant),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12.32),
                      child: Image.asset(variant.assetPath, fit: BoxFit.cover),
                    ),
                  ),
                  if (selected)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_circle,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
