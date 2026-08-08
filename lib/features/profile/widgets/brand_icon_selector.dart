part of '../pages/profile_page.dart';

class _BrandIconSelector extends StatelessWidget {
  const _BrandIconSelector();

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
          return _BrandIconChoice(
            variant: variant,
            selected: controller.selected == variant,
            onSelected: controller.select,
          );
        },
      ),
    );
  }
}

class _BrandIconChoice extends StatelessWidget {
  const _BrandIconChoice({
    required this.variant,
    required this.selected,
    required this.onSelected,
  });

  final BrandIconVariant variant;
  final bool selected;
  final ValueChanged<BrandIconVariant> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 68,
      height: 68,
      child: Material(
        color: selected
            ? colorScheme.primaryContainer.withValues(alpha: 0.35)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
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
    );
  }
}
