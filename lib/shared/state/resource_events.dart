import 'package:flutter/foundation.dart';

/// Aviso de que un tipo de recurso cambió en el servidor.
///
/// El tipo es la raíz de la ruta que se mutó (`/api/agents/...` → `agents`),
/// la misma noción que usa la caché del cliente HTTP para invalidarse: si una
/// petición ensucia la caché de un recurso, ensucia también lo que las
/// pantallas están enseñando de él.
@immutable
class ResourceChange {
  const ResourceChange(this.resourceType);

  final String resourceType;

  @override
  bool operator ==(Object other) =>
      other is ResourceChange && other.resourceType == resourceType;

  @override
  int get hashCode => resourceType.hashCode;

  @override
  String toString() => 'ResourceChange($resourceType)';
}

/// Punto único por el que pasa «este recurso cambió».
///
/// Antes cada pantalla recargaba por su cuenta después de mutar, así que dos
/// vistas del mismo recurso se desincronizaban: la que hacía el cambio se
/// enteraba y las demás seguían enseñando su copia hasta que alguien pulsaba
/// actualizar. Ese es el patrón que hace aparecer regresiones en la pantalla
/// que nadie tocó.
///
/// Quien muta no tiene que acordarse de avisar: lo emite el cliente HTTP en
/// cada mutación con éxito. Quien pinta se suscribe con
/// `WatchesResourceChanges` y recarga.
class ResourceEvents extends ChangeNotifier {
  final Set<String> _pending = {};
  bool _scheduled = false;

  /// Tipos avisados en la notificación en curso.
  Set<String> get pending => Set.unmodifiable(_pending);

  /// Registra un cambio. Los avisos del mismo ciclo se agrupan: guardar un
  /// agente toca su recurso y sus etiquetas, y no tiene sentido que las
  /// pantallas recarguen dos veces por una sola acción del usuario.
  void changed(String resourceType) {
    if (resourceType.isEmpty) return;
    _pending.add(resourceType);
    if (_scheduled) return;
    _scheduled = true;
    Future.microtask(_flush);
  }

  void _flush() {
    _scheduled = false;
    if (_pending.isEmpty) return;
    notifyListeners();
    _pending.clear();
  }

  /// Emite de inmediato, sin esperar al agrupado. Para pruebas.
  @visibleForTesting
  void flushNow() => _flush();

  /// Deriva el tipo de recurso de una ruta de la API.
  ///
  /// `/api/agents/private/ag-1` → `agents`. Comparte la regla con la caché:
  /// dos segmentos, porque `/api/knowledge/packs` y `/api/knowledge` son el
  /// mismo recurso para quien lo enseña.
  static String typeFromPath(String path) {
    final segments = path
        .split('?')
        .first
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (segments.length < 2) return '';
    return segments[1];
  }
}
