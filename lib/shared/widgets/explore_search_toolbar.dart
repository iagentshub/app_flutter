import 'package:flutter/material.dart';

/// Opción visual del selector de tipos usado por los exploradores público y
/// administrativo. [count] es opcional porque no todos los endpoints devuelven
/// agregados globales.
class ExploreTypeOption {
  const ExploreTypeOption({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    this.count,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final int? count;
}

/// Barra canónica de Explorar: búsqueda descriptiva, selector de tipos y
/// acciones secundarias. En pantallas estrechas apila el selector para que el
/// campo de búsqueda conserve un ancho útil.
class ExploreSearchToolbar extends StatelessWidget {
  const ExploreSearchToolbar({
    required this.searchController,
    required this.searchHint,
    required this.typeOptions,
    required this.selectedTypes,
    required this.allTypesLabel,
    required this.typeFilterTooltip,
    required this.multipleTypesLabel,
    required this.onTypesChanged,
    this.onSearchChanged,
    this.onSearchSubmitted,
    this.actions = const [],
    this.allowMultipleTypes = true,
    this.selectorKey,
    super.key,
  });

  final TextEditingController searchController;
  final String searchHint;
  final List<ExploreTypeOption> typeOptions;
  final Set<String> selectedTypes;
  final String allTypesLabel;
  final String typeFilterTooltip;
  final String Function(int count) multipleTypesLabel;
  final ValueChanged<Set<String>> onTypesChanged;
  final ValueChanged<String>? onSearchChanged;
  final ValueChanged<String>? onSearchSubmitted;
  final List<Widget> actions;
  final bool allowMultipleTypes;
  final Key? selectorKey;

  int? get _totalCount {
    if (typeOptions.any((option) => option.count == null)) return null;
    return typeOptions.fold<int>(0, (sum, option) => sum + option.count!);
  }

  String get _selectionLabel {
    if (selectedTypes.isEmpty) return _withCount(allTypesLabel, _totalCount);
    if (selectedTypes.length > 1) {
      return multipleTypesLabel(selectedTypes.length);
    }
    final selected = typeOptions
        .where((option) => selectedTypes.contains(option.value))
        .firstOrNull;
    return selected?.label ?? allTypesLabel;
  }

  String _withCount(String label, int? count) =>
      count == null ? label : '$label ($count)';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 620;
            final search = TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: searchHint,
                prefixIcon: const Icon(Icons.search, size: 20),
              ),
              onChanged: onSearchChanged,
              onSubmitted: onSearchSubmitted,
            );
            final selector = _TypeSelector(
              key: selectorKey,
              options: typeOptions,
              selectedTypes: selectedTypes,
              label: _selectionLabel,
              allTypesLabel: _withCount(allTypesLabel, _totalCount),
              tooltip: typeFilterTooltip,
              allowMultiple: allowMultipleTypes,
              onChanged: onTypesChanged,
              expand: compact,
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [search, const SizedBox(height: 8), selector],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: search),
                const SizedBox(width: 8),
                selector,
              ],
            );
          },
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: actions,
          ),
        ],
      ],
    );
  }
}

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({
    required this.options,
    required this.selectedTypes,
    required this.label,
    required this.allTypesLabel,
    required this.tooltip,
    required this.allowMultiple,
    required this.onChanged,
    required this.expand,
    super.key,
  });

  final List<ExploreTypeOption> options;
  final Set<String> selectedTypes;
  final String label;
  final String allTypesLabel;
  final String tooltip;
  final bool allowMultiple;
  final ValueChanged<Set<String>> onChanged;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: expand ? double.infinity : 220,
      child: PopupMenuButton<void>(
        tooltip: tooltip,
        position: PopupMenuPosition.under,
        itemBuilder: (context) {
          final menuSelection = Set<String>.of(selectedTypes);
          return [
            PopupMenuItem<void>(
              enabled: false,
              padding: EdgeInsets.zero,
              child: StatefulBuilder(
                builder: (context, setMenuState) => SizedBox(
                  width: 260,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CheckboxListTile(
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: menuSelection.isEmpty,
                        title: Text(allTypesLabel),
                        onChanged: (_) {
                          setMenuState(menuSelection.clear);
                          onChanged(Set<String>.of(menuSelection));
                        },
                      ),
                      const Divider(height: 1),
                      for (final option in options)
                        CheckboxListTile(
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: menuSelection.contains(option.value),
                          secondary: Icon(
                            option.icon,
                            size: 18,
                            color: option.color,
                          ),
                          title: Text(_optionLabel(option)),
                          onChanged: (checked) {
                            setMenuState(() {
                              if (!allowMultiple) menuSelection.clear();
                              if (checked == true) {
                                menuSelection.add(option.value);
                              } else {
                                menuSelection.remove(option.value);
                              }
                            });
                            onChanged(Set<String>.of(menuSelection));
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        child: InputDecorator(
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  String _optionLabel(ExploreTypeOption option) =>
      option.count == null ? option.label : '${option.label} (${option.count})';
}
