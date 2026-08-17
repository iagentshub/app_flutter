import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/widgets.dart';

import '../../../core/network/api_error.dart';
import '../../../models/profile/profile_models.dart';
import '../../../shared/state/action_result.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../repositories/profile_repository.dart';
import '../utils/avatar_compressor.dart';

/// El backend exige que `github` sea una URL https:// completa, pero pedirle
/// eso al usuario es peor UX que un campo "usuario de GitHub" con prefijo
/// fijo `github.com/` — se convierte en los dos sentidos aquí.
String githubUsernameFromUrl(String? url) {
  if (url == null || url.isEmpty) return '';
  final match = RegExp(
    r'github\.com/([^/\s]+)',
    caseSensitive: false,
  ).firstMatch(url);
  return match?.group(1) ?? url;
}

String? githubUrlFromUsername(String input) {
  final trimmed = input.trim().replaceAll(RegExp(r'^@'), '');
  if (trimmed.isEmpty) return null;
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  return 'https://github.com/$trimmed';
}

/// Orquesta las cuatro pestañas del perfil: carga el bundle, mantiene el
/// borrador de los formularios y ejecuta las acciones sobre la cuenta.
///
/// Los mensajes de resultado se **devuelven** como [ActionResult] en vez de
/// mostrarse aquí: el SnackBar necesita un `BuildContext` que el controller no
/// tiene. `null` significa que no hay nada que mostrar.
///
/// El tema es la excepción: `ThemeController` se resuelve por
/// `InheritedNotifier` y sólo la página puede alcanzarlo, así que el controller
/// recibe [syncTheme] y lo llama cuando el backend le da un tema nuevo.
class ProfileController extends ChangeNotifier {
  ProfileController({
    required ProfileRepository repository,
    required SessionController sessionController,
    required LocaleController localeController,
    required Future<void> Function(String theme) syncTheme,
    required String Function(String path, String fallback) tx,
  }) : _repository = repository,
       _sessionController = sessionController,
       _localeController = localeController,
       _syncTheme = syncTheme,
       _tx = tx;

  /// Tope de la imagen ya comprimida (JPEG) que acepta el backend.
  static const maxAvatarBytes = 10 * 1024 * 1024;

  /// Tope del archivo original antes de comprimir: evita que el dispositivo
  /// procese un fichero de entrada absurdamente grande.
  static const maxAvatarInputBytes = 40 * 1024 * 1024;

  /// Mínimo que exige `POST /api/auth/change-password`.
  static const minPasswordLength = 8;

  final ProfileRepository _repository;
  final SessionController _sessionController;
  final LocaleController _localeController;
  final Future<void> Function(String theme) _syncTheme;
  final String Function(String path, String fallback) _tx;

  final TextEditingController bioController = TextEditingController();
  final TextEditingController githubController = TextEditingController();
  final TextEditingController cvController = TextEditingController();
  final TextEditingController currentPasswordController =
      TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();

  bool _disposed = false;

  ProfileBundle? _bundle;
  bool _loading = true;
  String? _error;
  bool _savingSettings = false;
  bool _savingProfile = false;
  bool _requestingDeletion = false;
  bool _uploadingAvatar = false;
  int _avatarVersion = 0;

  // Borrador de los formularios: se rellena en `load` y sólo viaja al backend
  // cuando el usuario pulsa guardar.
  bool _isEmailPublic = false;
  Set<String> _selectedLanguages = <String>{};
  String _theme = 'dark-red';
  String _defaultTheme = 'dark-red';
  bool _themeConfigurable = true;
  String _language = 'es';

  ProfileBundle? get bundle => _bundle;
  bool get loading => _loading;
  String? get error => _error;
  bool get savingSettings => _savingSettings;
  bool get savingProfile => _savingProfile;
  bool get requestingDeletion => _requestingDeletion;
  bool get uploadingAvatar => _uploadingAvatar;

  bool get isEmailPublic => _isEmailPublic;
  String get theme => _theme;
  String get defaultTheme => _defaultTheme;
  bool get themeConfigurable => _themeConfigurable;
  String get language => _language;

  /// Conjunto vivo, no una copia: el diálogo de idiomas lo lee para armar su
  /// borrador y copiarlo en cada `build` sería gasto puro. Sólo el controller
  /// lo muta, siempre por reasignación en [setLanguages].
  Set<String> get selectedLanguages => _selectedLanguages;
  bool get hasLanguages => _selectedLanguages.isNotEmpty;
  bool hasLanguage(String id) => _selectedLanguages.contains(id);

