part of '../pages/admin_page.dart';

class _AdminConfigTab extends StatefulWidget {
  const _AdminConfigTab({
    required this.repository,
    required this.token,
    required this.initialSettings,
    required this.tx,
    required this.onSaved,
    super.key,
  });

  final AdminRepository repository;
  final String token;
  final Map<String, dynamic> initialSettings;
  final String Function(String path, String fallback) tx;
  final ValueChanged<Map<String, dynamic>> onSaved;

  @override
  State<_AdminConfigTab> createState() => _AdminConfigTabState();
}

class _AdminConfigTabState extends State<_AdminConfigTab> {
  late String _registration;
  late final TextEditingController _maxUsersController;
  late final TextEditingController _maxSessionsController;
  late final TextEditingController _logRetentionController;
  late final TextEditingController _stressConcurrencyController;
  late bool _emailVerify;
  late bool _guestEnabled;
  late bool _landingEnabled;
  late bool _billingEnabled;
  late bool _oauthGoogle;
  late bool _oauthApple;
  late bool _oauthMicrosoft;
  late bool _autoUpdate;
  late bool _usersCanConfigureTheme;
  late String _defaultTheme;

  bool _saving = false;
  String? _saveMsg;
  bool _checkingUpdate = false;
  String? _checkResult;
  bool? _checkOk;
  String? _autoUpdateResult;
  List<String> _commitLines = [];

  String _tx(String path, String fallback) => widget.tx(path, fallback);

  @override
  void initState() {
    super.initState();
    final cfg = widget.initialSettings;
    var mode = (cfg['registration'] ?? 'open').toString();
    if (mode == 'invite') mode = 'closed';
    _registration = mode;
    _maxUsersController = TextEditingController(
      text: (cfg['max_users'] ?? 0).toString(),
    );
    _maxSessionsController = TextEditingController(
      text: (cfg['max_concurrent_sessions'] ?? 0).toString(),
    );
    _logRetentionController = TextEditingController(
      text: (cfg['log_retention_days'] ?? 30).toString(),
    );
    _stressConcurrencyController = TextEditingController(
      text: (cfg['stress_max_concurrency'] ?? 0).toString(),
    );
    _emailVerify = cfg['email_verify'] == true;
    _guestEnabled = cfg['guest_enabled'] != false;
    _landingEnabled = cfg['landing_enabled'] == true;
    _billingEnabled = cfg['billing_enabled'] == true;
    _oauthGoogle = cfg['oauth_google_enabled'] != false;
    _oauthApple = cfg['oauth_apple_enabled'] != false;
    _oauthMicrosoft = cfg['oauth_microsoft_enabled'] != false;
    _autoUpdate = cfg['auto_update_enabled'] != false;
    _usersCanConfigureTheme = cfg['users_can_configure_theme'] != false;
    _defaultTheme = (cfg['default_theme'] ?? 'dark-red').toString();
    if (!kThemeIds.contains(_defaultTheme)) _defaultTheme = 'dark-red';
  }

