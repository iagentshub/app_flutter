import '../../../core/network/api_repository.dart';
import '../../../models/admin/admin_explore_models.dart';

class AdminStats {
  const AdminStats({required this.raw});

  final Map<String, dynamic> raw;

  int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  int get usersTotal => _asInt(raw['users_total']);
  int get usersActive => _asInt(raw['users_active']);
  int get usersVerified => _asInt(raw['users_verified']);

  /// Invitados con sesión abierta ahora mismo, y el tope del clúster.
  ///
  /// Van aparte de `usersTotal` a propósito: son cuentas efímeras que se borran
  /// solas, y mezclarlas haría subir y bajar el total sin que nadie se dé de
  /// alta. Pero son las que consumen el cupo del demo, y cuando se llena el
  /// alta responde 503 sin que nada más lo explique.
  int get guestsActive => _asInt(raw['guests_active']);
  int get guestsMax => _asInt(raw['guests_max']);
  int get connectionsTotal => _asInt(raw['connections_total']);
  int get workflowsTotal => _asInt(raw['workflows_total']);
  int get knowledgeTotal => _asInt(raw['knowledge_total']);
  int get conversationsTotal => _asInt(raw['conversations_total']);
  int get agentsPublic => _asInt(raw['agents_public']);
  int get agentsPrivate => _asInt(raw['agents_private']);

  int get requestsToday => _asInt(raw['requests_today']);
  int get errorsToday => _asInt(raw['errors_today']);
  double get failureRatePct =>
      (raw['failure_rate_pct'] as num?)?.toDouble() ?? 0.0;
  int get avgLatencyMs => _asInt(raw['avg_latency_ms']);
  String? get topErrorEndpoint => raw['top_error_endpoint'] as String?;
  int get topErrorCount => _asInt(raw['top_error_count']);

  // Salud del host — None cuando el backend no pudo leer la métrica (p.ej.
  // memoria fuera de Linux); ver _server_health() en admin.py.
  double? get diskUsedPct => (raw['disk_used_pct'] as num?)?.toDouble();
  double? get diskUsedGb => (raw['disk_used_gb'] as num?)?.toDouble();
  double? get diskTotalGb => (raw['disk_total_gb'] as num?)?.toDouble();
  double? get memoryUsedPct => (raw['memory_used_pct'] as num?)?.toDouble();
  double? get memoryUsedGb => (raw['memory_used_gb'] as num?)?.toDouble();
  double? get memoryTotalGb => (raw['memory_total_gb'] as num?)?.toDouble();
  double? get cpuLoadPct => (raw['cpu_load_pct'] as num?)?.toDouble();
  int? get cpuCores =>
      raw['cpu_cores'] == null ? null : _asInt(raw['cpu_cores']);
}

/// KPIs del dashboard de Admin (`/api/admin/stats`) y el listado paginado de
/// `/api/admin/explore` que alimenta tanto el resumen por tipo de recurso
/// como las pestañas Usuarios/Grupos/Agentes/... (ver `AdminExploreResult`).
class AdminStatsRepository extends ApiRepository {
  AdminStatsRepository({required super.apiClient});

  Future<AdminExploreResult> explorePage(
    String token, {
    String? cursor,
    String query = '',
    Set<AdminResourceType> types = const {},
    String owner = '',
    String role = '',
    String active = '',
    String verified = '',
    String knowledgeType = '',
    int limit = 100,
  }) async {
    final params = <String, dynamic>{
      'limit': '$limit',
      'include_total': 'true',
      'include_counts': 'true',
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      if (query.trim().isNotEmpty) 'q': query.trim(),
      if (types.isNotEmpty) 'type': types.map((type) => type.wireName).toList(),
      if (owner.isNotEmpty) 'owner': owner,
      if (role.isNotEmpty) 'role': role,
      if (active.isNotEmpty) 'active': active,
      if (verified.isNotEmpty) 'verified': verified,
      if (knowledgeType.isNotEmpty) 'knowledge_type': knowledgeType,
    };
    final response = await apiClient.get(
      Uri(path: '/api/v2/admin/explore', queryParameters: params).toString(),
      gaToken: token,
    );
    return AdminExploreResult.fromJson(response.json);
  }

  Future<AdminStats> getStats(String token) async {
    final response = await apiClient.get(
      '/api/admin/stats',
      gaToken: token,
      cache: true,
    );
    return AdminStats(raw: response.json);
  }
}
