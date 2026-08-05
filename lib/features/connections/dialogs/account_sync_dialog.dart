part of '../widgets/providers_section.dart';

/// Diálogo genérico "¿qué te quieres traer?" — igual para los 6 proveedores.
/// Sirve tanto para Ollama (solo LLMs) como para OpenAI/Anthropic/GitHub
/// Copilot/NVIDIA/Google: la única diferencia entre proveedores la resuelve
/// el backend al listar los modelos disponibles.
class _AccountSyncDialog extends StatefulWidget {
  const _AccountSyncDialog({
    required this.models,
    required this.alreadySynced,
    required this.tx,
  });

  final List<String> models;
  final Set<String> alreadySynced;
  final String Function(String path, String fallback) tx;

  @override
  State<_AccountSyncDialog> createState() => _AccountSyncDialogState();
}

class _AccountSyncDialogState extends State<_AccountSyncDialog> {
  late Set<String> _selected;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = widget.models.toSet();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _filteredModels {
    if (_query.isEmpty) return widget.models;
    return widget.models
        .where((model) => model.toLowerCase().contains(_query))
        .toList();
  }

  /// Con búsqueda activa, "todo"/"ninguno" solo afectan a lo visible en ese
  /// momento — permite componer varias búsquedas para armar la selección.
  void _selectAll(bool value) {
    setState(() {
      if (value) {
        _selected = {..._selected, ..._filteredModels};
      } else {
        _selected = _selected.difference(_filteredModels.toSet());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.tx('providers.sync_dialog_title', '¿Qué modelos quieres traer?'),
      ),
      content: SizedBox(
        width: dialogContentWidth(context, 420),
        height: dialogContentHeight(context, 420),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.models.length > 8) ...[
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  hintText: widget.tx(
                    'providers.sync_dialog_search_hint',
                    'Buscar modelo...',
                  ),
                  suffixIcon: _query.isEmpty
                      ? null
                      : AppIconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          tooltip: widget.tx(
                            'providers.sync_dialog_clear_search',
                            'Limpiar búsqueda',
                          ),
                          onPressed: _searchController.clear,
                        ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                TertiaryButton(
                  onPressed: () => _selectAll(true),
                  child: Text(
                    widget.tx(
                      'providers.sync_dialog_select_all',
                      'Seleccionar todo',
                    ),
                  ),
                ),
                TertiaryButton(
                  onPressed: () => _selectAll(false),
                  child: Text(
                    widget.tx('providers.sync_dialog_select_none', 'Ninguno'),
                  ),
                ),
                const Spacer(),
                Text(
                  '${_selected.length}/${widget.models.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            Flexible(
              child: _filteredModels.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        widget.tx(
                          'providers.sync_dialog_no_matches',
                          'Ningún modelo coincide con la búsqueda',
                        ),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final model in _filteredModels)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _selected.contains(model),
                            title: Text(model),
                            subtitle: widget.alreadySynced.contains(model)
                                ? Text(
                                    widget.tx(
                                      'providers.sync_dialog_already_synced_hint',
                                      'Ya sincronizado',
                                    ),
                                    style: const TextStyle(fontSize: 11),
                                  )
                                : null,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selected = {..._selected, model};
                                } else {
                                  _selected = {..._selected}..remove(model);
                                }
                              });
                            },
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TertiaryButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.tx('common.cancel', 'Cancelar')),
        ),
        PrimaryButton(
          onPressed: () => Navigator.of(context).pop(_selected.toList()),
          child: Text(
            widget.tx(
              'providers.sync_dialog_confirm',
              'Sincronizar seleccionados',
            ),
          ),
        ),
      ],
    );
  }
}
