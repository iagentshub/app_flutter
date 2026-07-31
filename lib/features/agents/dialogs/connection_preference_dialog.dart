part of '../pages/chat_page.dart';

class _ConnectionPreferenceDialog extends StatefulWidget {
  const _ConnectionPreferenceDialog({
    required this.connections,
    required this.initialConnectionId,
    required this.tx,
    required this.onSave,
  });

  final List<ConnectionItem> connections;
  final String? initialConnectionId;
  final String Function(String path, String fallback) tx;
  final Future<void> Function(String? connectionId) onSave;

  @override
  State<_ConnectionPreferenceDialog> createState() =>
      _ConnectionPreferenceDialogState();
}

class _ConnectionPreferenceDialogState
    extends State<_ConnectionPreferenceDialog> {
  String? _connectionId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _connectionId = widget.initialConnectionId;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.onSave(_connectionId);
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
          initialValue: _connectionId,
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
                value: conn.id,
                child: Text(
                  '${conn.name} (${conn.type})',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          onChanged: (value) => setState(() => _connectionId = value),
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
