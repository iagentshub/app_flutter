part of '../pages/admin_page.dart';

class _AgentEditDialog extends StatefulWidget {
  const _AgentEditDialog({required this.agent, required this.tx});

  final Map<String, dynamic> agent;
  final String Function(String path, String fallback) tx;

  @override
  State<_AgentEditDialog> createState() => _AgentEditDialogState();
}

class _AgentEditDialogState extends State<_AgentEditDialog> {
  final _nameController = TextEditingController();
  final _modelController = TextEditingController();
  final _connectionController = TextEditingController();
  final _temperatureController = TextEditingController();
  final _promptController = TextEditingController();
  String _agentType = 'generic';

  @override
  void initState() {
    super.initState();
    _nameController.text = (widget.agent['name'] ?? '').toString();
    _agentType = (widget.agent['agent_type'] ?? 'generic').toString();
    _modelController.text = (widget.agent['model'] ?? '').toString();
    _connectionController.text = (widget.agent['connection_id'] ?? '')
        .toString();
    _temperatureController.text = (widget.agent['temperature'] ?? 0.7)
        .toString();
    _promptController.text = (widget.agent['system_prompt'] ?? '').toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _modelController.dispose();
    _connectionController.dispose();
    _temperatureController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop({
      'name': name,
      'agent_type': _agentType,
      'model': _modelController.text.trim(),
      'connection_id': _connectionController.text.trim().isEmpty
          ? null
          : _connectionController.text.trim(),
      'temperature': double.tryParse(_temperatureController.text.trim()) ?? 0.7,
      'system_prompt': _promptController.text,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.tx('admin.edit_agent_title', 'Editar agente')),
      content: SizedBox(
        width: dialogContentWidth(context, 540),
        child: ListView(
          shrinkWrap: true,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: widget.tx('admin.field_name', 'Nombre'),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _agentType,
              decoration: InputDecoration(
                labelText: widget.tx('admin.field_type', 'Tipo'),
              ),
              items: const [
                DropdownMenuItem(value: 'claude', child: Text('claude')),
                DropdownMenuItem(value: 'openai', child: Text('openai')),
                DropdownMenuItem(value: 'github', child: Text('github')),
                DropdownMenuItem(value: 'ollama', child: Text('ollama')),
                DropdownMenuItem(value: 'generic', child: Text('generic')),
              ],
              onChanged: (v) => setState(() => _agentType = v ?? 'generic'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _modelController,
              decoration: InputDecoration(
                labelText: widget.tx('admin.field_model', 'Modelo'),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _connectionController,
              decoration: InputDecoration(
                labelText: widget.tx('admin.field_connection', 'Conexión'),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _temperatureController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: widget.tx('admin.field_temperature', 'Temperatura'),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _promptController,
              minLines: 6,
              maxLines: 10,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: InputDecoration(
                labelText: widget.tx(
                  'admin.field_system_prompt',
                  'Prompt de sistema',
                ),
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
          onPressed: _submit,
          child: Text(widget.tx('common.save', 'Guardar')),
        ),
      ],
    );
  }
}

// ── Tab: Configuración (widget con estado propio) ────────────────────
