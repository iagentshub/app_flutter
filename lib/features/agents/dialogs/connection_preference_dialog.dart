part of '../pages/chat_page.dart';

/// Permite a este usuario elegir su propia conexión/modelo para un agente,
/// sin afectar a la conexión predeterminada que ven el resto de usuarios
/// (relevante sobre todo en agentes compartidos o enlazados).
class _ConnectionPreferenceDialog extends StatefulWidget {
  const _ConnectionPreferenceDialog({
    required this.connections,
    required this.orchestrations,
    required this.initialConnectionId,
    required this.initialLlmOrchestrationId,
    required this.tx,
    required this.onSave,
  });

  final List<ConnectionItem> connections;
  final List<LlmOrchestrationItem> orchestrations;
  final String? initialConnectionId;
  final String? initialLlmOrchestrationId;
  final String Function(String path, String fallback) tx;
  final Future<void> Function(String? connectionId, String? llmOrchestrationId)
  onSave;

  @override
  State<_ConnectionPreferenceDialog> createState() =>
      _ConnectionPreferenceDialogState();
}

class _ConnectionPreferenceDialogState
    extends State<_ConnectionPreferenceDialog> {
  String? _target;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _target = widget.initialConnectionId != null
        ? 'connection:${widget.initialConnectionId}'
        : widget.initialLlmOrchestrationId != null
        ? 'orchestration:${widget.initialLlmOrchestrationId}'
        : null;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.onSave(
      _target?.startsWith('connection:') == true
          ? _target!.substring('connection:'.length)
          : null,
      _target?.startsWith('orchestration:') == true
          ? _target!.substring('orchestration:'.length)
          : null,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.tx;
    return AlertDialog(
      title: Text(tx('agents.preferences_title', 'Preferencia de conexión')),
      content: SizedBox(
        width: dialogContentWidth(context, 360),
        child: DropdownButtonFormField<String?>(
          initialValue: _target,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: tx('agents.field_connection', 'Conexión LLM'),
          ),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(
                tx(
                  'agents.preferences_use_default',
                  'Usar la conexión del agente',
                ),
              ),
            ),
            ...widget.connections.map(
              (conn) => DropdownMenuItem<String?>(
                value: 'connection:${conn.id}',
                child: Text(
                  '${conn.name} (${conn.type})',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            ...widget.orchestrations.map(
              (item) => DropdownMenuItem<String?>(
                value: 'orchestration:${item.id}',
                child: Text(
                  '${item.name} (${item.mode == 'balanced' ? tx('llm_orchestrations.balanced', 'Balanceo') : tx('llm_orchestrations.stack', 'Pila')})',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          onChanged: (value) => setState(() => _target = value),
        ),
      ),
      actions: [
        TertiaryButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(tx('common.cancel', 'Cancelar')),
        ),
        PrimaryButton(
          onPressed: _saving ? null : _save,
          child: Text(tx('common.save', 'Guardar')),
        ),
      ],
    );
  }
}