  /// `null` mientras no haya bundle cargado: el avatar cuelga del username.
  String? get avatarUrl {
    final username = _bundle?.session.username;
    if (username == null || username.isEmpty) return null;
    return _repository.avatarUrl(username, _avatarVersion);
  }

  String? get token => _sessionController.gaToken;

  /// Para las vistas que hablan con la API sin pasar por el controller —el
  /// diálogo de sesiones activas, que tiene su propio ciclo de carga.
  ProfileRepository get repository => _repository;

  // ── Borrador ──────────────────────────────────────────────────────────

  void setTheme(String value) {
    _theme = value;
    _notify();
  }

  void setLanguage(String value) {
    _language = value;
    _notify();
  }

  void setEmailPublic(bool value) {
    _isEmailPublic = value;
    _notify();
  }

  void setLanguages(Set<String> value) {
    _selectedLanguages = value;
    _notify();
  }

  // ── Carga y acciones ──────────────────────────────────────────────────

  Future<void> load() async {
    final token = this.token;
    if (token == null || token.isEmpty) {
      _error = _tx('common.no_session', 'No hay sesión activa');
      _loading = false;
      _notify();
      return;
    }

    _loading = true;
    _error = null;
    _notify();

    try {
      final bundle = await _repository.fetchBundle(token);
      _bundle = bundle;
      _theme = bundle.settings.theme;
      _defaultTheme = bundle.settings.defaultTheme;
      _themeConfigurable = bundle.settings.themeConfigurable;
      _language = bundle.settings.language;
      bioController.text = bundle.social.bio ?? '';
      _isEmailPublic = bundle.session.isEmailPublic;
      githubController.text = githubUsernameFromUrl(bundle.social.github);
      cvController.text = bundle.social.cv ?? '';
      _selectedLanguages = bundle.social.languages.toSet();
      _loading = false;
      _notify();
      await _syncPreferences(bundle.settings.language, bundle.settings.theme);
      return;
    } on ApiError catch (error) {
      _error = error.message;
      _loading = false;
    } catch (_) {
      _error = _tx('profile.load_error', 'No se pudo cargar el perfil');
      _loading = false;
    }
    _notify();
  }

  Future<ActionResult?> saveSettings() async {
    final token = this.token;
    if (token == null || token.isEmpty) return null;

    _savingSettings = true;
    _notify();
    try {
      final updated = await _repository.updateSettings(
        token,
        theme: _themeConfigurable ? _theme : null,
        language: _language,
      );
      _theme = updated.theme;
      _defaultTheme = updated.defaultTheme;
      _themeConfigurable = updated.themeConfigurable;
      _language = updated.language;
      await _syncPreferences(updated.language, updated.theme);
      return ActionResult(
        _tx('profile.preferences_saved', 'Preferencias guardadas'),
      );
    } on ApiError catch (error) {
      return ActionResult.error(error.message);
    } catch (_) {
      return ActionResult.error(
        _tx(
          'profile.preferences_error',
          'No se pudieron guardar las preferencias',
        ),
      );
    } finally {
      _savingSettings = false;
      _notify();
    }
  }

  Future<ActionResult?> savePublicProfile() async {
    final token = this.token;
    if (token == null || token.isEmpty) return null;

    _savingProfile = true;
    _notify();
    try {
      await _repository.updateSocialProfile(
        token,
        bio: bioController.text.trim(),
        isEmailPublic: _isEmailPublic,
        github: githubUrlFromUsername(githubController.text) ?? '',
        cv: cvController.text.trim(),
        languages: _selectedLanguages.toList(),
      );
      // Recarga para quedarse con lo que el backend normalizó, no con el
      // borrador local.
      await load();
      return ActionResult(
        _tx('profile.social_saved', 'Perfil público actualizado'),
      );
    } on ApiError catch (error) {
      return ActionResult.error(error.message);
    } catch (_) {
      return ActionResult.error(
        _tx('profile.social_error', 'No se pudo actualizar el perfil público'),
      );
    } finally {
      _savingProfile = false;
      _notify();
    }
  }

