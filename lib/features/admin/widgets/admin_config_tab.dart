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
  late bool _registrationOpen;
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
  late bool _oauthGithub;
  late bool _usersCanConfigureTheme;
  late String _defaultTheme;
  late final TextEditingController _splashCyclesController;
  late bool _splashEndOnLogo;

  bool _saving = false;
  String? _saveMsg;

  String _tx(String path, String fallback) => widget.tx(path, fallback);

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
    _oauthGithub = cfg['oauth_github_enabled'] != false;
    _usersCanConfigureTheme = cfg['users_can_configure_theme'] != false;
    _defaultTheme = (cfg['default_theme'] ?? 'dark-red').toString();
    if (!kThemeIds.contains(_defaultTheme)) _defaultTheme = 'dark-red';
    _splashCyclesController = TextEditingController(
      text: (cfg['splash_cycles'] ?? 1).toString(),
    );
    _splashEndOnLogo = cfg['splash_end_on_logo'] != false;
  }

  @override
  void dispose() {
    _maxUsersController.dispose();
    _maxSessionsController.dispose();
    _logRetentionController.dispose();
    _stressConcurrencyController.dispose();
    _splashCyclesController.dispose();
    super.dispose();
  }

  void _showMessage(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? FncColors.materialRed.shade700 : null,
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
        'stress_max_concurrency':
            int.tryParse(_stressConcurrencyController.text.trim()) ?? 0,
        'oauth_google_enabled': _oauthGoogle,
        'oauth_apple_enabled': _oauthApple,
        'oauth_microsoft_enabled': _oauthMicrosoft,
        'oauth_github_enabled': _oauthGithub,
        'users_can_configure_theme': _usersCanConfigureTheme,
        'default_theme': _defaultTheme,
        'splash_cycles':
            int.tryParse(_splashCyclesController.text.trim()) ?? 1,
        'splash_end_on_logo': _splashEndOnLogo,
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

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[
      _sectionCard(_tx('admin.config_section_registration', 'Registro'), [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_tx('admin.config_registration_open', 'Abrir registro')),
          value: _registrationOpen,
          onChanged: (v) => setState(() => _registrationOpen = v),
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
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            _tx('admin.config_oauth_github', 'Mostrar botón de GitHub'),
          ),
          value: _oauthGithub,
          onChanged: (v) => setState(() => _oauthGithub = v),
        ),
      ]),
      _AdminBannersCard(
        repository: widget.repository,
        token: widget.token,
        tx: _tx,
      ),
      _sectionCard(_tx('admin.config_section_splash', 'Animación de inicio'), [
        TextField(
          controller: _splashCyclesController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: _tx('admin.config_splash_cycles', 'Ciclos'),
            helperText: _tx(
              'admin.config_splash_cycles_hint',
              'Cada ciclo es una ida y vuelta completa del logo (1-10).',
            ),
          ),
        ),
        const SizedBox(height: 6),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            _tx('admin.config_splash_end_on_logo', 'Terminar en el logo'),
          ),
          subtitle: Text(
            _tx(
              'admin.config_splash_end_on_logo_hint',
              'Si se desactiva, el splash se cierra en la forma inicial en vez de en el logo iA.',
            ),
          ),
          value: _splashEndOnLogo,
          onChanged: (v) => setState(() => _splashEndOnLogo = v),
        ),
      ]),
      _AdminUpdatesCard(
        repository: widget.repository,
        token: widget.token,
        initialAutoUpdate:
            widget.initialSettings['auto_update_enabled'] != false,
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
                        ? _tx('admin.config_save_loading', 'Guardando...')
                        : _tx('admin.config_save_btn', 'Guardar configuración'),
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
