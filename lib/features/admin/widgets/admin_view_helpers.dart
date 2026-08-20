part of '../pages/admin_page.dart';

extension _AdminViewHelpers on _AdminPageState {
  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: FncFonts.size11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  /// Chips de las labels reales del recurso (visibilidad, origen, idioma,
  /// estado…) con el color canónico del catálogo, para que el explorar de
  /// admin muestre el mismo origen —`official` incluido— que Explorar.
  List<Widget> _labelBadges(Map<String, dynamic> item) {
    final raw = item['labels'];
    if (raw is! List) return const [];
    return [
      for (final value in raw)
        if (value.toString().isNotEmpty)
          _badge(
            trOr('labels.${value.toString()}', value.toString()),
            labelColor(value.toString()),
          ),
    ];
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<(String, String)> options,
    required ValueChanged<String> onChanged,
    double width = 170,
  }) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        isExpanded: true,
        items: options
            .map(
              (opt) => DropdownMenuItem(
                value: opt.$1,
                child: Text(opt.$2, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: (next) {
          if (next == null) return;
          onChanged(next);
        },
      ),
    );
  }

  /// Diálogo de filtros compartido por las pestañas Agentes/Conexiones/
  /// Orquestaciones, que solo filtran por propietario.
  void _openOwnerFilterDialog({
    required List<String> owners,
    required String currentOwner,
    required ValueChanged<String> onChanged,
  }) {
    showFilterDialog(
      context,
      title: _tx('common.filters'),
      clearLabel: _tx('common.clear_filters'),
      closeLabel: _tx('common.close'),
      onClear: () => onChanged(''),
      buildFields: (setDialogState) => [
        _dropdown(
          label: _tx('admin.table_owner'),
          value: currentOwner,
          width: 360,
          options: [
            ('', _tx('admin.all_owners')),
            ...owners.map((o) => (o, o)),
          ],
          onChanged: (v) {
            onChanged(v);
            setDialogState(() {});
          },
        ),
      ],
    );
  }

  void _openKnowledgeFiltersDialog() {
    showFilterDialog(
      context,
      title: _tx('common.filters'),
      clearLabel: _tx('common.clear_filters'),
      closeLabel: _tx('common.close'),
      onClear: () => refresh(() {
        _knowledgeType = '';
        _knowledgeOwner = '';
      }),
      buildFields: (setDialogState) => [
        _dropdown(
          label: _tx('admin.filter_type'),
          value: _knowledgeType,
          width: 360,
          options: [
            ('', _tx('admin.all_types')),
            ('url', 'URL'),
            ('document', _tx('admin.type_document')),
          ],
          onChanged: (v) {
            refresh(() => _knowledgeType = v);
            setDialogState(() {});
          },
        ),
        const SizedBox(height: 12),
        _dropdown(
          label: _tx('admin.table_owner'),
          value: _knowledgeOwner,
          width: 360,
          options: [
            ('', _tx('admin.all_owners')),
            ..._ownersOf(_knowledge).map((o) => (o, o)),
          ],
          onChanged: (v) {
            refresh(() => _knowledgeOwner = v);
            setDialogState(() {});
          },
        ),
      ],
    );
  }

  Widget _emptyCard(String text) => Card(
    child: Padding(padding: const EdgeInsets.all(16), child: Text(text)),
  );
}
