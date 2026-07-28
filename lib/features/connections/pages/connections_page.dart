import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../models/connections/connection_models.dart';
import '../repositories/connections_repository.dart';
import '../../../shared/state/session_controller.dart';

class ConnectionsPage extends StatefulWidget {
  const ConnectionsPage({
    required this.apiClient,
    required this.sessionController,
    super.key,
  });

  final ApiClient apiClient;
  final SessionController sessionController;

  @override
  State<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends State<ConnectionsPage> {
  late final ConnectionsRepository _repository;
  List<ConnectionItem> _connections = const [];
  List<ConnectionProvider> _providers = const [];
  bool _loading = true;
  bool _testingAll = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = ConnectionsRepository(apiClient: widget.apiClient);
    _load();
  }

  String? get _token => widget.sessionController.gaToken;

  Future<void> _load() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'No hay sesión activa';
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _repository.listConnections(token),
        _repository.listProviders(token),
      ]);

      if (!mounted) return;
      setState(() {
        _connections = results[0] as List<ConnectionItem>;
        _providers = results[1] as List<ConnectionProvider>;
        _loading = false;
      });
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar las conexiones';
        _loading = false;
      });
    }
  }

  Future<void> _openCreateDialog() async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ConnectionFormDialog(providers: _providers),
    );

    if (payload == null) return;
    await _saveConnection(payload);
  }

  Future<void> _openEditDialog(ConnectionItem item) async {
    if (item.isVirtual) {
      _showMessage('Esta conexión es derivada de Ollama y no se edita directamente');
      return;
    }

    final token = _token;
    if (token == null || token.isEmpty) return;

    Map<String, dynamic> initial = item.raw;
    try {
      initial = await _repository.getConnection(token, item.id);
    } catch (_) {
      // Si falla detalle, intentamos editar con lo ya cargado en lista.
    }

    if (!mounted) return;
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ConnectionFormDialog(
        providers: _providers,
        initial: initial,
      ),
    );

    if (payload == null) return;
    payload['id'] = item.id;
    await _saveConnection(payload);
  }

  Future<void> _saveConnection(Map<String, dynamic> payload) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    try {
      await _repository.saveConnection(token, payload);
      _showMessage('Conexión guardada');
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo guardar la conexión', isError: true);
    }
  }

  Future<void> _deleteConnection(ConnectionItem item) async {
    if (item.isVirtual) {
      _showMessage('Esta conexión es derivada de Ollama y no se elimina directamente');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar conexión'),
        content: Text('¿Seguro que quieres eliminar "${item.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm != true) return;

    final token = _token;
    if (token == null || token.isEmpty) return;

    try {
      await _repository.deleteConnection(token, item.id);
      _showMessage('Conexión eliminada');
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo eliminar la conexión', isError: true);
    }
  }

  Future<void> _testConnection(ConnectionItem item) async {
    if (item.isVirtual) {
      _showMessage('Esta conexión es derivada de Ollama y no se testea directamente');
      return;
    }

    final token = _token;
    if (token == null || token.isEmpty) return;
    try {
      final result = await _repository.testConnection(token, item.id);
      final detail = result.detail?.trim().isNotEmpty == true ? '\n${result.detail}' : '';
      _showMessage('${result.ok ? 'OK' : 'ERROR'}: ${result.message}$detail', isError: !result.ok);
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo testear la conexión', isError: true);
    }
  }

  Future<void> _testAll() async {
    final token = _token;
    if (token == null || token.isEmpty) return;

    setState(() => _testingAll = true);
    try {
      final results = await _repository.testAllConnections(token);
      if (!mounted) return;
      final ok = results.where((r) => r.ok).length;
      final fail = results.length - ok;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Test masivo (${results.length})'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Correctas: $ok | Fallidas: $fail'),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: results
                        .map(
                          (r) => ListTile(
                            dense: true,
                            leading: Icon(r.ok ? Icons.check_circle_outline : Icons.error_outline),
                            title: Text(r.id),
                            subtitle: Text(r.message),
                            trailing: r.latencyMs == null ? null : Text('${r.latencyMs}ms'),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo ejecutar test masivo', isError: true);
    } finally {
      if (mounted) {
        setState(() => _testingAll = false);
      }
    }
  }

  void _showMessage(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.red.shade700 : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Error cargando conexiones', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_error!),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _providers.isEmpty ? null : _openCreateDialog,
                icon: const Icon(Icons.add),
                label: const Text('Nueva conexión'),
              ),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Actualizar'),
              ),
              OutlinedButton.icon(
                onPressed: _testingAll ? null : _testAll,
                icon: const Icon(Icons.play_circle_outline),
                label: Text(_testingAll ? 'Probando...' : 'Test masivo'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Conexiones: ${_connections.length} | Proveedores: ${_providers.length}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          if (_connections.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No hay conexiones todavía. Crea la primera.'),
              ),
            )
          else
            ..._connections.map(_buildConnectionCard),
        ],
      ),
    );
  }

  Widget _buildConnectionCard(ConnectionItem item) {
    final metaParts = <String>[item.type];
    if (item.model.isNotEmpty) metaParts.add(item.model);
    if (item.host.isNotEmpty) metaParts.add(item.host);
    if (item.url.isNotEmpty) metaParts.add(item.url);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                if (item.shared) _chip('Shared'),
                if (item.personalKey) _chip('Personal'),
                if (item.isVirtual) _chip('Virtual'),
              ],
            ),
            const SizedBox(height: 6),
            Text(metaParts.join(' · ')),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: item.isVirtual ? null : () => _testConnection(item),
                  icon: const Icon(Icons.health_and_safety_outlined),
                  label: const Text('Test'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openEditDialog(item),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _deleteConnection(item),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Eliminar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _ConnectionFormDialog extends StatefulWidget {
  const _ConnectionFormDialog({
    required this.providers,
    this.initial,
  });

  final List<ConnectionProvider> providers;
  final Map<String, dynamic>? initial;

  @override
  State<_ConnectionFormDialog> createState() => _ConnectionFormDialogState();
}

class _ConnectionFormDialogState extends State<_ConnectionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _scope = 'workspace';
  String _selectedType = '';
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, bool> _boolValues = {};

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController.text = (initial?['name'] as String?) ?? '';
    _scope = initial?['_personal_key'] == true ? 'personal' : 'workspace';

    if (widget.providers.isNotEmpty) {
      final initialType = initial?['type'] as String?;
      _selectedType = widget.providers.any((p) => p.type == initialType)
          ? (initialType ?? widget.providers.first.type)
          : widget.providers.first.type;
      _syncControllersFromProvider();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  ConnectionProvider? get _provider {
    for (final p in widget.providers) {
      if (p.type == _selectedType) return p;
    }
    return null;
  }

  void _syncControllersFromProvider() {
    final provider = _provider;
    if (provider == null) return;
    final initial = widget.initial;

    for (final field in provider.fields) {
      if (field.type == 'checkbox') {
        final raw = initial?[field.key];
        final boolValue = raw is bool
            ? raw
            : (raw is String ? raw.toLowerCase() == 'true' : field.defaultValue.toLowerCase() == 'true');
        _boolValues[field.key] = boolValue;
        continue;
      }

      final existingController = _textControllers[field.key];
      if (existingController != null) continue;

      final value = initial?[field.key]?.toString() ?? field.defaultValue;
      _textControllers[field.key] = TextEditingController(text: value);
    }
  }

  bool _visible(ProviderField field) {
    if (field.dependsOn == null || field.dependsOn!.isEmpty) return true;
    final dependsOn = field.dependsOn!;
    final expected = field.dependsValue ?? '';
    final boolVal = _boolValues[dependsOn];
    if (boolVal != null) {
      return boolVal.toString() == expected;
    }
    final textVal = _textControllers[dependsOn]?.text ?? '';
    return textVal == expected;
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    final provider = _provider;
    if (provider == null) return;

    final payload = <String, dynamic>{
      'name': _nameController.text.trim(),
      'type': _selectedType,
      'scope': _scope,
    };

    for (final field in provider.fields) {
      if (!_visible(field)) continue;

      if (field.type == 'checkbox') {
        payload[field.key] = _boolValues[field.key] ?? false;
        continue;
      }

      final raw = _textControllers[field.key]?.text ?? '';
      if (field.type == 'number') {
        final parsed = num.tryParse(raw.trim());
        if (parsed != null) {
          payload[field.key] = parsed;
        } else {
          payload[field.key] = raw.trim();
        }
      } else {
        payload[field.key] = raw.trim();
      }
    }

    Navigator.of(context).pop(payload);
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider;

    return AlertDialog(
      title: Text(widget.initial == null ? 'Nueva conexión' : 'Editar conexión'),
      content: SizedBox(
        width: 560,
        child: provider == null
            ? const Text('No hay proveedores disponibles')
            : Form(
                key: _formKey,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'El nombre es obligatorio';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedType,
                      items: widget.providers
                          .map(
                            (p) => DropdownMenuItem<String>(
                              value: p.type,
                              child: Text('${p.label} (${p.type})'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _selectedType = value;
                          _syncControllersFromProvider();
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Proveedor'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _scope,
                      items: const [
                        DropdownMenuItem(value: 'workspace', child: Text('Workspace')),
                        DropdownMenuItem(value: 'personal', child: Text('Personal')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _scope = value);
                      },
                      decoration: const InputDecoration(labelText: 'Ámbito'),
                    ),
                    const SizedBox(height: 10),
                    ...provider.fields
                        .where(_visible)
                        .map((field) => _buildField(field))
                        .expand((widget) => [widget, const SizedBox(height: 10)]),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Guardar'),
        ),
      ],
    );
  }

  Widget _buildField(ProviderField field) {
    if (field.type == 'checkbox') {
      final value = _boolValues[field.key] ?? false;
      return SwitchListTile(
        title: Text(field.label),
        value: value,
        onChanged: (next) => setState(() => _boolValues[field.key] = next),
        contentPadding: EdgeInsets.zero,
      );
    }

    if (field.type == 'select') {
      final controller = _textControllers[field.key] ??= TextEditingController(text: field.defaultValue);
      final current = controller.text.isEmpty ? null : controller.text;
      return DropdownButtonFormField<String>(
        initialValue: current,
        decoration: InputDecoration(labelText: field.label),
        items: field.options
            .map((option) => DropdownMenuItem<String>(value: option.value, child: Text(option.label)))
            .toList(),
        onChanged: (value) {
          controller.text = value ?? '';
          setState(() {});
        },
        validator: (value) {
          if (field.required && (value == null || value.trim().isEmpty)) {
            return 'Campo obligatorio';
          }
          return null;
        },
      );
    }

    final controller = _textControllers[field.key] ??= TextEditingController(text: field.defaultValue);
    final isPassword = field.type == 'password';
    final isNumber = field.type == 'number';
    final isTextarea = field.type == 'textarea';

    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      minLines: isTextarea ? 3 : 1,
      maxLines: isTextarea ? 5 : 1,
      decoration: InputDecoration(
        labelText: field.label,
        hintText: field.placeholder.isEmpty ? null : field.placeholder,
      ),
      validator: (value) {
        if (field.required && (value == null || value.trim().isEmpty)) {
          return 'Campo obligatorio';
        }
        return null;
      },
    );
  }
}
