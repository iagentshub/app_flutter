import 'api_client.dart';

/// Base mínima para repositorios que comparten el mismo cliente HTTP.
///
/// No contiene lógica de dominio: únicamente hace explícita la dependencia
/// común y permite constructores `super.apiClient` consistentes.
abstract class ApiRepository {
  const ApiRepository({required this.apiClient});

  final ApiClient apiClient;
}
