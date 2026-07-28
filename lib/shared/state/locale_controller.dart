import 'package:flutter/foundation.dart';

import '../../core/storage/local_store.dart';

/// Idioma de la app, compartido por toda la UI (nav, login, etc.). Se
/// persiste localmente para que sobreviva a reinicios y se sincroniza con
/// la preferencia guardada en el backend (`/api/settings`) al iniciar
/// sesión o al guardar cambios en Profile.
class LocaleController extends ChangeNotifier {
  LocaleController._(this._isEnglish);

  static const _key = 'app_language';

  bool _isEnglish;
  bool get isEnglish => _isEnglish;

  static Future<LocaleController> bootstrap() async {
    final prefs = await LocalStore.instance();
    final lang = prefs.getString(_key);
    return LocaleController._(lang == 'en');
  }

  Future<void> setEnglish(bool value) async {
    if (_isEnglish == value) return;
    _isEnglish = value;
    notifyListeners();
    final prefs = await LocalStore.instance();
    await prefs.setString(_key, value ? 'en' : 'es');
  }

  /// Aplica el idioma reportado por el backend (p. ej. tras login o al
  /// cargar Profile), sin distinguir mayúsculas/minúsculas.
  Future<void> syncFromBackend(String? languageCode) async {
    if (languageCode == null || languageCode.isEmpty) return;
    await setEnglish(languageCode.toLowerCase() == 'en');
  }
}
