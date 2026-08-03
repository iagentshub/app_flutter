part of '../pages/connections_page.dart';

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

  @override
  void initState() {
    super.initState();
    _selected = widget.models.toSet();
  }

  void _selectAll(bool value) {
    setState(() => _selected = value ? widget.models.toSet() : {});
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
            Row(
              children: [
                TertiaryButton(
                  onPressed: () => _selectAll(true),
                  child: Text(
                    widget.tx('providers.sync_dialog_select_all', 'Seleccionar todo'),
                  ),
                ),
                TertiaryButton(
                  onPressed: () => _selectAll(false),
                  child: Text(
                    widget.tx('providers.sync_dialog_select_none', 'Ninguno'),
                  ),
                ),
              ],
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final model in widget.models)
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
            widget.tx('providers.sync_dialog_confirm', 'Sincronizar seleccionados'),
          ),
        ),
      ],
    );
  }
}