  /// Sube la foto ya elegida. La página se encarga del selector de archivos
  /// (es UI de plataforma); aquí se comprime en un isolate aparte, se valida
  /// y se envía.
  Future<ActionResult?> uploadAvatar({
    required String fileName,
    required List<int>? fileBytes,
  }) async {
    final token = this.token;
    if (token == null || token.isEmpty) return null;

    if (fileBytes == null || fileBytes.isEmpty) {
      return ActionResult.error(
        _tx('profile.avatar_error', 'No se pudo actualizar la foto'),
      );
    }
    if (fileBytes.length > maxAvatarInputBytes) {
      return ActionResult.error(
        _tx(
          'profile.avatar_input_too_large',
          'La imagen original es demasiado grande',
        ),
      );
    }

    _uploadingAvatar = true;
    _notify();
    try {
      final compressed = await compute(
        compressAvatarBytes,
        AvatarCompressionInput(Uint8List.fromList(fileBytes)),
      );
      if (compressed.bytes.length > maxAvatarBytes) {
        return ActionResult.error(
          _tx('profile.avatar_too_large', 'La imagen no puede superar 10 MB'),
        );
      }

      await _repository.uploadAvatar(
        token,
        fileName: compressed.fileName,
        fileBytes: compressed.bytes,
      );
      _avatarVersion++;
      return ActionResult(
        _tx('profile.avatar_updated', 'Foto de perfil actualizada'),
      );
    } on AvatarCompressionException {
      return ActionResult.error(
        _tx('profile.avatar_error', 'No se pudo actualizar la foto'),
      );
    } on ApiError catch (error) {
      return ActionResult.error(error.message);
    } catch (_) {
      return ActionResult.error(
        _tx('profile.avatar_error', 'No se pudo actualizar la foto'),
      );
    } finally {
      _uploadingAvatar = false;
      _notify();
    }
  }

  /// Devuelve siempre un resultado: el diálogo se cierra sólo si
  /// [ActionResult.isError] es `false`.
  Future<ActionResult> changePassword() async {
    final token = this.token;
    if (token == null || token.isEmpty) {
      return ActionResult.error(
        _tx('common.no_session', 'No hay sesión activa'),
      );
    }

    final current = currentPasswordController.text;
    final next = newPasswordController.text;
    if (current.isEmpty || next.isEmpty) {
      return ActionResult.error(
        _tx('profile.password_required', 'Completa contraseña actual y nueva'),
      );
    }
    if (next.trim().length < minPasswordLength) {
      return ActionResult.error(
        _tx(
          'profile.password_too_short',
          'La nueva contraseña debe tener al menos 8 caracteres',
        ),
      );
    }

    try {
      await _repository.changePassword(
        token,
        currentPassword: current,
        newPassword: next,
      );
      currentPasswordController.clear();
      newPasswordController.clear();
      return ActionResult(
        _tx('profile.password_updated', 'Contraseña actualizada'),
      );
    } on ApiError catch (error) {
      return ActionResult.error(error.message);
    } catch (_) {
      return ActionResult.error(
        _tx('profile.password_error', 'No se pudo actualizar la contraseña'),
      );
    }
  }

  /// `true` si procede pedir confirmación antes de llamar a [requestDeletion].
  bool get canRequestDeletion {
    final token = this.token;
    if (token == null || token.isEmpty) return false;
    final bundle = _bundle;
    return bundle != null && !bundle.deletion.scheduled;
  }

  /// Mensaje para cuando la eliminación ya estaba pedida. La página lo muestra
  /// sin abrir el diálogo de confirmación.
  ActionResult get deletionAlreadyScheduled => ActionResult(
    _tx(
      'profile.deletion_already_scheduled',
      'La cuenta ya está programada para eliminación',
    ),
  );

  Future<ActionResult?> requestDeletion() async {
    final token = this.token;
    if (token == null || token.isEmpty) return null;

    _requestingDeletion = true;
    _notify();
    try {
      final message = await _repository.requestDeletion(token);
      await load();
      return ActionResult(message);
    } on ApiError catch (error) {
      return ActionResult.error(error.message);
    } catch (_) {
      return ActionResult.error(
        _tx(
          'profile.deletion_error',
          'No se pudo programar la eliminación de cuenta',
        ),
      );
    } finally {
      _requestingDeletion = false;
      _notify();
    }
  }

  Future<void> _syncPreferences(String language, String theme) async {
    // El idioma se esperaba igual que el tema: sin el await, quien llame a
    // esto podía continuar con la preferencia de idioma aún sin persistir.
    await _localeController.syncFromBackend(language);
    await _syncTheme(theme);
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    bioController.dispose();
    githubController.dispose();
    cvController.dispose();
    currentPasswordController.dispose();
    newPasswordController.dispose();
    super.dispose();
  }
}
