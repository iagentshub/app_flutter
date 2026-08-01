import 'dart:convert';

import '../../../core/network/api_repository.dart';

/// Cliente de Centinel: test runner funcional (pytest), prueba de estrés y
/// "buscar límite" (probe) de Centinel.
class CentinelRepository extends ApiRepository {
  CentinelRepository({required super.apiClient});

  static const _base = '/api/admin/centinel';

  // ── Funcional (pytest) ────────────────────────────────────────────────

  Future<Map<String, dynamic>> status(String token) async {
    final response = await apiClient.get('$_base/status', gaToken: token);
    return response.json;
  }

  Future<Map<String, dynamic>> tree(String token) async {
    final response = await apiClient.get('$_base/tree', gaToken: token);
    return response.json;
  }

  Future<Map<String, dynamic>> run(
    String token, {
    String target = 'tests/',
    bool rerunFailed = false,
  }) async {
    final response = await apiClient.post(
      '$_base/run',
      gaToken: token,
      body: {'target': target, 'rerun_failed': rerunFailed},
    );
    return response.json;
  }

  Future<void> abort(String token) async {
    await apiClient.delete('$_base/run', gaToken: token);
  }

  Future<List<Map<String, dynamic>>> history(String token) async {
    final response = await apiClient.get('$_base/history', gaToken: token);
    final payload = response.body;
    if (payload is! List) return const [];
    return payload.whereType<Map<String, dynamic>>().toList();
  }

  /// Eventos del run en curso (o replay si ya terminó): started, collecting,
  /// test, summary, done, aborted, error.
  Stream<Map<String, dynamic>> stream(String token, String runId) {
    return _decodeSse(
      apiClient.getStream('$_base/stream/$runId', gaToken: token),
    );
  }

  // ── Rendimiento (stress test) ────────────────────────────────────────

  Future<Map<String, dynamic>> stressStatus(String token) async {
    final response = await apiClient.get(
      '$_base/stress/status',
      gaToken: token,
    );
    return response.json;
  }

  Future<Map<String, dynamic>> stressRun(
    String token,
    Map<String, dynamic> config,
  ) async {
    final response = await apiClient.post(
      '$_base/stress/run',
      gaToken: token,
      body: config,
    );
    return response.json;
  }

  Future<void> stressAbort(String token) async {
    await apiClient.delete('$_base/stress/run', gaToken: token);
  }

  /// Eventos: stress_started, stress_tick (1/s), stress_done, stress_abort,
  /// stress_error.
  Stream<Map<String, dynamic>> stressStream(String token, String runId) {
    return _decodeSse(
      apiClient.getStream('$_base/stress/stream/$runId', gaToken: token),
    );
  }

  // ── Buscar límite (probe) ────────────────────────────────────────────

  Future<Map<String, dynamic>> probeStatus(String token) async {
    final response = await apiClient.get('$_base/stress/probe', gaToken: token);
    return response.json;
  }

  Future<Map<String, dynamic>> probeStart(
    String token,
    Map<String, dynamic> config,
  ) async {
    final response = await apiClient.post(
      '$_base/stress/probe',
      gaToken: token,
      body: config,
    );
    return response.json;
  }

  Future<void> probeAbort(String token) async {
    await apiClient.delete('$_base/stress/probe', gaToken: token);
  }

  Stream<Map<String, dynamic>> _decodeSse(Stream<String> lines) async* {
    await for (final line in lines) {
      if (!line.startsWith('data: ')) continue;
      final raw = line.substring(6).trim();
      if (raw.isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) yield decoded;
      } catch (_) {
        // Comentarios keep-alive (": ping") u otras líneas no-JSON.
      }
    }
  }
}
