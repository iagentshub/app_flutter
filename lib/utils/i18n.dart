import 'package:flutter/foundation.dart';

/// Traducción por identificador, accesible desde cualquier punto de la app.
///
/// ```dart
/// Text(tr('workflows.run_cancelling'))
/// ```
///
/// **Un solo argumento: el identificador.** Antes cada llamada llevaba además
/// el texto en español —`_tx('clave')`— y eso tenía dos costes.
/// El visible: cada cadena vivía en dos sitios, el JSON y la llamada, y al
/// cambiar una se olvidaba la otra. El grave: **una clave sin declarar no se
/// notaba**, porque la app enseñaba ese texto de respaldo y en inglés seguía
/// saliendo en español. Así se colaron 24 claves, entre ellas los botones de
/// activar y desactivar recursos, en cuatro pantallas.
///
/// Si la clave no está, [tr] devuelve **el propio identificador** —feo a
/// propósito, para que se vea y se arregle— y deja un aviso en consola. La
/// guarda `test/i18n_claves_existentes_test.dart` lo caza antes, en CI.
String tr(String id) => I18n.resolve(id);

/// Traducción de una clave **dinámica**, con la alternativa a mostrar si no
/// existe.
///
/// Es la excepción a «un solo argumento», y la única legítima: aquí la clave se
/// construye en tiempo de ejecución —`trOr('labels.$etiqueta', etiqueta)`— con
/// nombres que el usuario inventa, así que la ausencia es lo normal y no un
/// olvido. No avisa por consola por eso mismo, y por eso mismo tampoco puede
/// devolver el identificador: enseñaría `labels.mi_etiqueta` en vez de
/// `mi_etiqueta`.
///
/// Si la clave es literal, esta no es la función: es [tr].
String trOr(String id, String alternativa) => I18n.resolveOr(id, alternativa);

/// Traduce un código estable del backend y conserva su mensaje como fallback.
///
/// Los errores HTTP y SSE comparten el namespace global `errors`: de este
/// modo el idioma visible no depende del texto de respaldo enviado por el
/// servidor y los códigos nuevos siguen siendo compatibles hasta que el
/// cliente incorpore su traducción.
String trErrorOr(String? code, String fallback) {
  if (code == null || code.isEmpty) return fallback;
  return I18n.resolveOrEn('errors', code, fallback);
}

/// Los bundles de traducción del idioma activo.
///
/// Vive aquí, en `utils/`, y no en la capa de i18n, porque [tr] tiene que
/// poder llamarse desde cualquier widget sin recibir el bundle por parámetro ni
/// depender del `BuildContext`.
///
/// Los bundles los registra [TranslatedTexts] al cargar el namespace de cada
/// página: la app no carga los cinco de golpe, sino el que necesita quien se
/// abre. Por eso la resolución busca en todos los registrados — las claves
/// llevan su sección delante (`workflows.`, `admin.`, `common.`) y no chocan;
/// `test/i18n_claves_existentes_test.dart` comprueba que sigue siendo así.
abstract final class I18n {
  static final Map<String, Map<String, dynamic>> _bundles = {};
  static final Set<String> _avisadas = {};

  /// Registra el bundle de un namespace. Reemplaza el anterior: al cambiar de
  /// idioma llega el mismo namespace con otro contenido.
  static void registrar(String namespace, Map<String, dynamic> bundle) {
    _bundles[namespace] = bundle;
  }

  /// Olvida lo cargado. Solo lo necesitan los tests, que comparten proceso.
  @visibleForTesting
  static void limpiar() {
    _bundles.clear();
    _avisadas.clear();
  }

  static String resolve(String id) {
    for (final bundle in _bundles.values) {
      final valor = _buscar(bundle, id);
      if (valor != null) return valor;
    }
    return _falta(id);
  }

  /// Como [resolve], pero con alternativa explícita y sin avisar: la usa
  /// [trOr] para claves construidas en tiempo de ejecución.
  static String resolveOr(String id, String alternativa) {
    for (final bundle in _bundles.values) {
      final valor = _buscar(bundle, id);
      if (valor != null) return valor;
    }
    return alternativa;
  }

  /// Resuelve una clave dentro de un namespace concreto con fallback.
  ///
  /// Los códigos de API viven en `errors.json` y no llevan el namespace en el
  /// payload. Consultarlos de forma acotada evita colisiones con claves de UI
  /// que puedan llamarse igual en otros bundles.
  static String resolveOrEn(String namespace, String id, String alternativa) {
    final bundle = _bundles[namespace];
    if (bundle == null) return alternativa;
    return _buscar(bundle, id) ?? alternativa;
  }

  /// Resuelve mirando primero un bundle concreto —el de la página, que es el
  /// que casi siempre tiene la clave— y después los demás registrados.
  ///
  /// El segundo paso importa más de lo que parece: el bundle de una página se
  /// carga de forma asíncrona, así que en el primer fotograma —y en los tests,
  /// donde nadie espera a esa carga— todavía está vacío. Antes eso no se veía
  /// porque salía el texto de respaldo; ahora saldría el identificador.
  static String resolveEn(Map<String, dynamic> bundle, String id) =>
      _buscar(bundle, id) ?? resolve(id);

  static String? _buscar(Map<String, dynamic> bundle, String id) {
    dynamic actual = bundle;
    for (final tramo in id.split('.')) {
      if (actual is Map && actual.containsKey(tramo)) {
        actual = actual[tramo];
      } else {
        return null;
      }
    }
    return actual is String ? actual : null;
  }

  /// El aviso sale una vez por clave, no en cada repintado.
  static String _falta(String id) {
    if (kDebugMode && _avisadas.add(id)) {
      debugPrint('[i18n] - NOT FOUND «$id» in assets/locales/');
    }
    return id;
  }
}
