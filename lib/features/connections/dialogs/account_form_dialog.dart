part of '../widgets/providers_section.dart';

class _AccountFormDialog extends StatefulWidget {
  const _AccountFormDialog({
    required this.apiClient,
    required this.token,
    required this.providers,
    required this.tx,
    this.existing,
  });

  final ApiClient apiClient;
  final String token;

  /// Al crear: los proveedores entre los que elegir (normalmente los 7).
  /// Al editar: una lista de un único elemento — el proveedor de
  /// [existing], que no se puede cambiar.
  final List<AccountProviderMeta> providers;
  final AccountItem? existing;
  final String Function(String path) tx;

  @override
  State<_AccountFormDialog> createState() => _AccountFormDialogState();
}

class _AccountFormDialogState extends State<_AccountFormDialog> {
  late final AccountsRepository _repository;
  final _apiKeyController = TextEditingController();
  final _hostController = TextEditingController();
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _nameController = TextEditingController();
  late String _selectedProvider;
  bool _testing = false;
  bool _saving = false;
  String? _testMessage;
  bool? _testOk;

  static const _ollamaLocalHost = 'http://localhost:11434';
  static const _ollamaCloudHost = 'https://ollama.com';

  bool get _isEdit => widget.existing != null;
  bool get _isHub => _meta.provider == 'iagentshub';
  bool get _isOllama => _meta.provider == 'ollama';

  void _setOllamaHost(String host) {
    setState(() => _hostController.text = host);
  }

  AccountProviderMeta get _meta =>
      widget.providers.firstWhere((m) => m.provider == _selectedProvider);

