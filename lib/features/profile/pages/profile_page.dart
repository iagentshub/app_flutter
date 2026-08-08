import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';

import '../../../app/theme/fnc_colors.dart';
import '../../../app/theme/fnc_fonts.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/async_state_panel.dart';
import '../../../shared/widgets/confirm_action_dialog.dart';

import '../../../app/router/router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../features/connections/widgets/providers_section.dart';
import '../../../models/profile/profile_models.dart';
import '../repositories/profile_repository.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/brand_icon_controller.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/state/theme_controller.dart';
import '../../../shared/widgets/brand_icon.dart';
import '../../../shared/widgets/responsive_dialog.dart';
import '../../../shared/widgets/state_messaging_mixin.dart';
import '../utils/avatar_compressor.dart';
import '../widgets/profile_groups_section.dart';

part '../widgets/brand_icon_selector.dart';
part '../widgets/profile_account_section.dart';
part '../widgets/profile_groups_tab_section.dart';
part '../widgets/profile_social_section.dart';
part '../widgets/profile_view_helpers.dart';

/// Idiomas disponibles para el perfil público. Por ahora la plataforma solo
/// soporta Español e Inglés (a diferencia del listado más amplio de
/// la interfaz web, aún no habilitado aquí).
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
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
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
    with SingleTickerProviderStateMixin, StateMessaging {
  late final ProfileRepository _repository;
  late final TranslatedTexts _t;
  late final TabController _tabController;

  static const _sectionIds = ['account', 'social', 'groups', 'providers'];

  ProfileBundle? _bundle;
  bool _loading = true;
  String? _error;
  bool _savingSettings = false;
  bool _savingProfile = false;
  bool _requestingDeletion = false;
  bool _uploadingAvatar = false;
  int _avatarVersion = 0;

  final _bioController = TextEditingController();
  bool _isEmailPublic = false;
  final _githubController = TextEditingController();
  final _cvController = TextEditingController();
  Set<String> _selectedLanguages = {};
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();

  String _theme = 'dark-red';
  String _defaultTheme = 'dark-red';
  bool _themeConfigurable = true;
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
        _defaultTheme = bundle.settings.defaultTheme;
        _themeConfigurable = bundle.settings.themeConfigurable;
        _language = bundle.settings.language;
        _bioController.text = bundle.social.bio ?? '';
        _isEmailPublic = bundle.session.isEmailPublic;
        _githubController.text = _githubUsernameFromUrl(bundle.social.github);
        _cvController.text = bundle.social.cv ?? '';
        _selectedLanguages = bundle.social.languages.toSet();
        _loading = false;
      });
      widget.localeController.syncFromBackend(bundle.settings.language);
      ThemeControllerScope.of(
        context,
        listen: false,
      ).syncFromBackend(bundle.settings.theme);
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
        theme: _themeConfigurable ? _theme : null,
        language: _language,
      );
      if (!mounted) return;
      setState(() {
        _theme = updated.theme;
        _defaultTheme = updated.defaultTheme;
        _themeConfigurable = updated.themeConfigurable;
        _language = updated.language;
      });
      widget.localeController.syncFromBackend(updated.language);
      await ThemeControllerScope.of(
        context,
        listen: false,
      ).syncFromBackend(updated.theme);
      showMessage('Preferencias guardadas');
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage('No se pudieron guardar las preferencias', isError: true);
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
        isEmailPublic: _isEmailPublic,
        github: _githubUrlFromUsername(_githubController.text) ?? '',
        cv: _cvController.text.trim(),
        languages: _selectedLanguages.toList(),
      );
      showMessage('Perfil público actualizado');
      await _load();
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage('No se pudo actualizar el perfil público', isError: true);
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

    final result = await FilePicker.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final rawBytes = file.bytes;
    if (rawBytes == null || rawBytes.isEmpty) {
      showMessage(
        _tx('profile.avatar_error', 'No se pudo actualizar la foto'),
        isError: true,
      );
      return;
    }
    // Rechazar antes de intentar decodificar: evita que el dispositivo
    // procese un fichero de entrada absurdamente grande.
    if (rawBytes.length > 40 * 1024 * 1024) {
      showMessage(
        _tx('profile.avatar_input_too_large', 'La imagen original es demasiado grande'),
        isError: true,
      );
      return;
    }

    setState(() => _uploadingAvatar = true);
    try {
      final compressed = await compute(
        compressAvatarBytes,
        AvatarCompressionInput(rawBytes),
      );

      if (compressed.bytes.length > 10 * 1024 * 1024) {
        showMessage(
          _tx('profile.avatar_too_large', 'La imagen no puede superar 10 MB'),
          isError: true,
        );
        return;
      }

      await widget.apiClient.postMultipart(
        '/api/auth/me/avatar',
        fieldName: 'avatar',
        fileName: compressed.fileName,
        fileBytes: compressed.bytes,
        gaToken: token,
      );
      if (!mounted) return;
      setState(() => _avatarVersion++);
      showMessage(_tx('profile.avatar_updated', 'Foto de perfil actualizada'));
    } on AvatarCompressionException catch (_) {
      showMessage(
        _tx('profile.avatar_error', 'No se pudo actualizar la foto'),
        isError: true,
      );
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(
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
            width: dialogContentWidth(context, 320),
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
            TertiaryButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_tx('common.cancel', 'Cancelar')),
            ),
            PrimaryButton(
              onPressed: () => Navigator.of(context).pop(draft),
              child: Text(_tx('common.save', 'Guardar')),
            ),
          ],
        ),
      ),
    );
    if (result != null) setState(() => _selectedLanguages = result);
  }

  Future<void> _openChangePasswordDialog() async {
    var submitting = false;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_tx('profile.tab_security', 'Seguridad')),
          content: SizedBox(
            width: dialogContentWidth(context, 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
              ],
            ),
          ),
          actions: [
            TertiaryButton(
              onPressed: submitting ? null : () => Navigator.of(context).pop(),
              child: Text(_tx('common.cancel', 'Cancelar')),
            ),
            PrimaryButton.icon(
              onPressed: submitting
                  ? null
                  : () async {
                      setDialogState(() => submitting = true);
                      final ok = await _changePassword();
                      if (!context.mounted) return;
                      if (ok) {
                        Navigator.of(context).pop();
                      } else {
                        setDialogState(() => submitting = false);
                      }
                    },
              icon: const Icon(Icons.lock_reset_outlined),
              label: Text(
                submitting
                    ? _tx('profile.updating', 'Actualizando...')
                    : _tx('profile.change_password', 'Cambiar contraseña'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _changePassword() async {
    final token = _token;
    if (token == null || token.isEmpty) return false;

    final current = _currentPasswordController.text;
    final next = _newPasswordController.text;
    if (current.isEmpty || next.isEmpty) {
      showMessage('Completa contraseña actual y nueva', isError: true);
      return false;
    }
    if (next.trim().length < 8) {
      showMessage(
        'La nueva contraseña debe tener al menos 8 caracteres',
        isError: true,
      );
      return false;
    }

    try {
      await _repository.changePassword(
        token,
        currentPassword: current,
        newPassword: next,
      );
      _currentPasswordController.clear();
      _newPasswordController.clear();
      showMessage('Contraseña actualizada');
      return true;
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
      return false;
    } catch (_) {
      showMessage('No se pudo actualizar la contraseña', isError: true);
      return false;
    }
  }

  Future<void> _requestDeletion() async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    final bundle = _bundle;
    if (bundle == null) return;
    if (bundle.deletion.scheduled) {
      showMessage('La cuenta ya está programada para eliminación');
      return;
    }

    final confirm = await showConfirmActionDialog(
      context,
      title: 'Solicitar eliminación de cuenta',
      message:
          'La cuenta se programará para eliminación en 30 días. ¿Deseas continuar?',
      cancelLabel: 'Cancelar',
      confirmLabel: 'Confirmar',
    );
    if (!confirm) return;

    setState(() => _requestingDeletion = true);
    try {
      final message = await _repository.requestDeletion(token);
      showMessage(message);
      await _load();
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(
        'No se pudo programar la eliminación de cuenta',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _requestingDeletion = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AsyncStatePanel.loading();
    if (_error != null) {
      return ListView(
        children: [
          AsyncStatePanel.error(
            title: 'Error cargando perfil',
            message: _error!,
            retryLabel: _tx('common.retry', 'Reintentar'),
            onRetry: _load,
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
      _tx('connections.tab_providers', 'Proveedores'),
    ];
    final section = _sectionIds[_tabController.index];
    final token = _token;

    return Column(
      children: [
        Material(
          color: FncColors.transparent,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: tabLabels.map((label) => Tab(text: label)).toList(),
          ),
        ),
        Expanded(
          // Proveedores trae su propio ListView con scroll interno,
          // incompatible con el ListView de ancho acotado que usan el resto
          // de secciones — se monta a pantalla completa.
          child: section == 'providers'
              ? (token == null || token.isEmpty
                    ? const SizedBox.shrink()
                    : ProvidersSection(
                        apiClient: widget.apiClient,
                        token: token,
                        localeController: widget.localeController,
                      ))
              : RefreshIndicator(
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
}
