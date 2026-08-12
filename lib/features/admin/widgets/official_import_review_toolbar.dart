import 'package:flutter/material.dart';

import '../../../shared/widgets/buttons/app_buttons.dart';
import '../models/official_import_models.dart';
import 'official_import_message_box.dart';

class OfficialImportReviewToolbar extends StatelessWidget {
  const OfficialImportReviewToolbar({
    required this.draft,
    required this.searchController,
    required this.selectedType,
    required this.selectedState,
    required this.showOmitted,
    required this.showLogs,
    required this.busy,
    required this.availableWidth,
    required this.mobile,
    required this.tx,
    required this.onSearchChanged,
    required this.onTypeChanged,
    required this.onStateChanged,
    required this.onShowOmittedChanged,
    required this.onShowLogsChanged,
    required this.onSelectVisible,
    required this.onDeselectVisible,
    required this.onShowGraph,
    this.error,
    super.key,
  });

  final ImportDraft draft;
  final TextEditingController searchController;
  final String selectedType;
  final String selectedState;
  final bool showOmitted;
  final bool showLogs;
  final bool busy;
  final double availableWidth;
  final bool mobile;
  final String? error;
  final String Function(String path, String fallback) tx;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onTypeChanged;
  final ValueChanged<String?> onStateChanged;
  final ValueChanged<bool> onShowOmittedChanged;
  final ValueChanged<bool> onShowLogsChanged;
  final VoidCallback onSelectVisible;
  final VoidCallback onDeselectVisible;
  final VoidCallback onShowGraph;

  static const _types = [
    'all',
    'agent',
    'skill',
    'prompt',
    'knowledge',
    'memory',
    'tool',
    'workflow',
    'unknown',
  ];

  static const _states = [
    'all',
    'new',
    'updated',
    'removed',
    'unchanged',
    'duplicate',
    'unrecognized',
  ];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        draft.source.repositoryUrl,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 8),
      if (draft.errors.isNotEmpty)
        OfficialImportMessageBox(
          messages: draft.errors,
          color: Theme.of(context).colorScheme.error,
        ),
      if (showLogs && draft.warnings.isNotEmpty)
        OfficialImportMessageBox(
          messages: draft.warnings,
          color: Theme.of(context).colorScheme.tertiary,
        ),
      if (showLogs && draft.logs.isNotEmpty)
        OfficialImportMessageBox(
          messages: draft.logs,
          color: Theme.of(context).colorScheme.outline,
        ),
      if (error != null)
        OfficialImportMessageBox(
          messages: [error!],
          color: Theme.of(context).colorScheme.error,
        ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          SizedBox(
            width: mobile ? availableWidth : 320,
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                labelText: tx('common.search', 'Buscar'),
              ),
            ),
          ),
          _ReviewFilter(
            width: mobile ? availableWidth : 180,
            value: selectedType,
            label: tx('common.type', 'Tipo'),
            values: _types,
            onChanged: onTypeChanged,
          ),
          FilterChip(
            selected: showOmitted,
            label: Text(tx('official.show_omitted', 'Mostrar omitidos')),
            onSelected: busy ? null : onShowOmittedChanged,
          ),
          if (draft.warnings.isNotEmpty || draft.logs.isNotEmpty)
            FilterChip(
              selected: showLogs,
              avatar: const Icon(Icons.receipt_long_outlined, size: 18),
              label: Text(
                '${tx('official.log', 'Log')} '
                '(${draft.warnings.length + draft.logs.length})',
              ),
              onSelected: onShowLogsChanged,
            ),
          _ReviewFilter(
            width: mobile ? availableWidth : 180,
            value: selectedState,
            label: tx('common.status', 'Estado'),
            values: _states,
            onChanged: onStateChanged,
          ),
          TertiaryButton.icon(
            onPressed: busy ? null : onSelectVisible,
            icon: const Icon(Icons.select_all),
            label: Text(tx('official.select_visible', 'Seleccionar visibles')),
          ),
          TertiaryButton.icon(
            onPressed: busy ? null : onDeselectVisible,
            icon: const Icon(Icons.deselect),
            label: Text(tx('official.deselect_visible', 'Desmarcar visibles')),
          ),
          TertiaryButton.icon(
            onPressed: busy ? null : onShowGraph,
            icon: const Icon(Icons.account_tree_outlined),
            label: Text(tx('official.preview_graph', 'Grafo previo')),
          ),
        ],
      ),
    ],
  );
}

class _ReviewFilter extends StatelessWidget {
  const _ReviewFilter({
    required this.width,
    required this.value,
    required this.label,
    required this.values,
    required this.onChanged,
  });

  final double width;
  final String value;
  final String label;
  final List<String> values;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final item in values)
          DropdownMenuItem(value: item, child: Text(item)),
      ],
      onChanged: onChanged,
    ),
  );
}