  @override
  void initState() {
    super.initState();
    _repository = AccountsRepository(apiClient: widget.apiClient);
    final existing = widget.existing;
    _selectedProvider = existing?.provider ?? widget.providers.first.provider;
    _nameController.text = existing?.name ?? '';
    _urlController.text = existing?.url ?? '';
    _usernameController.text = existing?.username ?? '';
    _hostController.text = existing != null && existing.host.isNotEmpty
        ? existing.host
        : (_meta.usesHost ? 'http://localhost:11434' : '');
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _hostController.dispose();
    _urlController.dispose();
    _usernameController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _connectWithGithub() async {
    final accessToken = await showAppDialog<String>(
      context: context,
      builder: (context) => _GithubDeviceFlowDialog(
        apiClient: widget.apiClient,
        token: widget.token,
        tx: widget.tx,
      ),
    );
    if (accessToken == null || accessToken.isEmpty) return;
    setState(() => _apiKeyController.text = accessToken);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.tx('providers.github_connected'))),
    );
  }

  void _onProviderChanged(String provider) {
    setState(() {
      _selectedProvider = provider;
      _testMessage = null;
      _hostController.text = _meta.usesHost ? 'http://localhost:11434' : '';
    });
  }

  String? get _apiKeyOrNull => _apiKeyController.text.trim().isEmpty
      ? null
      : _apiKeyController.text.trim();
  String? get _hostOrNull =>
      _hostController.text.trim().isEmpty ? null : _hostController.text.trim();
  String? get _urlOrNull =>
      _urlController.text.trim().isEmpty ? null : _urlController.text.trim();
  String? get _usernameOrNull => _usernameController.text.trim().isEmpty
      ? null
      : _usernameController.text.trim();
  String? get _nameOrNull =>
      _nameController.text.trim().isEmpty ? null : _nameController.text.trim();

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _testMessage = null;
    });
    try {
      final preview = _isEdit
          ? await _repository.testAccount(
              widget.token,
              widget.existing!.id,
              apiKey: _apiKeyOrNull,
              host: _hostOrNull,
              url: _urlOrNull,
              username: _usernameOrNull,
            )
          : await _repository.testNewAccount(
              widget.token,
              _selectedProvider,
              apiKey: _apiKeyOrNull,
              host: _hostOrNull,
              url: _urlOrNull,
              username: _usernameOrNull,
            );
      if (!mounted) return;
      setState(() {
        if (_isHub) {
          _testOk = preview.ok;
          _testMessage = preview.message?.isNotEmpty == true
              ? preview.message
              : (preview.ok
                    ? widget.tx('providers.test_ok')
                    : widget.tx('providers.error_generic'));
        } else {
          _testOk = preview.models.isNotEmpty;
          _testMessage = preview.models.isNotEmpty
              ? '${preview.modelsCount} ${widget.tx('providers.models_found')}'
              : widget.tx('providers.no_models_found');
        }
      });
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _testOk = false;
        _testMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _testOk = false;
        _testMessage = widget.tx('providers.error_generic');
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await _repository.updateAccount(
          widget.token,
          widget.existing!.id,
          apiKey: _apiKeyOrNull,
          host: _hostOrNull,
          url: _urlOrNull,
          username: _usernameOrNull,
          name: _nameOrNull,
        );
      } else {
        await _repository.createAccount(
          widget.token,
          _selectedProvider,
          apiKey: _apiKeyOrNull,
          host: _hostOrNull,
          url: _urlOrNull,
          username: _usernameOrNull,
          name: _nameOrNull,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: FncColors.materialRed.shade700,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.tx('providers.error_generic')),
          backgroundColor: FncColors.materialRed.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEdit
        ? '${widget.tx('providers.edit_action')} ${widget.existing!.name.isNotEmpty ? widget.existing!.name : _meta.label}'
        : widget.tx('providers.add_account');

    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: dialogContentWidth(context, 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isEdit)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _meta.label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedProvider,
                    decoration: InputDecoration(
                      labelText: widget.tx('providers.provider_label'),
                    ),
                    items: widget.providers
                        .map(
                          (m) => DropdownMenuItem(
                            value: m.provider,
                            child: Text(m.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) _onProviderChanged(value);
                    },
                  ),
                ),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: widget.tx('providers.name_label'),
                  hintText: _meta.label,
                ),
              ),
              if (_meta.requiresUrl) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    labelText: widget.tx('providers.url_label'),
                    hintText: 'https://hub.ejemplo.com',
                  ),
                ),
              ],
              if (_meta.requiresUsername) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: widget.tx('providers.username_label'),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (_meta.provider == 'github') ...[
                SizedBox(
                  width: double.infinity,
                  child: SecondaryButton.icon(
                    onPressed: _connectWithGithub,
                    icon: const Icon(Icons.open_in_new),
                    label: Text(widget.tx('providers.github_connect_action')),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_meta.requiresApiKey)
                TextField(
                  controller: _apiKeyController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: _isHub
                        ? widget.tx('providers.password_label')
                        : _meta.provider == 'github'
                        ? widget.tx('providers.github_token_label')
                        : widget.tx('providers.api_key_label'),
                    hintText: _isEdit ? widget.existing?.apiKeyMasked : null,
                  ),
                ),
              if (_meta.usesHost) ...[
                const SizedBox(height: 12),
                if (_isOllama) ...[
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          onPressed: () => _setOllamaHost(_ollamaLocalHost),
                          child: Text(widget.tx('providers.ollama_host_local')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SecondaryButton(
                          onPressed: () => _setOllamaHost(_ollamaCloudHost),
                          child: Text(widget.tx('providers.ollama_host_cloud')),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                TextField(
                  controller: _hostController,
                  decoration: InputDecoration(
                    labelText: _isOllama
                        ? widget.tx('providers.ollama_host_custom')
                        : widget.tx('providers.host_label'),
                  ),
                ),
                if (_isOllama) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.tx('providers.ollama_host_hint'),
                    style: TextStyle(
                      fontSize: FncFonts.size11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 12),
              SecondaryButton.icon(
                onPressed: _testing ? null : _test,
                icon: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: IAgentsLoadingMark(),
                      )
                    : const Icon(Icons.health_and_safety_outlined),
                label: Text(widget.tx('providers.test_action')),
              ),
              if (_testMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _testMessage!,
                  style: TextStyle(
                    color: _testOk == true
                        ? FncColors.materialGreen
                        : FncColors.materialRed.shade700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TertiaryButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(widget.tx('common.cancel')),
        ),
        PrimaryButton(
          onPressed: _saving ? null : _save,
          child: Text(widget.tx('common.save')),
        ),
      ],
    );
  }
}
