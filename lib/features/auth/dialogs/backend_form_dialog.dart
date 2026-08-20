part of '../pages/backend_config_page.dart';

class _BackendFormDialog extends StatefulWidget {
  const _BackendFormDialog({
    required this.backendController,
    required this.tx,
    this.existing,
  });

  final BackendController backendController;
  final String Function(String path) tx;
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

  String _tx(String path) => widget.tx(path);

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
      setState(() => _statusMessage = _tx('backend_config.invalid_host'));
      return;
    }

    setState(() {
      _testing = true;
      _statusMessage = null;
    });
    final result = await widget.backendController.pingBackend(url);
    if (!mounted) return;
    _applyConnectionResult(result, url);
  }

  void _applyConnectionResult(BackendPingResult result, String url) {
    if (result.ok) {
      setState(() {
        _verified = true;
        _verifiedUrl = url;
        _statusMessage = _tx('backend_config.test_ok');
        _testing = false;
      });
    } else {
      setState(() {
        _verified = false;
        _verifiedUrl = null;
        _statusMessage = result.error != null
            ? _tx(
                'backend_config.test_connection_error',
              ).replaceAll('{error}', result.error!)
            : result.statusCode != null
            ? _tx(
                'backend_config.test_http_error',
              ).replaceAll('{code}', '${result.statusCode}')
            : _tx(
                'backend_config.test_connection_error',
              ).replaceAll('{error}', result.error ?? '');
        _testing = false;
      });
    }
  }

  Future<void> _save() async {
    if (_verified != true || _verifiedUrl == null) return;
    final url = _verifiedUrl!;
    setState(() {
      _testing = true;
      _statusMessage = _tx('backend_config.test_button_loading');
    });

    // La comprobación que habilitó el botón puede haberse quedado obsoleta.
    // Se valida de nuevo inmediatamente antes de persistir para no guardar un
    // backend que ya no responde o que dejó de exponer el contrato esperado.
    final result = await widget.backendController.pingBackend(url);
    if (!mounted) return;
    if (!result.ok) {
      _applyConnectionResult(result, url);
      return;
    }

    final existing = widget.existing;
    final entry = existing == null
        ? await widget.backendController.addBackend(
            name: _nameController.text.trim(),
            url: url,
          )
        : await widget.backendController.updateBackend(
            existing.id,
            name: _nameController.text.trim(),
            url: url,
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
        !_testing &&
        (!insecureTransport || _insecureTransportAccepted);
    return AlertDialog(
      title: Text(
        _isEditing
            ? _tx('backend_config.edit_dialog_title')
            : _tx('backend_config.dialog_title'),
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
                  labelText: _tx('backend_config.field_name'),
                  hintText: _tx('backend_config.field_name_hint'),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? _tx('backend_config.name_required')
                    : null,
                onChanged: (_) => _invalidateVerification(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _hostController,
                decoration: InputDecoration(
                  labelText: _tx('backend_config.field_host'),
                  hintText: _tx('backend_config.field_host_hint'),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? _tx('backend_config.invalid_host')
                    : null,
                onChanged: (_) => _invalidateVerification(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _portController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _tx('backend_config.field_port'),
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
                    title: Text(_tx('backend_config.http_warning_title')),
                    subtitle: Text(_tx('backend_config.http_warning_body')),
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
          child: Text(_tx('backend_config.cancel')),
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
                  ? _tx('backend_config.test_button_loading')
                  : _tx('backend_config.test_button'),
            ),
          )
        else
          PrimaryButton.icon(
            onPressed: readyToSave ? _save : null,
            icon: _testing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_isEditing ? Icons.save_outlined : Icons.add),
            label: Text(
              _testing
                  ? _tx('backend_config.test_button_loading')
                  : _isEditing
                  ? _tx('backend_config.save_button')
                  : _tx('backend_config.add_confirmed_button'),
            ),
          ),
      ],
    );
  }
}
