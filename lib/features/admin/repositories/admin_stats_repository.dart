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

  Future<AdminExploreResult> explore(String token) async {
    const pageSize = 200;
    var offset = 0;
    var total = 0;
    var counts = const <AdminResourceType, int>{};
    final items = <AdminExploreItem>[];
    do {
      final response = await apiClient.get(
        '/api/admin/explore?limit=$pageSize&offset=$offset',
        gaToken: token,
      );
      final page = AdminExploreResult.fromJson(response.json);
      total = page.total;
      counts = page.counts;
      items.addAll(page.items);
      offset += page.items.length;
      if (page.items.isEmpty) break;
    } while (items.length < total);
    return AdminExploreResult(items: items, total: total, counts: counts);
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
