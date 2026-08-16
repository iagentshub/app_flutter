import '../../core/network/api_repository.dart';

/// Comparte/descomparte un recurso con uno o varios grupos (groups) —
/// un recurso puede estar compartido con varios grupos a la vez
/// (`resource_group_shares` es una relación N a N en el backend).
class SharingRepository extends ApiRepository {
  SharingRepository({required super.apiClient});

  /// IDs de los grupos que ya tienen acceso al recurso.
  Future<List<String>> listGroups(
    String token, {
    required String resourceType,
    required String resourceId,
  }) async {
    final response = await apiClient.get(
      '/api/sharing/$resourceType/${Uri.encodeComponent(resourceId)}/groups',
      gaToken: token,
    );
    final ids = response.json['group_ids'];
    if (ids is! List) return const [];
    return ids.map((e) => e.toString()).toList();
  }

  Future<void> share(
    String token, {
    required String resourceType,
    required String resourceId,
    required String groupId,
  }) async {
    await apiClient.post(
      '/api/sharing/$resourceType/${Uri.encodeComponent(resourceId)}',
      gaToken: token,
      body: {'group_id': groupId},
    );
  }

  /// Retira el acceso del grupo y devuelve qué dependencias se conservaron.
  ///
  /// Al descompartir un agente, el servidor retira también lo que ese agente
  /// arrastró al compartirse, salvo lo que otro recurso compartido del grupo
  /// siga necesitando. Esa lista es lo único que el usuario no puede deducir
  /// de la pantalla, así que sube hasta la interfaz.
  Future<UnshareResult> unshare(
    String token, {
    required String resourceType,
    required String resourceId,
    required String groupId,
  }) async {
    final response = await apiClient.delete(
      '/api/sharing/$resourceType/${Uri.encodeComponent(resourceId)}?group_id=${Uri.encodeQueryComponent(groupId)}',
      gaToken: token,
    );
    final payload = response.json;
    return UnshareResult(
      uncascaded: _ids(payload['uncascaded']),
      kept: _ids(payload['kept']),
    );
  }

  List<String> _ids(Object? raw) => raw is List
      ? raw.map((e) => e.toString()).toList(growable: false)
      : const [];
}

/// Resultado de retirar un recurso de un grupo.
class UnshareResult {
  const UnshareResult({required this.uncascaded, required this.kept});

  /// Dependencias que han dejado de estar compartidas con el grupo.
  final List<String> uncascaded;

  /// Dependencias que siguen compartidas porque otro recurso las necesita.
  final List<String> kept;
}
