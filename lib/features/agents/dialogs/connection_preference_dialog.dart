part of '../pages/chat_page.dart';

/// Permite a este usuario elegir su propia conexión/modelo para un agente,
/// sin afectar a la conexión predeterminada que ven el resto de usuarios
/// (relevante sobre todo en agentes compartidos o enlazados).
class _ConnectionPreferenceDialog extends StatefulWidget {
  const _ConnectionPreferenceDialog({
    required this.connections,
    required this.initialConnectionId,
    required this.tx,
    required this.onSave,
  });

  final List<ConnectionItem> connections;
  final String? initialConnectionId;
  final String Function(String path) tx;
  final Future<void> Function(String? connectionId) onSave;

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
    _target = widget.initialConnectionId;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.onSave(_target);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.tx;
    return AlertDialog(
      title: Text(tx('agents.preferences_title')),
      content: SizedBox(
        width: dialogContentWidth(context, 360),
        child: DropdownButtonFormField<String?>(
          initialValue: _target,
          isExpanded: true,
          decoration: InputDecoration(labelText: tx('agents.field_connection')),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(tx('agents.preferences_use_default')),
            ),
            ...widget.connections.map(
              (conn) => DropdownMenuItem<String?>(
                value: conn.id,
                child: Text(
                  '${conn.name} (${conn.type == 'llm_orchestration' ? (conn.model == 'balanced' ? tx('llm_orchestrations.balanced') : tx('llm_orchestrations.stack')) : conn.type})',
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
          child: Text(tx('common.cancel')),
        ),
        PrimaryButton(
          onPressed: _saving ? null : _save,
          child: Text(tx('common.save')),
        ),
      ],
    );
  }
}
