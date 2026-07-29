import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/i18n/locale_loader.dart';
import '../../../shared/state/backend_controller.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/widgets/responsive_dialog.dart';
import '../../../shared/widgets/status_dot.dart';

class BackendConfigPage extends StatefulWidget {
  const BackendConfigPage({
    required this.backendController,
    required this.localeController,
    super.key,
  });

  final BackendController backendController;
  final LocaleController localeController;

  @override
  State<BackendConfigPage> createState() => _BackendConfigPageState();
}

class _BackendConfigPageState extends State<BackendConfigPage> {
  late Future<Map<String, dynamic>> _textsFuture;

  // null = comprobando/desconocido, true = responde, false = no responde.
  final Map<String, bool?> _health = {};
  Timer? _healthTimer;

  @override
  void initState() {
    super.initState();
    _textsFuture = LocaleLoader.load(
      isEnglish: widget.localeController.isEnglish,
      namespace: 'auth',
    );
    widget.backendController.addListener(_onChanged);
    _refreshHealth();
    _healthTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => _refreshHealth(),
    );
  }

  @override
  void dispose() {
    widget.backendController.removeListener(_onChanged);
    _healthTimer?.cancel();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refreshHealth() async {
    final options = widget.backendController.options;
    await Future.wait(
      options.map((option) async {
        final result = await widget.backendController.pingBackend(
          option.baseUrl,
        );
        if (!mounted) return;
        setState(() => _health[option.id] = result.ok);
      }),
    );
  }

  String _txt(Map<String, dynamic> bundle, String path, String fallback) {
    return LocaleLoader.text(bundle, path, fallback: fallback);
  }

  Future<void> _openAddDialog(Map<String, dynamic> t) async {
    final saved = await showDialog<SavedBackend>(
      context: context,
      builder: (context) => _BackendFormDialog(
        backendController: widget.backendController,
        t: t,
        txt: _txt,
      ),
    );
    if (saved != null && mounted) {
      setState(() => _health[saved.id] = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _txt(
              t,
              'backend_config.added_toast',
              'Backend "{name}" añadido',
            ).replaceAll('{name}', saved.name),
          ),
        ),
      );
    }
  }

  Future<void> _openEditDialog(
    Map<String, dynamic> t,
    SavedBackend backend,
  ) async {
    final saved = await showDialog<SavedBackend>(
      context: context,
      builder: (context) => _BackendFormDialog(
        backendController: widget.backendController,
        t: t,
        txt: _txt,
        existing: backend,
      ),
    );
    if (saved != null && mounted) {
      setState(() => _health[saved.id] = true);
    }
  }

  Future<void> _confirmDelete(
    Map<String, dynamic> t,
    SavedBackend backend,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _txt(t, 'backend_config.delete_dialog_title', 'Eliminar backend'),
        ),
        content: Text(
          _txt(
            t,
            'backend_config.delete_dialog_body',
            '¿Seguro que quieres eliminar "{name}"?',
          ).replaceAll('{name}', backend.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_txt(t, 'backend_config.cancel', 'Cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_txt(t, 'backend_config.delete_confirm', 'Eliminar')),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await widget.backendController.removeBackend(backend.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _textsFuture,
      builder: (context, snapshot) {
        final t = snapshot.data ?? const <String, dynamic>{};
        final selectedId = widget.backendController.selectedBackendId;
        final options = widget.backendController.options;
        final connectionError = widget.backendController.lastConnectionError;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              _txt(t, 'backend_config.page_title', 'Configurar backend'),
            ),
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      _txt(
                        t,
                        'backend_config.list_title',
                        'Backends disponibles',
                      ),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _txt(
                        t,
                        'backend_config.list_subtitle',
                        'Elige a cuál conectarte, o añade uno nuevo.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 14),
                    ...options.map((option) {
                      final selected = option.id == selectedId;
                      final official = widget.backendController.isOfficial(
                        option.id,
                      );
                      final savedEntry = widget.backendController.savedBackends
                          .where((b) => b.id == option.id)
                          .firstOrNull;
                      return _BackendRow(
                        label: option.label,
                        url: option.baseUrl,
                        selected: selected,
                        official: official,
                        health: _health[option.id],
                        errorMessage: (selected && connectionError != null)
                            ? connectionError
                            : null,
                        officialLabel: _txt(
                          t,
                          'backend_config.official_badge',
                          'Oficial',
                        ),
                        editTooltip: _txt(
                          t,
                          'backend_config.edit_tooltip',
                          'Editar',
                        ),
                        deleteTooltip: _txt(
                          t,
                          'backend_config.delete_tooltip',
                          'Eliminar',
                        ),
                        onTap: () => widget.backendController
                            .setSelectedBackend(option.id),
                        onEdit: (official || savedEntry == null)
                            ? null
                            : () => _openEditDialog(t, savedEntry),
                        onDelete: (official || savedEntry == null)
                            ? null
                            : () => _confirmDelete(t, savedEntry),
                      );
                    }),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _openAddDialog(t),
                      icon: const Icon(Icons.add),
                      label: Text(
                        _txt(t, 'backend_config.add_button', 'Añadir backend'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _BackendRow extends StatelessWidget {
  const _BackendRow({
    required this.label,
    required this.url,
    required this.selected,
    required this.official,
    required this.health,
    required this.errorMessage,
    required this.officialLabel,
    required this.editTooltip,
    required this.deleteTooltip,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final String label;
  final String url;
  final bool selected;
  final bool official;
  final bool? health;
  final String? errorMessage;
  final String officialLabel;
  final String editTooltip;
  final String deleteTooltip;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: selected ? scheme.primaryContainer.withValues(alpha: 0.35) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: selected
            ? BorderSide(color: scheme.primary, width: 1.4)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected ? scheme.primary : scheme.outline,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        StatusDot(
                          state: switch (health) {
                            true => StatusDotState.ok,
                            false => StatusDotState.error,
                            null => StatusDotState.unknown,
                          },
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            label,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (official) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              officialLabel,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      url,
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFC62828),
                          fontSize: 11,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (onEdit != null)
                IconButton(
                  tooltip: editTooltip,
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: onEdit,
                ),
              if (onDelete != null)
                IconButton(
                  tooltip: deleteTooltip,
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: onDelete,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackendFormDialog extends StatefulWidget {
  const _BackendFormDialog({
    required this.backendController,
    required this.t,
    required this.txt,
    this.existing,
  });

  final BackendController backendController;
  final Map<String, dynamic> t;
  final String Function(
    Map<String, dynamic> bundle,
    String path,
    String fallback,
  )
  txt;
  final SavedBackend? existing;

  @override
  State<_BackendFormDialog> createState() => _BackendFormDialogState();
}

class _BackendFormDialogState extends State<_BackendFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final _hostController = TextEditingController();
  late final _portController = TextEditingController();

  bool _testing = false;
  bool? _verified;
  String? _verifiedUrl;
  String? _statusMessage;

  bool get _isEditing => widget.existing != null;

  String _tx(String path, String fallback) =>
      widget.txt(widget.t, path, fallback);

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      final parts = widget.backendController.splitHostAndPort(existing.url);
      _hostController.text = parts.host;
      _portController.text = parts.port;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _invalidateVerification() {
    if (_verified != null) setState(() => _verified = null);
  }

  String? _composedUrl() {
    final combined = widget.backendController.composeHostAndPort(
      _hostController.text,
      _portController.text,
    );
    final normalized = widget.backendController.normalizeBackendInput(combined);
    return normalized.isEmpty ? null : normalized;
  }

  Future<void> _testConnection() async {
    if (_formKey.currentState?.validate() != true) return;
    final url = _composedUrl();
    if (url == null) {
      setState(
        () => _statusMessage = _tx(
          'backend_config.invalid_host',
          'Host inválido. Usa un dominio o IP.',
        ),
      );
      return;
    }

    setState(() {
      _testing = true;
      _statusMessage = null;
    });
    final result = await widget.backendController.pingBackend(url);
    if (!mounted) return;
    if (result.ok) {
      setState(() {
        _verified = true;
        _verifiedUrl = url;
        _statusMessage = _tx('backend_config.test_ok', 'Conexión OK');
        _testing = false;
      });
    } else {
      setState(() {
        _verified = false;
        _statusMessage = result.statusCode != null
            ? _tx(
                'backend_config.test_http_error',
                'El servidor respondió HTTP {code}',
              ).replaceAll('{code}', '${result.statusCode}')
            : _tx(
                'backend_config.test_connection_error',
                'No se pudo conectar: {error}',
              ).replaceAll('{error}', result.error ?? '');
        _testing = false;
      });
    }
  }

  Future<void> _save() async {
    if (_verified != true || _verifiedUrl == null) return;
    final existing = widget.existing;
    final entry = existing == null
        ? await widget.backendController.addBackend(
            name: _nameController.text.trim(),
            url: _verifiedUrl!,
          )
        : await widget.backendController.updateBackend(
            existing.id,
            name: _nameController.text.trim(),
            url: _verifiedUrl!,
          );
    if (!mounted) return;
    Navigator.of(context).pop(entry);
  }

  @override
  Widget build(BuildContext context) {
    final readyToSave = _verified == true && _verifiedUrl != null;
    return AlertDialog(
      title: Text(
        _isEditing
            ? _tx('backend_config.edit_dialog_title', 'Editar backend')
            : _tx('backend_config.dialog_title', 'Añadir backend'),
      ),
      content: SizedBox(
        width: dialogContentWidth(context, 420),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: _tx('backend_config.field_name', 'Nombre'),
                  hintText: _tx(
                    'backend_config.field_name_hint',
                    'p. ej. Servidor de casa',
                  ),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? _tx(
                        'backend_config.name_required',
                        'El nombre es obligatorio',
                      )
                    : null,
                onChanged: (_) => _invalidateVerification(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _hostController,
                decoration: InputDecoration(
                  labelText: _tx('backend_config.field_host', 'Dominio o IP'),
                  hintText: _tx(
                    'backend_config.field_host_hint',
                    'www.midominio.com o 192.168.1.20',
                  ),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? _tx(
                        'backend_config.invalid_host',
                        'Host inválido. Usa un dominio o IP.',
                      )
                    : null,
                onChanged: (_) => _invalidateVerification(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _portController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _tx(
                    'backend_config.field_port',
                    'Puerto (opcional)',
                  ),
                ),
                onChanged: (_) => _invalidateVerification(),
              ),
              if (_statusMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _statusMessage!,
                  style: TextStyle(
                    color: _verified == true
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFC62828),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_tx('backend_config.cancel', 'Cancelar')),
        ),
        if (!readyToSave)
          FilledButton.icon(
            onPressed: _testing ? null : _testConnection,
            icon: _testing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_find),
            label: Text(
              _testing
                  ? _tx('backend_config.test_button_loading', 'Comprobando…')
                  : _tx('backend_config.test_button', 'Comprobar conexión'),
            ),
          )
        else
          FilledButton.icon(
            onPressed: _save,
            icon: Icon(_isEditing ? Icons.save_outlined : Icons.add),
            label: Text(
              _isEditing
                  ? _tx('backend_config.save_button', 'Guardar cambios')
                  : _tx(
                      'backend_config.add_confirmed_button',
                      'Añadir a la lista',
                    ),
            ),
          ),
      ],
    );
  }
}
