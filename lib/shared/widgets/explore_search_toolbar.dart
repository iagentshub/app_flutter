import 'package:flutter/material.dart';

import 'multi_select_dropdown.dart';

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
            final selector = MultiSelectDropdown<String>(
              key: selectorKey,
              options: [
                for (final option in typeOptions)
                  MultiSelectDropdownOption(
                    value: option.value,
                    label: option.label,
                    icon: option.icon,
                    color: option.color,
                    count: option.count,
                  ),
              ],
              selectedValues: selectedTypes,
              emptyLabel: _withCount(allTypesLabel, _totalCount),
              tooltip: typeFilterTooltip,
              multipleSelectedLabel: multipleTypesLabel,
              selectionReducer: (current, value, selected) {
                final next = Set<String>.of(current);
                if (!allowMultipleTypes) next.clear();
                if (selected) {
                  next.add(value);
                } else {
                  next.remove(value);
                }
                return next;
              },
              onChanged: onTypesChanged,
              width: compact ? double.infinity : 220,
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
