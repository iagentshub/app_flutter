import 'api_client.dart';

/// Base mínima para repositorios que comparten el mismo cliente HTTP.
///
/// No contiene lógica de dominio: únicamente hace explícita la dependencia
/// común y permite constructores `super.apiClient` consistentes.
abstract class ApiRepository {
  const ApiRepository({required this.apiClient});

  final ApiClient apiClient;

  /// Activa o desactiva (borrado suave) un recurso vía el endpoint común
  /// `POST /api/{basePath}/{id}/activate|deactivate`.
  ///
  /// `basePath` es la ruta del recurso sin barras extremas, p. ej.
  /// `'agents'`, `'skills'`, `'connections'`, `'knowledge'`, `'workflows'`.
  Future<void> setActive(
    String token,
    String basePath,
    String id,
    bool active,
  ) async {
    final action = active ? 'activate' : 'deactivate';
    await apiClient.post(
      '/api/$basePath/${Uri.encodeComponent(id)}/$action',
      gaToken: token,
    );
  }
}
