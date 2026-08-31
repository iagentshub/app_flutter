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

  final AdminPlatformRepository repository;
  final String token;
  final Map<String, dynamic> initialSettings;
  final String Function(String path) tx;
  final ValueChanged<Map<String, dynamic>> onSaved;

  @override
  State<_AdminConfigTab> createState() => _AdminConfigTabState();
}

class _AdminConfigTabState extends State<_AdminConfigTab> with StateMessaging {
  late bool _registrationOpen;
  late final TextEditingController _maxUsersController;
  late final TextEditingController _maxSessionsController;
  late final TextEditingController _maxUploadMbController;
  late final TextEditingController _logRetentionController;
  late final TextEditingController _auditLogRetentionController;
  late final TextEditingController _stressConcurrencyController;
  late bool _emailVerify;
  late bool _guestEnabled;
  late bool _landingEnabled;
  late bool _billingEnabled;
  late bool _oauthGoogle;
  late bool _oauthApple;
  late bool _oauthMicrosoft;
  late bool _oauthGithub;
  late bool _usersCanConfigureTheme;
  late String _defaultTheme;

  bool _saving = false;
  String? _saveMsg;

  String _tx(String path) => widget.tx(path);

  @override
  void initState() {
    super.initState();
    final cfg = widget.initialSettings;
    _registrationOpen = (cfg['registration'] ?? 'open').toString() == 'open';
    _maxUsersController = TextEditingController(
      text: (cfg['max_users'] ?? 0).toString(),
    );
    _maxSessionsController = TextEditingController(
      text: (cfg['max_concurrent_sessions'] ?? 0).toString(),
    );
    // Se edita en MB porque es la unidad en la que se piensa un fichero; el
    // contrato con el backend sigue siendo en bytes.
    _maxUploadMbController = TextEditingController(
      text: _bytesToMb(cfg['max_request_bytes']),
    );
    _logRetentionController = TextEditingController(
      text: (cfg['log_retention_days'] ?? 30).toString(),
    );
    _auditLogRetentionController = TextEditingController(
      text: (cfg['audit_log_retention_days'] ?? 365).toString(),
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
    _oauthGithub = cfg['oauth_github_enabled'] != false;
    _usersCanConfigureTheme = cfg['users_can_configure_theme'] != false;
    _defaultTheme = (cfg['default_theme'] ?? 'dark-red').toString();
    if (!kThemeIds.contains(_defaultTheme)) _defaultTheme = 'dark-red';
  }

  @override
  void dispose() {
    _maxUsersController.dispose();
    _maxSessionsController.dispose();
    _maxUploadMbController.dispose();
    _logRetentionController.dispose();
    _auditLogRetentionController.dispose();
    _stressConcurrencyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final themeController = ThemeControllerScope.of(context, listen: false);
    setState(() {
      _saving = true;
      _saveMsg = null;
    });
    try {
      final payload = {
        'registration': _registrationOpen ? 'open' : 'closed',
        'max_users': int.tryParse(_maxUsersController.text.trim()) ?? 0,
        'max_concurrent_sessions':
            int.tryParse(_maxSessionsController.text.trim()) ?? 0,
        'email_verify': _emailVerify,
        'guest_enabled': _guestEnabled,
        'landing_enabled': _landingEnabled,
        'billing_enabled': _billingEnabled,
        'log_retention_days':
            int.tryParse(_logRetentionController.text.trim()) ?? 30,
        'audit_log_retention_days':
            int.tryParse(_auditLogRetentionController.text.trim()) ?? 365,
        'max_request_bytes': _mbToBytes(_maxUploadMbController.text),
        'stress_max_concurrency':
            int.tryParse(_stressConcurrencyController.text.trim()) ?? 0,
        'oauth_google_enabled': _oauthGoogle,
        'oauth_apple_enabled': _oauthApple,
        'oauth_microsoft_enabled': _oauthMicrosoft,
        'oauth_github_enabled': _oauthGithub,
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
      setState(() => _saveMsg = _tx('admin.config_saved'));
      showMessage(_tx('admin.config_saved'));
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(_tx('admin.error_generic'), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[
      _sectionCard(_tx('admin.config_section_registration'), [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_tx('admin.config_registration_open')),
          value: _registrationOpen,
          onChanged: (v) => setState(() => _registrationOpen = v),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _maxUsersController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText:
                '${_tx('admin.config_max_users')} ${_tx('admin.config_unlimited_hint')}',
          ),
        ),
        const SizedBox(height: 6),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_tx('admin.config_email_verify')),
          value: _emailVerify,
          onChanged: (v) => setState(() => _emailVerify = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_tx('admin.config_guest_enabled')),
          value: _guestEnabled,
          onChanged: (v) => setState(() => _guestEnabled = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_tx('admin.config_landing_enabled')),
          subtitle: Text(_tx('admin.config_landing_hint')),
          value: _landingEnabled,
          onChanged: (v) => setState(() => _landingEnabled = v),
        ),
      ]),
      _sectionCard(_tx('admin.config_section_sessions'), [
        TextField(
          controller: _maxSessionsController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText:
                '${_tx('admin.config_max_sessions')} ${_tx('admin.config_unlimited_hint')}',
          ),
        ),
      ]),
      _sectionCard(_tx('admin.config_section_appearance'), [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_tx('admin.config_user_theme_enabled')),
          subtitle: Text(_tx('admin.config_user_theme_hint')),
          value: _usersCanConfigureTheme,
          onChanged: (value) => setState(() => _usersCanConfigureTheme = value),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _defaultTheme,
          decoration: InputDecoration(
            labelText: _tx('admin.config_default_theme'),
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
      _sectionCard(_tx('admin.config_section_centinel'), [
        TextField(
          controller: _stressConcurrencyController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText:
                '${_tx('admin.config_stress_concurrency')} ${_tx('admin.config_unlimited_500_hint')}',
          ),
        ),
      ]),
      _sectionCard(_tx('admin.config_section_uploads'), [
        TextField(
          controller: _maxUploadMbController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText:
                '${_tx('admin.config_max_upload')} ${_tx('admin.config_mb_unlimited_hint')}',
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _tx('admin.config_max_upload_hint'),
          style: const TextStyle(fontSize: FncFonts.size12),
        ),
      ]),
      _sectionCard(_tx('admin.config_section_logs'), [
        TextField(
          controller: _logRetentionController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText:
                '${_tx('admin.config_retention')} ${_tx('admin.config_days_hint')}',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _auditLogRetentionController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText:
                '${_tx('admin.config_audit_retention')} ${_tx('admin.config_days_hint')}',
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _tx('admin.config_audit_retention_hint'),
          style: const TextStyle(fontSize: FncFonts.size12),
        ),
      ]),
      _sectionCard(_tx('admin.config_section_billing'), [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_tx('admin.config_billing_enabled')),
          value: _billingEnabled,
          onChanged: (v) => setState(() => _billingEnabled = v),
        ),
      ]),
      _sectionCard(_tx('admin.config_section_oauth'), [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_tx('admin.config_oauth_google')),
          value: _oauthGoogle,
          onChanged: (v) => setState(() => _oauthGoogle = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_tx('admin.config_oauth_apple')),
          value: _oauthApple,
          onChanged: (v) => setState(() => _oauthApple = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_tx('admin.config_oauth_microsoft')),
          value: _oauthMicrosoft,
          onChanged: (v) => setState(() => _oauthMicrosoft = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_tx('admin.config_oauth_github')),
          value: _oauthGithub,
          onChanged: (v) => setState(() => _oauthGithub = v),
        ),
      ]),
      _AdminConfigAuditCard(
        repository: widget.repository,
        token: widget.token,
        tx: _tx,
      ),
      _AdminBannersCard(
        repository: widget.repository,
        token: widget.token,
        tx: _tx,
      ),
      _AdminUpdatesCard(
        repository: widget.repository,
        token: widget.token,
        initialAutoUpdate:
            widget.initialSettings['auto_update_enabled'] != false,
        autoUpdateAvailable:
            widget.initialSettings['auto_update_available'] != false,
        tx: _tx,
      ),
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
                        ? _tx('admin.config_save_loading')
                        : _tx('admin.config_save_btn'),
                  ),
                ),
                if (_saveMsg != null)
                  Text(
                    _saveMsg!,
                    style: const TextStyle(color: _statusOkColor),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Bytes → MB para el campo del formulario. 0 (sin límite) se escribe 0, y un
/// valor que no cae en MB exactos se redondea hacia arriba: quedarse corto
/// bajaría el límite al guardar sin que el administrador lo haya pedido.
String _bytesToMb(Object? bytes) {
  final valor = bytes is num ? bytes.toInt() : 0;
  if (valor <= 0) return '0';
  return ((valor + 1024 * 1024 - 1) ~/ (1024 * 1024)).toString();
}

int _mbToBytes(String texto) {
  final mb = int.tryParse(texto.trim()) ?? 0;
  return mb <= 0 ? 0 : mb * 1024 * 1024;
}

// Colores de estado compartidos por _AdminConfigTab y _AdminUpdatesCard
// (guardado correcto, commit al día / desactualizado).
const _statusOkColor = FncColors.success;
const _statusWarnColor = FncColors.labelDevelopment;

/// Tarjeta genérica de una sección de la pestaña Configuración — usada tanto
/// por los campos de este archivo como por _AdminUpdatesCard.
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
            style: const TextStyle(
              fontSize: FncFonts.size15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    ),
  );
}
