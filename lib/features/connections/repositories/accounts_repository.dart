import '../../../core/network/api_repository.dart';
import '../../../models/accounts/account_models.dart';
import '../../../models/github/github_device_flow.dart';

class AccountsRepository extends ApiRepository {
  AccountsRepository({required super.apiClient});

  Future<List<AccountItem>> listAccounts(String token) async {
    final response = await apiClient.get('/api/accounts', gaToken: token);
    final payload = response.body;
    if (payload is! List) return const [];
    return payload
        .whereType<Map<String, dynamic>>()
        .map((item) => AccountItem(raw: item))
        .toList();
  }

  /// Crea una cuenta nueva. No hay límite de una por proveedor: se pueden
  /// vincular varias del mismo `provider` (ej. dos API keys de OpenAI).
  Future<AccountItem> createAccount(
    String token,
    String provider, {
    String? apiKey,
    String? host,
    String? url,
    String? username,
    String? name,
  }) async {
    final response = await apiClient.post(
      '/api/accounts',
      gaToken: token,
      body: {
        'provider': provider,
        if (apiKey != null) 'api_key': apiKey,
        if (host != null) 'host': host,
        if (url != null) 'url': url,
        if (username != null) 'username': username,
        if (name != null) 'name': name,
      },
    );
    return AccountItem(raw: response.json);
  }

  Future<AccountItem> updateAccount(
    String token,
    String accountId, {
    String? apiKey,
    String? host,
    String? url,
    String? username,
    String? name,
  }) async {
    final response = await apiClient.put(
      '/api/accounts/${Uri.encodeComponent(accountId)}',
      gaToken: token,
      body: {
        if (apiKey != null) 'api_key': apiKey,
        if (host != null) 'host': host,
        if (url != null) 'url': url,
        if (username != null) 'username': username,
        if (name != null) 'name': name,
      },
    );
    return AccountItem(raw: response.json);
  }

  /// Desvincula la cuenta y borra también las conexiones que había
  /// sincronizado. Devuelve cuántas se borraron.
  Future<int> unlinkAccount(String token, String accountId) async {
    final response = await apiClient.delete(
      '/api/accounts/${Uri.encodeComponent(accountId)}',
      gaToken: token,
    );
    final deleted = response.json['connections_deleted'];
    return deleted is int ? deleted : 0;
  }

  /// Prueba credenciales nuevas, antes de crear la cuenta.
  Future<AccountModelsPreview> testNewAccount(
    String token,
    String provider, {
    String? apiKey,
    String? host,
    String? url,
    String? username,
  }) async {
    final response = await apiClient.post(
      '/api/accounts/test',
      gaToken: token,
      body: {
        'provider': provider,
        if (apiKey != null) 'api_key': apiKey,
        if (host != null) 'host': host,
        if (url != null) 'url': url,
        if (username != null) 'username': username,
      },
    );
    return AccountModelsPreview.fromJson(response.json);
  }

  /// Sin [apiKey]/[host]/[url]/[username] previsualiza con las credenciales
  /// ya guardadas de una cuenta vinculada (el backend hace fallback si el
  /// body llega vacío).
  Future<AccountModelsPreview> testAccount(
    String token,
    String accountId, {
    String? apiKey,
    String? host,
    String? url,
    String? username,
  }) async {
    final body = <String, dynamic>{
      if (apiKey != null) 'api_key': apiKey,
      if (host != null) 'host': host,
      if (url != null) 'url': url,
      if (username != null) 'username': username,
    };
    final response = await apiClient.post(
      '/api/accounts/${Uri.encodeComponent(accountId)}/test',
      gaToken: token,
      body: body,
    );
    return AccountModelsPreview.fromJson(response.json);
  }

  /// Sin [models] sincroniza todos los modelos encontrados (comportamiento
  /// histórico). Con [models], solo crea/actualiza conexiones para esos ids.
  Future<AccountItem> syncAccount(
    String token,
    String accountId, {
    List<String>? models,
  }) async {
    final response = await apiClient.post(
      '/api/accounts/${Uri.encodeComponent(accountId)}/sync',
      gaToken: token,
      body: models == null ? null : {'models': models},
    );
    return AccountItem(raw: response.json);
  }

  /// Inicia el GitHub OAuth Device Flow: en vez de pegar un token a mano, el
  /// usuario visita `verificationUri`, introduce `userCode` y autoriza el
  /// acceso — luego hay que sondear [pollGithubDeviceToken] hasta que esté
  /// listo. 503 si el servidor no tiene una GitHub OAuth App configurada.
  Future<GithubDeviceCode> startGithubDeviceFlow(String token) async {
    final response = await apiClient.post(
      '/api/accounts/github/device-code',
      gaToken: token,
    );
    return GithubDeviceCode.fromJson(response.json);
  }

  /// Sondea si el Device Flow ya fue autorizado.
  Future<GithubDeviceTokenResult> pollGithubDeviceToken(
    String token,
    String deviceCode,
  ) async {
    final response = await apiClient.post(
      '/api/accounts/github/device-token',
      gaToken: token,
      body: {'device_code': deviceCode},
    );
    return GithubDeviceTokenResult.fromJson(response.json);
  }
}
