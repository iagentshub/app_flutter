import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../models/profile/profile_models.dart';
import '../repositories/profile_repository.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../widgets/profile_groups_section.dart';

/// Mismo listado fijo de idiomas que _ALL_LANGS en profile.js (frontend_vanilla).
const _languageOptions = [
  ('es', 'Español', '🇪🇸'),
  ('en', 'English', '🇬🇧'),
  ('fr', 'Français', '🇫🇷'),
  ('de', 'Deutsch', '🇩🇪'),
  ('pt', 'Português', '🇵🇹'),
  ('it', 'Italiano', '🇮🇹'),
  ('zh', '中文', '🇨🇳'),
  ('ja', '日本語', '🇯🇵'),
  ('ar', 'العربية', '🇸🇦'),
];

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    required this.apiClient,
    required this.sessionController,
    required this.localeController,
    super.key,
  });

  final ApiClient apiClient;
  final SessionController sessionController;
  final LocaleController localeController;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final ProfileRepository _repository;
  late final TranslatedTexts _t;

  ProfileBundle? _bundle;
  bool _loading = true;
  String? _error;
  bool _savingSettings = false;
  bool _savingProfile = false;
  bool _changingPassword = false;
  bool _requestingDeletion = false;
  String _section = 'account';

  final _bioController = TextEditingController();
  final _emailPublicController = TextEditingController();
  final _githubController = TextEditingController();
  final _cvController = TextEditingController();
  Set<String> _selectedLanguages = {};
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();

  String _theme = 'dark-red';
  String _language = 'es';

  String _tx(String path, String fallback) => _t.text(path, fallback: fallback);

  @override
  void initState() {
    super.initState();
    _repository = ProfileRepository(apiClient: widget.apiClient);
    _t = TranslatedTexts(localeController: widget.localeController, namespace: 'resources')
      ..addListener(_onTextsChanged);
    _load();
  }

  void _onTextsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _bioController.dispose();
    _emailPublicController.dispose();
    _githubController.dispose();
    _cvController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _t.removeListener(_onTextsChanged);
    _t.dispose();
    super.dispose();
  }

  String? get _token => widget.sessionController.gaToken;

  Future<void> _load() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = _tx('common.no_session', 'No hay sesión activa');
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final bundle = await _repository.fetchBundle(token);
      if (!mounted) return;
      setState(() {
        _bundle = bundle;
        _theme = bundle.settings.theme;
        _language = bundle.settings.language;
        _bioController.text = bundle.social.bio ?? '';
        _emailPublicController.text = bundle.social.emailPublic ?? '';
        _githubController.text = bundle.social.github ?? '';
        _cvController.text = bundle.social.cv ?? '';
        _selectedLanguages = bundle.social.languages.toSet();
        _loading = false;
      });
      widget.localeController.syncFromBackend(bundle.settings.language);
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar el perfil';
        _loading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    final token = _token;
    if (token == null || token.isEmpty) return;

    setState(() => _savingSettings = true);
    try {
      final updated = await _repository.updateSettings(
        token,
        theme: _theme,
        language: _language,
      );
      if (!mounted) return;
      setState(() {
        _theme = updated.theme;
        _language = updated.language;
      });
      widget.localeController.syncFromBackend(updated.language);
      _showMessage('Preferencias guardadas');
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudieron guardar las preferencias', isError: true);
    } finally {
      if (mounted) setState(() => _savingSettings = false);
    }
  }

  Future<void> _savePublicProfile() async {
    final token = _token;
    if (token == null || token.isEmpty) return;

    setState(() => _savingProfile = true);
    try {
      await _repository.updateSocialProfile(
        token,
        bio: _bioController.text.trim(),
        emailPublic: _emailPublicController.text.trim(),
        github: _githubController.text.trim(),
        cv: _cvController.text.trim(),
        languages: _selectedLanguages.toList(),
      );
      _showMessage('Perfil público actualizado');
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo actualizar el perfil público', isError: true);
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _changePassword() async {
    final token = _token;
    if (token == null || token.isEmpty) return;

    final current = _currentPasswordController.text;
    final next = _newPasswordController.text;
    if (current.isEmpty || next.isEmpty) {
      _showMessage('Completa contraseña actual y nueva', isError: true);
      return;
    }
    if (next.trim().length < 8) {
      _showMessage('La nueva contraseña debe tener al menos 8 caracteres', isError: true);
      return;
    }

    setState(() => _changingPassword = true);
    try {
      await _repository.changePassword(
        token,
        currentPassword: current,
        newPassword: next,
      );
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _showMessage('Contraseña actualizada');
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo actualizar la contraseña', isError: true);
    } finally {
      if (mounted) setState(() => _changingPassword = false);
    }
  }

  Future<void> _requestDeletion() async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    final bundle = _bundle;
    if (bundle == null) return;
    if (bundle.deletion.scheduled) {
      _showMessage('La cuenta ya está programada para eliminación');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Solicitar eliminación de cuenta'),
        content: const Text(
          'La cuenta se programará para eliminación en 30 días. ¿Deseas continuar?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Confirmar')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _requestingDeletion = true);
    try {
      final message = await _repository.requestDeletion(token);
      _showMessage(message);
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo programar la eliminación de cuenta', isError: true);
    } finally {
      if (mounted) setState(() => _requestingDeletion = false);
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
    if (_loading) return const Center(child: CircularProgressIndicator());
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
                  const Text('Error cargando perfil', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_error!),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: Text(_tx('common.retry', 'Reintentar')),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final bundle = _bundle;
    if (bundle == null) {
      return const Center(child: Text('No hay datos de perfil disponibles'));
    }

    final tabs = <(String, String)>[
      ('account', _tx('profile.tab_account', 'Mi cuenta')),
      ('social', _tx('profile.tab_social', 'Perfil público')),
      ('preferences', _tx('profile.tab_preferences', 'Preferencias')),
      ('groups', _tx('profile.tab_groups', 'Grupos')),
      ('security', _tx('profile.tab_security', 'Seguridad')),
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: tabs.length,
              separatorBuilder: (context, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final (id, label) = tabs[index];
                return ChoiceChip(
                  label: Text(label),
                  selected: _section == id,
                  onSelected: (_) => setState(() => _section = id),
                );
              },
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    switch (_section) {
                      'social' => _buildSocialSection(bundle),
                      'preferences' => _buildPreferencesSection(),
                      'groups' => _buildGroupsSection(bundle),
                      'security' => _buildSecuritySection(),
                      _ => _buildAccountSection(bundle),
                    },
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(IconData icon, String text, {Color? color}) {
    final resolvedColor = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 16, color: resolvedColor),
        const SizedBox(width: 6),
        Text(
          text.toUpperCase(),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: resolvedColor),
        ),
      ],
    );
  }

  Widget _badge(String text, {required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildAccountSection(ProfileBundle bundle) {
    final username = bundle.session.username;
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';
    final planTier = bundle.license.tier;
    final planLabel = planTier == 'free' ? _tx('profile.plan_free', 'Gratuito') : planTier;
    final memberSince = bundle.social.createdAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  child: Text(initial, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(username, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _badge(bundle.session.role, color: Theme.of(context).colorScheme.primary),
                          _badge(planLabel, color: const Color(0xFF0891B2)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _sectionHeader(Icons.badge_outlined, _tx('profile.identity_title', 'Identidad')),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              _infoRow(
                Icons.groups_outlined,
                _tx('profile.active_group_label', 'Grupo activo'),
                bundle.session.workspaceName ?? bundle.session.workspaceId ?? '-',
              ),
              if (memberSince != null && memberSince.isNotEmpty) ...[
                const Divider(height: 1),
                _infoRow(Icons.calendar_today_outlined, _tx('profile.member_since', 'Miembro desde'), memberSince),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        _sectionHeader(Icons.warning_amber_outlined, _tx('profile.account_zone_title', 'Zona de cuenta'), color: Colors.red),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bundle.deletion.scheduled
                      ? '${_tx('profile.deletion_scheduled', 'Eliminación programada para')}: ${bundle.deletion.deletionDate ?? '-'}'
                      : _tx('profile.no_deletion_scheduled', 'No hay eliminación programada'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _requestingDeletion || bundle.deletion.scheduled ? null : _requestDeletion,
                  icon: const Icon(Icons.warning_amber_outlined),
                  label: Text(_requestingDeletion ? _tx('profile.scheduling', 'Programando...') : _tx('profile.request_deletion', 'Solicitar eliminación de cuenta')),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreferencesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(Icons.tune_outlined, _tx('profile.tab_preferences', 'Preferencias')),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _theme,
                  decoration: InputDecoration(labelText: _tx('profile.theme_label', 'Tema')),
                  items: _themes.map((theme) => DropdownMenuItem<String>(value: theme, child: Text(theme))).toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _theme = value);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _language,
                  decoration: InputDecoration(labelText: _tx('profile.language_label', 'Idioma')),
                  items: const [
                    DropdownMenuItem(value: 'es', child: Text('Español')),
                    DropdownMenuItem(value: 'en', child: Text('English')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _language = value);
                  },
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _savingSettings ? null : _saveSettings,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_savingSettings ? _tx('profile.saving', 'Guardando...') : _tx('profile.save_preferences', 'Guardar preferencias')),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialSection(ProfileBundle bundle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _sectionHeader(Icons.public_outlined, _tx('profile.tab_social', 'Perfil público'))),
            TextButton.icon(
              onPressed: () => context.push('${RouteNames.publicProfilePrefix}${bundle.session.username}'),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(_tx('profile.view_public_profile', 'Ver mi perfil')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _bioController,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: InputDecoration(labelText: _tx('profile.bio_label', 'Bio')),
                ),
                const SizedBox(height: 6),
                Text(_tx('profile.languages_label', 'Idiomas'), style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 4),
                Text(
                  _tx('profile.languages_hint', 'Elige los idiomas en los que puedes trabajar.'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _languageOptions.map((option) {
                    final (id, label, flag) = option;
                    final selected = _selectedLanguages.contains(id);
                    return FilterChip(
                      label: Text('$flag $label'),
                      selected: selected,
                      onSelected: (value) {
                        setState(() {
                          if (value) {
                            _selectedLanguages = {..._selectedLanguages, id};
                          } else {
                            _selectedLanguages = {..._selectedLanguages}..remove(id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailPublicController,
                  decoration: InputDecoration(labelText: _tx('profile.email_public_label', 'Email público')),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _githubController,
                  decoration: InputDecoration(labelText: _tx('profile.github_label', 'GitHub (https://...)')),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _cvController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: InputDecoration(labelText: _tx('profile.cv_label', 'CV / Resumen profesional')),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _savingProfile ? null : _savePublicProfile,
                  icon: const Icon(Icons.save_as_outlined),
                  label: Text(_savingProfile ? _tx('profile.saving', 'Guardando...') : _tx('profile.save_social', 'Guardar perfil público')),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecuritySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(Icons.lock_outline, _tx('profile.tab_security', 'Seguridad')),
        const SizedBox(height: 8),
        Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _currentPasswordController,
              obscureText: true,
              decoration: InputDecoration(labelText: _tx('profile.current_password_label', 'Contraseña actual')),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: InputDecoration(labelText: _tx('profile.new_password_label', 'Nueva contraseña')),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _changingPassword ? null : _changePassword,
              icon: const Icon(Icons.lock_reset_outlined),
              label: Text(_changingPassword ? _tx('profile.updating', 'Actualizando...') : _tx('profile.change_password', 'Cambiar contraseña')),
            ),
          ],
        ),
      ),
        ),
      ],
    );
  }

  Widget _buildGroupsSection(ProfileBundle bundle) {
    final token = _token;
    if (token == null || token.isEmpty) return const SizedBox.shrink();
    return ProfileGroupsSection(
      apiClient: widget.apiClient,
      token: token,
      currentUsername: bundle.session.username,
      localeController: widget.localeController,
    );
  }
}

const _themes = [
  'dark-red',
  'dark-blue',
  'dark-orange',
  'dark-purple',
  'light-red',
  'light-blue',
  'light-orange',
  'light-purple',
  'noir',
  'marble',
  'ember',
  'ocean',
  'forest',
  'dusk',
];
