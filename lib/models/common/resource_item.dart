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
  String get resourceType => raw['resource_type'] as String? ?? '';
  String get createdAt => raw['created_at'] as String? ?? '';
  String get updatedAt => raw['updated_at'] as String? ?? '';

  /// Llega de un group share ajeno: no soy el dueño.
  bool get shared => raw['_shared'] == true;

  /// Solo-lectura si es un recurso compartido por otro.
  bool get readOnly => shared;

  /// Activo por defecto: tolera respuestas de un backend anterior a is_active.
  bool get isActive => raw['is_active'] != false;

  String? get deactivatedAt => raw['deactivated_at'] as String?;

  List<String> get labels {
    final value = raw['labels'];
    if (value is List) return value.map((item) => item.toString()).toList();
    return const ['private'];
  }
}
