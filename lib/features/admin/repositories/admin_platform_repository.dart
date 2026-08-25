import '../../../core/network/api_repository.dart';
import '../../../shared/state/upload_limits.dart';

/// Configuración de plataforma (`/api/settings/platform`), actualizaciones
/// del backend y banners de notificación — el tab "Configuración" de Admin
/// (`_AdminConfigTab`/`_AdminBannersCard`/`_AdminUpdatesCard`) es el único
/// consumidor de este repositorio.
class AdminPlatformRepository extends ApiRepository {
  AdminPlatformRepository({required super.apiClient});

  Future<Map<String, dynamic>> getPlatformSettings(String token) async {
    final response = await apiClient.get(
      '/api/settings/platform',
      gaToken: token,
      cache: true,
    );
    return response.json;
  }

  Future<Map<String, dynamic>> updatePlatformSettings(
    String token,
    Map<String, dynamic> payload,
  ) async {
    final response = await apiClient.put(
      '/api/settings/platform',
      gaToken: token,
      body: payload,
    );
    final settings = response.json;
    UploadLimits.updateFromPlatform(settings);
    return settings;
  }

  Future<Map<String, dynamic>> getUserSettings(String token) async {
    final response = await apiClient.get('/api/settings', gaToken: token);
    return response.json;
  }

  /// Auditoría de configuración del arranque: qué funciones quedan
  /// desactivadas y por qué variable. El backend devuelve solo **nombres** de
  /// variable, nunca sus valores.
  Future<Map<String, dynamic>> getConfigAudit(String token) async {
    final response = await apiClient.get(
      '/api/admin/config-audit',
      gaToken: token,
    );
    return response.json;
  }

  Future<Map<String, dynamic>> checkUpdate(String token) async {
    final response = await apiClient.get(
      '/api/admin/check-update',
      gaToken: token,
    );
    return response.json;
  }

  Future<Map<String, dynamic>> setAutoUpdate(String token, bool enabled) async {
    final response = await apiClient.put(
      '/api/admin/auto-update',
      gaToken: token,
      body: {'enabled': enabled},
    );
    return response.json;
  }

  Future<Map<String, dynamic>> triggerUpdateNow(String token) async {
    final response = await apiClient.post(
      '/api/admin/update-now',
      gaToken: token,
    );
    return response.json;
  }

  // ── Banners de notificación ──────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listNotificationBanners(
    String token,
  ) async {
    final response = await apiClient.get(
      '/api/settings/notification-banners',
      gaToken: token,
    );
    final payload = response.body;
    if (payload is! List) return const [];
    return payload.whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> createNotificationBanner(
    String token,
    Map<String, dynamic> payload,
  ) async {
    final response = await apiClient.post(
      '/api/settings/notification-banners',
      gaToken: token,
      body: payload,
    );
    return response.json;
  }

  Future<Map<String, dynamic>> updateNotificationBanner(
    String token,
    String bannerId,
    Map<String, dynamic> payload,
  ) async {
    final response = await apiClient.put(
      '/api/settings/notification-banners/${Uri.encodeComponent(bannerId)}',
      gaToken: token,
      body: payload,
    );
    return response.json;
  }

  Future<void> deleteNotificationBanner(String token, String bannerId) async {
    await apiClient.delete(
      '/api/settings/notification-banners/${Uri.encodeComponent(bannerId)}',
      gaToken: token,
    );
  }
}
