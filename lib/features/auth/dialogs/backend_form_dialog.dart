part of '../pages/backend_config_page.dart';

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
                        ? FncColors.materialGreen800
                        : FncColors.materialRed800,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TertiaryButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_tx('backend_config.cancel', 'Cancelar')),
        ),
        if (!readyToSave)
          PrimaryButton.icon(
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
          PrimaryButton.icon(
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
