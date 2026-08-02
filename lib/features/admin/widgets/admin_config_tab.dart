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
  late bool _usersCanConfigureTheme;
  late String _defaultTheme;
  late bool _maintenanceEnabled;
  late final TextEditingController _maintenanceMessageController;
  DateTime? _maintenanceAt;

  bool _saving = false;
  String? _saveMsg;

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
    _usersCanConfigureTheme = cfg['users_can_configure_theme'] != false;
    _defaultTheme = (cfg['default_theme'] ?? 'dark-red').toString();
    if (!kThemeIds.contains(_defaultTheme)) _defaultTheme = 'dark-red';
    _maintenanceEnabled = cfg['maintenance_enabled'] == true;
    _maintenanceMessageController = TextEditingController(
      text: (cfg['maintenance_message'] ?? '').toString(),
    );
    _maintenanceAt = DateTime.tryParse(
      (cfg['maintenance_at'] ?? '').toString(),
    );
  }

  @override
  void dispose() {
    _maxUsersController.dispose();
    _maxSessionsController.dispose();
    _logRetentionController.dispose();
    _stressConcurrencyController.dispose();
    _maintenanceMessageController.dispose();
    super.dispose();
  }

  Future<void> _pickMaintenanceAt() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _maintenanceAt ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _maintenanceAt != null
          ? TimeOfDay.fromDateTime(_maintenanceAt!)
          : TimeOfDay.fromDateTime(now),
    );
    if (time == null) return;
    setState(() {
      _maintenanceAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
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
        'maintenance_enabled': _maintenanceEnabled,
        'maintenance_message': _maintenanceMessageController.text.trim(),
        'maintenance_at': _maintenanceAt?.toIso8601String(),
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
      _sectionCard(
        _tx('admin.config_section_maintenance', 'Mantenimiento'),
        [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              _tx('admin.config_maintenance_enabled', 'Aviso activo'),
            ),
            subtitle: Text(
              _tx(
                'admin.config_maintenance_hint',
                'Muestra un banner informativo a todos los usuarios — no bloquea la app.',
              ),
            ),
            value: _maintenanceEnabled,
            onChanged: (v) => setState(() => _maintenanceEnabled = v),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _maintenanceMessageController,
            maxLength: 500,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: _tx('admin.config_maintenance_message', 'Mensaje'),
              hintText: _tx(
                'admin.config_maintenance_message_hint',
                'Ej: mantenimiento el viernes a las 20h, puede haber cortes breves',
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  _maintenanceAt == null
                      ? _tx(
                          'admin.config_maintenance_no_date',
                          'Sin fecha programada',
                        )
                      : _fmtDateTime(_maintenanceAt!),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              TertiaryButton(
                onPressed: _pickMaintenanceAt,
                child: Text(
                  _tx('admin.config_maintenance_pick_date', 'Elegir fecha'),
                ),
              ),
              if (_maintenanceAt != null)
                AppIconButton(
                  tooltip: _tx('common.clear', 'Quitar'),
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _maintenanceAt = null),
                ),
            ],
          ),
        ],
      ),
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
const _statusOkColor = Color(0xFF059669);
const _statusWarnColor = Color(0xFFD97706);

String _fmtDateTime(DateTime dt) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
}

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
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    ),
  );
}