  @override
  void dispose() {
    _maxUsersController.dispose();
    _maxSessionsController.dispose();
    _logRetentionController.dispose();
    _stressConcurrencyController.dispose();
    super.dispose();
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

  Future<void> _save() async {
    final themeController = ThemeControllerScope.of(context, listen: false);
    setState(() {
      _saving = true;
      _saveMsg = null;
    });
    try {
      final payload = {
        'registration': _registration,
        'max_users': int.tryParse(_maxUsersController.text.trim()) ?? 0,
        'max_concurrent_sessions':
            int.tryParse(_maxSessionsController.text.trim()) ?? 0,
        'email_verify': _emailVerify,
        'guest_enabled': _guestEnabled,
        'landing_enabled': _landingEnabled,
        'billing_enabled': _billingEnabled,
        'log_retention_days':
            int.tryParse(_logRetentionController.text.trim()) ?? 30,
        'stress_max_concurrency':
            int.tryParse(_stressConcurrencyController.text.trim()) ?? 0,
        'oauth_google_enabled': _oauthGoogle,
        'oauth_apple_enabled': _oauthApple,
        'oauth_microsoft_enabled': _oauthMicrosoft,
        'users_can_configure_theme': _usersCanConfigureTheme,
        'default_theme': _defaultTheme,
      };
      final updated = await widget.repository.updatePlatformSettings(
        widget.token,
        payload,
      );
      widget.onSaved(updated);
      try {
        final effective = await widget.repository.getUserSettings(widget.token);
        await themeController.syncFromBackend(effective['theme'] as String?);
      } catch (_) {
        if (!_usersCanConfigureTheme) {
          await themeController.syncFromBackend(_defaultTheme);
        }
      }
      if (!mounted) return;
      setState(
        () => _saveMsg = _tx('admin.config_saved', 'Configuración guardada'),
      );
      _showMessage(_tx('admin.config_saved', 'Configuración guardada'));
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage(
        _tx('admin.error_generic', 'No se pudo completar la acción'),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleAutoUpdate(bool desired) async {
    setState(() {
      _autoUpdate = desired;
      _autoUpdateResult = null;
    });
    try {
      final result = await widget.repository.setAutoUpdate(
        widget.token,
        desired,
      );
      final enabled = result['auto_update_enabled'] == true;
      if (!mounted) return;
      setState(() {
        _autoUpdate = enabled;
        _autoUpdateResult = enabled
            ? _tx('admin.config_auto_update_on', 'Auto-actualización activada')
            : _tx(
                'admin.config_auto_update_off',
                'Auto-actualización desactivada',
              );
      });
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _autoUpdate = !desired;
        _autoUpdateResult = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _autoUpdate = !desired;
        _autoUpdateResult = _tx(
          'admin.error_generic',
          'No se pudo completar la acción',
        );
      });
    }
  }

  /// Línea "Backend: al día (abc1234)" / "App (Flutter): desactualizado…"
  /// para un componente — o `null` si ese repo no se horneó en la imagen
  /// (`commit == 'dev'`, instalaciones sin BACKEND_COMMIT/FRONTEND_COMMIT/
  /// APP_COMMIT, o builds locales).
  String? _commitLine(
    String label,
    dynamic commit,
    dynamic latest,
    dynamic upToDate,
  ) {
    final commitStr = commit?.toString() ?? 'dev';
    if (commitStr == 'dev') return null;
    final String description;
    if (upToDate == true) {
      description = _tx(
        'admin.config_commit_up_to_date',
        'Up to date ({commit})',
      ).replaceAll('{commit}', commitStr);
    } else if (upToDate == false) {
      description =
          _tx(
                'admin.config_commit_outdated',
                'Outdated: {commit} (latest {latest})',
              )
              .replaceAll('{commit}', commitStr)
              .replaceAll('{latest}', '${latest ?? '?'}');
    } else {
      description = _tx(
        'admin.config_commit_unchecked',
        '{commit} (unverified)',
      ).replaceAll('{commit}', commitStr);
    }
    return '$label: $description';
  }

  List<String> _buildCommitLines(Map<String, dynamic> data) {
    final lines = <String?>[
      _commitLine(
        _tx('admin.config_backend_commit_label', 'Backend'),
        data['backend_commit'],
        data['backend_commit_latest'],
        data['backend_up_to_date'],
      ),
      _commitLine(
        _tx('admin.config_frontend_commit_label', 'Web frontend'),
        data['frontend_commit'],
        data['frontend_commit_latest'],
        data['frontend_up_to_date'],
      ),
      _commitLine(
        _tx('admin.config_app_commit_label', 'App (Flutter)'),
        data['app_commit'],
        data['app_commit_latest'],
        data['app_up_to_date'],
      ),
    ].whereType<String>().toList();
    return lines;
  }

  Future<void> _checkUpdate() async {
    setState(() {
      _checkingUpdate = true;
      _checkResult = null;
      _checkOk = null;
      _commitLines = [];
    });
    try {
      final data = await widget.repository.checkUpdate(widget.token);
      if (!mounted) return;
      final commitLines = _buildCommitLines(data);
      if (data['checked'] != true) {
        setState(() {
          _checkResult = _tx(
            'admin.config_check_error',
            'No se pudo comprobar actualizaciones',
          );
          _checkOk = null;
          _commitLines = commitLines;
        });
      } else if (data['update_available'] == true) {
        setState(() {
          _checkResult =
              _tx(
                    'admin.config_update_available',
                    'Actualización disponible: {latest} (actual: {current})',
                  )
                  .replaceAll('{latest}', '${data['latest_version']}')
                  .replaceAll('{current}', '${data['current_version']}');
          _checkOk = false;
          _commitLines = commitLines;
        });
      } else {
        setState(() {
          _checkResult = _tx(
            'admin.config_up_to_date',
            'Al día (versión {version})',
          ).replaceAll('{version}', '${data['current_version']}');
          _checkOk = true;
          _commitLines = commitLines;
        });
      }
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() => _checkResult = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _checkResult = _tx(
          'admin.config_check_error',
          'No se pudo comprobar actualizaciones',
        ),
      );
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  Widget _sectionCard(String title, List<Widget> children) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[
      _sectionCard(_tx('admin.config_section_registration', 'Registro'), [
        DropdownButtonFormField<String>(
          initialValue: _registration,
          decoration: InputDecoration(
            labelText: _tx('admin.config_mode_label', 'Modo'),
          ),
          items: [
            DropdownMenuItem(
              value: 'open',
              child: Text(_tx('admin.config_mode_open', 'Abierto')),
            ),
            DropdownMenuItem(
              value: 'closed',
              child: Text(_tx('admin.config_mode_closed', 'Cerrado')),
            ),
          ],
          onChanged: (v) => setState(() => _registration = v ?? 'open'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _maxUsersController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText:
                '${_tx('admin.config_max_users', 'Máx. usuarios')} ${_tx('admin.config_unlimited_hint', '(0=∞)')}',
          ),
        ),
        const SizedBox(height: 6),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            _tx('admin.config_email_verify', 'Verificar email al registrarse'),
          ),
          value: _emailVerify,
          onChanged: (v) => setState(() => _emailVerify = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            _tx('admin.config_guest_enabled', 'Acceso como invitado'),
          ),
          value: _guestEnabled,
          onChanged: (v) => setState(() => _guestEnabled = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            _tx(
              'admin.config_landing_enabled',
              'Landing de presentación en "/"',
            ),
          ),
          subtitle: Text(
            _tx(
              'admin.config_landing_hint',
              'Si está desactivado, "/" redirige directo a /login/',
            ),
          ),
          value: _landingEnabled,
          onChanged: (v) => setState(() => _landingEnabled = v),
        ),
      ]),
      _sectionCard(_tx('admin.config_section_sessions', 'Sesiones'), [
        TextField(
          controller: _maxSessionsController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText:
                '${_tx('admin.config_max_sessions', 'Máx. sesiones simultáneas')} ${_tx('admin.config_unlimited_hint', '(0=∞)')}',
          ),
        ),
      ]),
      _sectionCard(_tx('admin.config_section_appearance', 'Apariencia'), [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            _tx(
              'admin.config_user_theme_enabled',
              'Permitir que los usuarios elijan el tema',
            ),
          ),
          subtitle: Text(
            _tx(
              'admin.config_user_theme_hint',
              'Si se desactiva, toda la aplicación usará el tema definido aquí.',
            ),
          ),
          value: _usersCanConfigureTheme,
          onChanged: (value) => setState(() => _usersCanConfigureTheme = value),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _defaultTheme,
          decoration: InputDecoration(
            labelText: _tx('admin.config_default_theme', 'Tema predeterminado'),
          ),
          items: kThemeIds
              .map(
                (theme) =>
                    DropdownMenuItem<String>(value: theme, child: Text(theme)),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _defaultTheme = value);
          },
        ),
      ]),
      _sectionCard(
        _tx('admin.config_section_centinel', 'Centinel · Stress Test'),
        [
          TextField(
            controller: _stressConcurrencyController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText:
                  '${_tx('admin.config_stress_concurrency', 'Concurrencia máx.')} ${_tx('admin.config_unlimited_500_hint', '(0=∞, máx 500)')}',
            ),
          ),
        ],
      ),
      _sectionCard(_tx('admin.config_section_logs', 'Logs'), [
        TextField(
          controller: _logRetentionController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText:
                '${_tx('admin.config_retention', 'Retención')} ${_tx('admin.config_days_hint', '(días)')}',
          ),
        ),
      ]),
      _sectionCard(_tx('admin.config_section_billing', 'Facturación'), [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            _tx(
              'admin.config_billing_enabled',
              'Activar planes de suscripción',
            ),
          ),
          value: _billingEnabled,
          onChanged: (v) => setState(() => _billingEnabled = v),
        ),
      ]),
      _sectionCard(_tx('admin.config_section_oauth', 'Login social'), [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            _tx('admin.config_oauth_google', 'Mostrar botón de Google'),
          ),
          value: _oauthGoogle,
          onChanged: (v) => setState(() => _oauthGoogle = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            _tx('admin.config_oauth_apple', 'Mostrar botón de Apple'),
          ),
          value: _oauthApple,
          onChanged: (v) => setState(() => _oauthApple = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            _tx('admin.config_oauth_microsoft', 'Mostrar botón de Microsoft'),
          ),
          value: _oauthMicrosoft,
          onChanged: (v) => setState(() => _oauthMicrosoft = v),
        ),
      ]),
      _sectionCard(_tx('admin.config_section_updates', 'Actualizaciones'), [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            _tx(
              'admin.config_auto_update',
              'Actualización automática (Watchtower)',
            ),
          ),
          value: _autoUpdate,
          onChanged: _toggleAutoUpdate,
        ),
        if (_autoUpdateResult != null)
          Text(
            _autoUpdateResult!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        const SizedBox(height: 8),
        SecondaryButton(
          onPressed: _checkingUpdate ? null : _checkUpdate,
          child: Text(
            _checkingUpdate
                ? _tx('admin.config_check_update_loading', 'Buscando...')
                : _tx('admin.config_check_update_btn', 'Buscar actualización'),
          ),
        ),
        if (_checkResult != null) ...[
          const SizedBox(height: 6),
          Text(
            _checkResult!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _checkOk == null
                  ? null
                  : (_checkOk == true
                        ? const Color(0xFF059669)
                        : const Color(0xFFD97706)),
            ),
          ),
        ],
        for (final line in _commitLines)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(line, style: Theme.of(context).textTheme.bodySmall),
          ),
      ]),
    ];
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: ResponsiveSliverMasonryGrid(
            minCardWidth: 320,
            maxColumns: 3,
            itemCount: sections.length,
            itemBuilder: (context, index) => sections[index],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverToBoxAdapter(
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                PrimaryButton(
                  onPressed: _saving ? null : _save,
                  child: Text(
                    _saving
                        ? _tx('admin.config_save_loading', 'Guardando...')
                        : _tx('admin.config_save_btn', 'Guardar configuración'),
                  ),
                ),
                if (_saveMsg != null)
                  Text(
                    _saveMsg!,
                    style: const TextStyle(color: Color(0xFF059669)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
