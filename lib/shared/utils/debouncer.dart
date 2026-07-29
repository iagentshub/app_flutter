import 'dart:async';

/// Retrasa la ejecución de `action` hasta que pasen `delay` sin que se
/// vuelva a llamar a `run` — para no recalcular el filtro ni reconstruir
/// la lista en cada pulsación de un campo de búsqueda en vivo.
class Debouncer {
  Debouncer({this.delay = const Duration(milliseconds: 300)});

  final Duration delay;
  Timer? _timer;

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() {
    _timer?.cancel();
  }
}
