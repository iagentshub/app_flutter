part of '../pages/backend_config_page.dart';

class _BackendFormDialog extends StatefulWidget {
  const _BackendFormDialog({
    required this.backendController,
    required this.tx,
    this.existing,
  });

  final BackendController backendController;
  final String Function(String path, String fallback) tx;
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
  bool _insecureTransportAccepted = false;

  bool get _isEditing => widget.existing != null;

  String _tx(String path, String fallback) => widget.tx(path, fallback);

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
    if (_verified != null || _insecureTransportAccepted) {
      setState(() {
        _verified = null;
        _insecureTransportAccepted = false;
      });
    }
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
    final connectionVerified = _verified == true && _verifiedUrl != null;
    final insecureTransport =
        connectionVerified && BackendUrl.usesInsecureTransport(_verifiedUrl);
    final readyToSave =
        connectionVerified &&
        (!insecureTransport || _insecureTransportAccepted);
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
              if (insecureTransport) ...[
                const SizedBox(height: 12),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.errorContainer.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: CheckboxListTile(
                    value: _insecureTransportAccepted,
                    onChanged: (value) => setState(
                      () => _insecureTransportAccepted = value ?? false,
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: Text(
                      _tx(
                        'backend_config.http_warning_title',
                        'Conexión HTTP sin cifrar',
                      ),
                    ),
                    subtitle: Text(
                      _tx(
                        'backend_config.http_warning_body',
                        'La cookie de sesión y las respuestas podrán verse o modificarse en la red local. Confirma que confías en esta red y servidor.',
                      ),
                    ),
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
        if (!connectionVerified)
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
            onPressed: readyToSave ? _save : null,
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
