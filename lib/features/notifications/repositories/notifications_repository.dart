import '../../../core/network/api_repository.dart';

/// Avisos del usuario: los que enciende la campana de la barra superior.
class NotificationsRepository extends ApiRepository {
  NotificationsRepository({required super.apiClient});

  /// Lista y contador en la misma respuesta.
  ///
  /// Sin caché a propósito: este es el sondeo periódico, y servirle la
  /// respuesta anterior dejaría el contador congelado, que es justo lo único
  /// que esta llamada existe para mover.
  Future<({List<Map<String, dynamic>> items, int unread})> list(
    String token,
  ) async {
    final response = await apiClient.get(
      '/api/notifications',
      gaToken: token,
    );
    final payload = response.body;
    if (payload is! Map<String, dynamic>) {
      return (items: const <Map<String, dynamic>>[], unread: 0);
    }
    final items = payload['items'];
    return (
      items: items is List
          ? items.whereType<Map<String, dynamic>>().toList()
          : const <Map<String, dynamic>>[],
      unread: (payload['unread'] as num?)?.toInt() ?? 0,
    );
  }

  /// La clave pública VAPID de la instalación, o vacía si no hay push.
  ///
  /// Se consulta antes de ofrecer el interruptor: enseñar uno que no puede
  /// funcionar es peor que no enseñarlo.
  Future<String> pushKey(String token) async {
    final response = await apiClient.get(
      '/api/notifications/push/key',
      gaToken: token,
    );
    final payload = response.body;
    if (payload is! Map<String, dynamic>) return '';
    return '${payload['key'] ?? ''}';
  }

  Future<void> subscribePush(String token, Map<String, String> datos) async {
    await apiClient.post(
      '/api/notifications/push/subscribe',
      gaToken: token,
      body: datos,
    );
  }

  Future<void> unsubscribePush(String token, String endpoint) async {
    await apiClient.delete(
      '/api/notifications/push/subscribe',
      gaToken: token,
      body: {'endpoint': endpoint},
    );
  }

  /// Preferencias de aviso: interruptores generales y por categoría.
  ///
  /// El catálogo de categorías lo publica el servidor; aquí no hay ninguna
  /// lista propia que pueda quedarse atrás al añadir un tipo de evento.
  Future<({bool email, bool push, Map<String, Map<String, bool>> categorias})>
      preferences(String token) async {
    final response = await apiClient.get('/api/settings', gaToken: token);
    final payload = response.body;
    if (payload is! Map<String, dynamic>) {
      return (
        email: true,
        push: true,
        categorias: const <String, Map<String, bool>>{},
      );
    }
    return (
      email: payload['notify_email'] != false,
      push: payload['notify_push'] != false,
      categorias: _categorias(payload['notification_categories']),
    );
  }

  /// Cambia un solo interruptor. El servidor fusiona con lo que ya había.
  Future<Map<String, Map<String, bool>>> setCategory(
    String token, {
    required String categoria,
    required String canal,
    required bool valor,
  }) async {
    final response = await apiClient.put(
      '/api/settings',
      gaToken: token,
      body: {
        'notification_categories': {
          categoria: {canal: valor},
        },
      },
    );
    final payload = response.body;
    if (payload is! Map<String, dynamic>) {
      return const <String, Map<String, bool>>{};
    }
    return _categorias(payload['notification_categories']);
  }

  Map<String, Map<String, bool>> _categorias(Object? crudo) {
    if (crudo is! Map) return const <String, Map<String, bool>>{};
    return {
      for (final entrada in crudo.entries)
        if (entrada.value is Map)
          '${entrada.key}': {
            'email': (entrada.value as Map)['email'] != false,
            'push': (entrada.value as Map)['push'] != false,
          },
    };
  }

  /// Marca uno como leído, o todos si [id] es nulo. Devuelve el contador ya
  /// actualizado para no encadenar otra petición solo por bajar el badge.
  Future<int> markRead(String token, {String? id}) async {
    final response = await apiClient.post(
      '/api/notifications/read',
      gaToken: token,
      body: {'id': ?id},
    );
    final payload = response.body;
    if (payload is! Map<String, dynamic>) return 0;
    return (payload['unread'] as num?)?.toInt() ?? 0;
  }
}
