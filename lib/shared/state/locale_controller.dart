import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;

import '../../core/storage/local_store.dart';

/// Idioma de la app, compartido por toda la UI (nav, login, etc.). Se
/// persiste localmente para que sobreviva a reinicios y se sincroniza con
/// la preferencia guardada en el backend (`/api/settings`) al iniciar
/// sesión o al guardar cambios en Profile.
///
/// El idioma se guarda como código ISO, no como un `bool isEnglish`: ese
/// booleano viajaba por veinte ficheros y añadir un tercer idioma obligaba a
/// tocar la firma de todo lo que lo pasaba, cuando la infraestructura de
/// traducción (un directorio por idioma en `assets/locales/`) ya lo admite.
class LocaleController extends ChangeNotifier {
  LocaleController._(this._languageCode);

  static const _key = 'app_language';

  /// Idioma por defecto cuando no hay preferencia guardada ni la reportada
  /// por el backend es reconocible.
  static const fallbackLanguageCode = 'es';

  /// Idiomas con bundle en `assets/locales/`. Añadir uno nuevo es crear su
  /// directorio y sumar el código aquí.
  static const supportedLanguageCodes = ['es', 'en'];

  /// Nombre nativo de cada idioma, para los selectores. Vive junto a la lista
  /// de arriba para que añadir un idioma siga siendo **un solo sitio**: las
  /// pantallas que ofrecen el cambio los recorren, en vez de escribir una
  /// opción por idioma a mano.
  static const languageNames = <String, String>{
    'es': 'Español',
    'en': 'English',
  };

  /// Nombre del idioma, o su código en mayúsculas si aún no tiene nombre.
  static String languageName(String code) =>
      languageNames[code] ?? code.toUpperCase();

  String _languageCode;
  String get languageCode => _languageCode;

  Locale get locale => Locale(_languageCode);

  static Future<LocaleController> bootstrap() async {
    final prefs = await LocalStore.instance();
    return LocaleController._(_normalize(prefs.getString(_key)));
  }

  Future<void> setLanguage(String languageCode) async {
    final normalized = _normalize(languageCode);
    if (_languageCode == normalized) return;
    _languageCode = normalized;
    notifyListeners();
    final prefs = await LocalStore.instance();
    await prefs.setString(_key, normalized);
  }

  /// Aplica el idioma reportado por el backend (p. ej. tras login o al
  /// cargar Profile), sin distinguir mayúsculas/minúsculas.
  Future<void> syncFromBackend(String? languageCode) async {
    if (languageCode == null || languageCode.isEmpty) return;
    await setLanguage(languageCode);
  }

  /// Un idioma desconocido —o una preferencia antigua con otro formato— cae
  /// al idioma por defecto en vez de dejar la app sin traducciones.
  static String _normalize(String? raw) {
    if (raw == null || raw.isEmpty) return fallbackLanguageCode;
    final code = raw.toLowerCase().split(RegExp('[_-]')).first;
    return supportedLanguageCodes.contains(code) ? code : fallbackLanguageCode;
  }
}
