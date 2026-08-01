/// Base común de todos los recursos que el usuario crea y gestiona
/// (agentes, skills, conexiones, conocimientos, workflows).
///
/// Espejo de `BaseResource` del backend. Cada modelo concreto extiende esta
/// clase y solo declara sus getters propios; los comunes (id, name, labels,
/// scope, owner, fechas, is_active…) viven aquí, sin duplicarse.
abstract class ResourceItem {
  const ResourceItem({required this.raw});

  final Map<String, dynamic> raw;

  String get id => raw['id'] as String? ?? '';
  String get name => raw['name'] as String? ?? '(sin nombre)';
  String get description => raw['description'] as String? ?? '';
  String get scope => raw['scope'] as String? ?? 'private';
  String get ownerId => raw['owner_id'] as String? ?? '';
  String get ownerUsername => raw['owner_username'] as String? ?? '';
  String get resourceType => raw['resource_type'] as String? ?? '';
  String get createdAt => raw['created_at'] as String? ?? '';
  String get updatedAt => raw['updated_at'] as String? ?? '';

  /// Llega de un group share ajeno: no soy el dueño.
  bool get shared => raw['_shared'] == true;

  /// Solo-lectura si es un recurso compartido por otro.
  bool get readOnly => shared;

  /// Activo por defecto: tolera respuestas anteriores a `is_active` y acepta
  /// tanto el booleano de la API como el flag entero 0/1 de persistencia.
  bool get isActive {
    final value = raw['is_active'];
    if (value is bool) return value;
    if (value is num) return value != 0;
    return true;
  }

  String? get deactivatedAt => raw['deactivated_at'] as String?;

  List<String> get labels {
    final value = raw['labels'];
    if (value is List) return value.map((item) => item.toString()).toList();
    return const ['private'];
  }
}
