import 'package:flutter/foundation.dart';

/// Cachea el resultado de un cálculo mientras sus entradas no cambien.
///
/// Las listas filtradas de las páginas eran getters que hacían
/// `.where(...).toList()` sobre la colección completa y se leían dentro de
/// `build`: se recorrían y se copiaban enteras en cada `setState` —al escribir
/// en el buscador, al cambiar de pestaña, al abrir un menú, al llegar una
/// traducción—, y la búsqueda además hace `toLowerCase()` por elemento y
/// campo. Con treinta recursos no se nota; con varios cientos, sí.
///
/// Uso:
/// ```dart
/// final _filtrados = Memoized<List<AgentItem>>();
///
/// List<AgentItem> get _filteredAgents =>
///     _filtrados.of([_agents, _scope, _query], () => _agents.where(...).toList());
/// ```
///
/// Las dependencias se comparan con `==`, así que una colección cuenta como
/// dependencia por identidad: sirve mientras la lista se reemplace al
/// recargar (`_agents = [...]`) en vez de mutarse en el sitio.
class Memoized<T> {
  List<Object?>? _deps;
  late T _value;
  bool _hasValue = false;

  T of(List<Object?> deps, T Function() compute) {
    if (_hasValue && listEquals(_deps, deps)) return _value;
    _deps = List<Object?>.of(deps);
    _value = compute();
    _hasValue = true;
    return _value;
  }
}
