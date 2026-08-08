import 'package:flutter/widgets.dart';

import '../../core/network/api_error.dart';

/// Ciclo de vida de un listado remoto: cargando, error y datos.
///
/// Veinte páginas repetían el mismo esqueleto —campos `_loading`, `_error` y
/// la lista; un `_load()` con `setState` al empezar, `try`, `if (!mounted)
/// return`, `setState` con los datos, `on ApiError` con el mensaje, `catch`
/// con un genérico traducido y `_loading = false` en los tres caminos—: unas
/// 35 líneas por página, más de 600 en total, y las diferencias entre copias
/// eran accidentales. Unas comprobaban la sesión y otras no; unas conservaban
/// los datos viejos al fallar una recarga y otras los borraban, dejando la
/// vista vacía.
///
/// Aquí esa política se fija una vez: **al fallar se conservan los datos
/// anteriores**. Un error de red en una recarga no debe vaciar lo que el
/// usuario ya estaba mirando.
class AsyncSection<T> extends ChangeNotifier {
  AsyncSection({required this.fetch, required this.genericError});

  /// Petición que trae los datos. Se vuelve a llamar en cada [load].
  final Future<T> Function() fetch;

  /// Mensaje para un fallo que no es un [ApiError] (sin red, respuesta
  /// ilegible). Es una función para que se resuelva con el idioma vigente en
  /// el momento del error, no con el de cuando se creó la sección.
  final String Function() genericError;

  T? _data;
  T? get data => _data;

  bool _loading = true;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  /// Si ya hay datos que enseñar mientras se recarga o tras un fallo.
  bool get hasData => _data != null;

  bool _disposed = false;

  Future<void> load() async {
    _loading = true;
    _error = null;
    _notify();
    try {
      final resultado = await fetch();
      if (_disposed) return;
      _data = resultado;
    } on ApiError catch (error) {
      _error = error.message;
    } catch (_) {
      _error = genericError();
    } finally {
      _loading = false;
      _notify();
    }
  }

  /// Reemplaza los datos sin pasar por la red — para cuando la propia página
  /// acaba de crear o borrar un elemento y ya sabe el resultado.
  void setData(T value) {
    _data = value;
    _error = null;
    _notify();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
