part of '../pages/profile_page.dart';

class _BrandIconSelector extends StatelessWidget {
  const _BrandIconSelector({required this.tx});

  final String Function(String path) tx;

  @override
  Widget build(BuildContext context) {
    final controller = BrandIconScope.watch(context);
    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: BrandIconVariant.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final variant = BrandIconVariant.values[index];
          return BrandIconChoice(
            variant: variant,
            label: _variantLabel(variant),
            selected: controller.selected == variant,
            onSelected: controller.select,
          );
        },
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
        width: 68,
        height: 68,
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
