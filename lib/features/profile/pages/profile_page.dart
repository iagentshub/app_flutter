import 'package:file_picker/file_picker.dart';
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

/// Idiomas disponibles para el perfil público. Por ahora la plataforma solo
/// soporta Español e Inglés (a diferencia del listado más amplio de
/// frontend_vanilla, aún no habilitado aquí).
const _languageOptions = [('es', 'Español', '🇪🇸'), ('en', 'English', '🇬🇧')];

/// El backend exige que `github` sea una URL https:// completa, pero pedirle
/// eso al usuario es peor UX que un campo "usuario de GitHub" con prefijo
/// fijo `github.com/` — se convierte en los dos sentidos aquí.
String _githubUsernameFromUrl(String? url) {
  if (url == null || url.isEmpty) return '';
  final match = RegExp(
    r'github\.com/([^/\s]+)',
    caseSensitive: false,
  ).firstMatch(url);
  return match?.group(1) ?? url;
}

String? _githubUrlFromUsername(String input) {
  final trimmed = input.trim().replaceAll(RegExp(r'^@'), '');
  if (trimmed.isEmpty) return null;
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://'))
    return trimmed;
  return 'https://github.com/$trimmed';
}

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

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late final ProfileRepository _repository;
  late final TranslatedTexts _t;
  late final TabController _tabController;

  static const _sectionIds = ['account', 'social', 'groups', 'security'];

  ProfileBundle? _bundle;
  bool _loading = true;
  String? _error;
  bool _savingSettings = false;
  bool _savingProfile = false;
  bool _changingPassword = false;
  bool _requestingDeletion = false;
  bool _uploadingAvatar = false;
  int _avatarVersion = 0;

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
    _tabController = TabController(length: _sectionIds.length, vsync: this)
      ..addListener(_onTabChanged);
    _t = TranslatedTexts(
      localeController: widget.localeController,
      namespace: 'resources',
    )..addListener(_onTextsChanged);
    _load();
  }

  void _onTextsChanged() {
    if (mounted) setState(() {});
  }

  void _onTabChanged() {
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
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
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
        _githubController.text = _githubUsernameFromUrl(bundle.social.github);
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
        github: _githubUrlFromUsername(_githubController.text) ?? '',
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

  String? get _avatarUrl {
    final username = _bundle?.session.username;
    if (username == null || username.isEmpty) return null;
    final base = widget.apiClient.backendController.effectiveBaseUrl;
    return '$base/api/users/${Uri.encodeComponent(username)}/avatar?v=$_avatarVersion';
  }

  Future<void> _pickAndUploadAvatar() async {
    final token = _token;
    if (token == null || token.isEmpty) return;

    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      _showMessage(
        _tx('profile.avatar_error', 'No se pudo actualizar la foto'),
        isError: true,
      );
      return;
    }
    if (bytes.length > 2 * 1024 * 1024) {
      _showMessage(
        _tx('profile.avatar_too_large', 'La imagen no puede superar 2 MB'),
        isError: true,
      );
      return;
    }

    setState(() => _uploadingAvatar = true);
    try {
      await widget.apiClient.postMultipart(
        '/api/auth/me/avatar',
        fieldName: 'avatar',
        fileName: file.name,
        fileBytes: bytes,
        gaToken: token,
      );
      if (!mounted) return;
      setState(() => _avatarVersion++);
      _showMessage(_tx('profile.avatar_updated', 'Foto de perfil actualizada'));
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage(
        _tx('profile.avatar_error', 'No se pudo actualizar la foto'),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _openLanguagesDialog() async {
    var draft = {..._selectedLanguages};
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_tx('profile.manage_languages', 'Gestionar idiomas')),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _languageOptions.map((option) {
                final (id, label, flag) = option;
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: draft.contains(id),
                  title: Text('$flag $label'),
                  onChanged: (value) {
                    setDialogState(() {
                      if (value == true) {
                        draft = {...draft, id};
                      } else {
                        draft = {...draft}..remove(id);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_tx('common.cancel', 'Cancelar')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(draft),
              child: Text(_tx('common.save', 'Guardar')),
            ),
          ],
        ),
      ),
    );
    if (result != null) setState(() => _selectedLanguages = result);
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
      _showMessage(
        'La nueva contraseña debe tener al menos 8 caracteres',
        isError: true,
      );
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
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmar'),
          ),
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
      _showMessage(
        'No se pudo programar la eliminación de cuenta',
        isError: true,
      );
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
                  const Text(
                    'Error cargando perfil',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
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

    final tabLabels = <String>[
      _tx('profile.tab_account', 'Mi cuenta'),
      _tx('profile.tab_social', 'Perfil público'),
      _tx('profile.tab_groups', 'Grupos'),
      _tx('profile.tab_security', 'Seguridad'),
    ];
    final section = _sectionIds[_tabController.index];

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: tabLabels.map((label) => Tab(text: label)).toList(),
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
                    switch (section) {
                      'social' => _buildSocialSection(bundle),
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
    final resolvedColor =
        color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 16, color: resolvedColor),
        const SizedBox(width: 6),
        Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: resolvedColor,
          ),
        ),
      ],
    );
  }

  Widget _badge(String text, {required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildAvatar(String initial) {
    final token = _token;
    final url = _avatarUrl;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipOval(
          child: SizedBox(
            width: 64,
            height: 64,
            child: (url != null && token != null)
                ? Image.network(
                    url,
                    headers: {'Cookie': 'ga_token=$token'},
                    fit: BoxFit.cover,
                    // El avatar subido puede pesar hasta 2MB a resolución
                    // completa; decodificar solo a 128px (2x el tamaño en
                    // pantalla) evita mantener un bitmap gigante en memoria
                    // para mostrarlo en un círculo de 64x64.
                    cacheWidth: 128,
                    cacheHeight: 128,
                    errorBuilder: (context, error, stack) =>
                        _avatarFallback(initial),
                    loadingBuilder: (context, child, progress) =>
                        progress == null ? child : _avatarFallback(initial),
                  )
                : _avatarFallback(initial),
          ),
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: InkWell(
            onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).cardColor,
                  width: 2,
                ),
              ),
              child: _uploadingAvatar
                  ? const Padding(
                      padding: EdgeInsets.all(5),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.camera_alt, size: 13, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _avatarFallback(String initial) {
    return CircleAvatar(
      radius: 32,
      child: Text(
        initial,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildAccountSection(ProfileBundle bundle) {
    final username = bundle.session.username;
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';
    final planTier = bundle.license.tier;
    final planLabel = planTier == 'free'
        ? _tx('profile.plan_free', 'Gratuito')
        : planTier;
    final memberSince = bundle.social.createdAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                _buildAvatar(initial),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _badge(
                            bundle.session.role,
                            color: Theme.of(context).colorScheme.primary,
                          ),
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
        _sectionHeader(
          Icons.badge_outlined,
          _tx('profile.identity_title', 'Identidad'),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              _infoRow(
                Icons.groups_outlined,
                _tx('profile.active_group_label', 'Grupo activo'),
                bundle.session.workspaceName ??
                    bundle.session.workspaceId ??
                    '-',
              ),
              if (memberSince != null && memberSince.isNotEmpty) ...[
                const Divider(height: 1),
                _infoRow(
                  Icons.calendar_today_outlined,
                  _tx('profile.member_since', 'Miembro desde'),
                  memberSince,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        _sectionHeader(
          Icons.tune_outlined,
          _tx('profile.tab_preferences', 'Preferencias'),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _theme,
                  decoration: InputDecoration(
                    labelText: _tx('profile.theme_label', 'Tema'),
                  ),
                  items: _themes
                      .map(
                        (theme) => DropdownMenuItem<String>(
                          value: theme,
                          child: Text(theme),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _theme = value);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _language,
                  decoration: InputDecoration(
                    labelText: _tx('profile.language_label', 'Idioma'),
                  ),
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
                  label: Text(
                    _savingSettings
                        ? _tx('profile.saving', 'Guardando...')
                        : _tx(
                            'profile.save_preferences',
                            'Guardar preferencias',
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _sectionHeader(
          Icons.warning_amber_outlined,
          _tx('profile.account_zone_title', 'Zona de cuenta'),
          color: Colors.red,
        ),
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
                      : _tx(
                          'profile.no_deletion_scheduled',
                          'No hay eliminación programada',
                        ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _requestingDeletion || bundle.deletion.scheduled
                      ? null
                      : _requestDeletion,
                  icon: const Icon(Icons.warning_amber_outlined),
                  label: Text(
                    _requestingDeletion
                        ? _tx('profile.scheduling', 'Programando...')
                        : _tx(
                            'profile.request_deletion',
                            'Solicitar eliminación de cuenta',
                          ),
                  ),
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
            Expanded(
              child: _sectionHeader(
                Icons.public_outlined,
                _tx('profile.tab_social', 'Perfil público'),
              ),
            ),
            TextButton.icon(
              onPressed: () => context.push(
                '${RouteNames.publicProfilePrefix}${bundle.session.username}',
              ),
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
                  decoration: InputDecoration(
                    labelText: _tx('profile.bio_label', 'Bio'),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _tx('profile.languages_label', 'Idiomas'),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _selectedLanguages.isEmpty
                          ? Text(
                              _tx(
                                'profile.languages_empty',
                                'Sin idiomas seleccionados',
                              ),
                              style: Theme.of(context).textTheme.bodySmall,
                            )
                          : Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _languageOptions
                                  .where(
                                    (option) =>
                                        _selectedLanguages.contains(option.$1),
                                  )
                                  .map(
                                    (option) => Chip(
                                      label: Text('${option.$3} ${option.$2}'),
                                    ),
                                  )
                                  .toList(),
                            ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _openLanguagesDialog,
                      icon: const Icon(Icons.tune, size: 16),
                      label: Text(
                        _tx('profile.manage_languages', 'Gestionar idiomas'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailPublicController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: _tx(
                      'profile.email_public_label',
                      'Email público',
                    ),
                    prefixIcon: const Icon(Icons.alternate_email, size: 20),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _githubController,
                  decoration: InputDecoration(
                    labelText: _tx('profile.github_label', 'Usuario de GitHub'),
                    prefixIcon: const Icon(Icons.code, size: 20),
                    prefixText: 'github.com/',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _tx('profile.cv_label', 'Resumen profesional'),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  _tx(
                    'profile.cv_hint',
                    'Soporta Markdown. Aparecerá en tu perfil público.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _cvController,
                  minLines: 6,
                  maxLines: 12,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: const InputDecoration(isDense: true),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _savingProfile ? null : _savePublicProfile,
                  icon: const Icon(Icons.save_as_outlined),
                  label: Text(
                    _savingProfile
                        ? _tx('profile.saving', 'Guardando...')
                        : _tx('profile.save_social', 'Guardar perfil público'),
                  ),
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
        _sectionHeader(
          Icons.lock_outline,
          _tx('profile.tab_security', 'Seguridad'),
        ),
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
                  decoration: InputDecoration(
                    labelText: _tx(
                      'profile.current_password_label',
                      'Contraseña actual',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: _tx(
                      'profile.new_password_label',
                      'Nueva contraseña',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _changingPassword ? null : _changePassword,
                  icon: const Icon(Icons.lock_reset_outlined),
                  label: Text(
                    _changingPassword
                        ? _tx('profile.updating', 'Actualizando...')
                        : _tx('profile.change_password', 'Cambiar contraseña'),
                  ),
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
