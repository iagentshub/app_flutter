import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show ImageProvider, NetworkImage;
import 'package:http/http.dart' as http;

import '../../shared/state/backend_controller.dart';
import '../config/backend_defaults.dart';
import 'api_error.dart';
import 'api_response.dart';
import 'api_response_cache.dart';
import 'api_uri.dart';
import 'bounded_line_transformer.dart';
import 'http_client_factory.dart';

export 'api_response.dart';

class ApiClient {
  ApiClient(
    this.backendController, {
    http.Client? client,
    Duration requestTimeout = const Duration(seconds: 30),
    int maxResponseBytes = 20 * 1024 * 1024,
    int maxDownloadBytes = 200 * 1024 * 1024,
    int maxStreamLineChars = 1024 * 1024,
    this.onUnauthorized,
    this.sessionIdentity = _anonymousSession,
  }) : _client = client ?? createHttpClient(),
       _requestTimeout = requestTimeout,
       _maxResponseBytes = maxResponseBytes,
       _maxDownloadBytes = maxDownloadBytes,
       _maxStreamLineChars = maxStreamLineChars {
    if (maxResponseBytes <= 0 ||
        maxDownloadBytes <= 0 ||
        maxStreamLineChars <= 0) {
      throw ArgumentError('Los límites de respuesta deben ser positivos');
    }
  }

  final BackendController backendController;
  final http.Client _client;
  final Duration _requestTimeout;
  final int _maxResponseBytes;
  final int _maxDownloadBytes;
  final int _maxStreamLineChars;

  /// Se invoca cuando cualquier petición autenticada recibe un 401 (token
  /// caducado, revocado o inválido), sea cual sea la vista que la disparó,
  /// para que la app pueda cerrar la sesión y volver a login de forma
  /// centralizada en vez de depender de que cada pantalla lo compruebe.
  final VoidCallback? onUnauthorized;

  /// Identidad de la sesión activa, usada para separar la caché por usuario.
  /// La aporta el [SessionController]; sin sesión (splash, login) basta el
  /// valor anónimo por defecto.
  final String Function() sessionIdentity;

  static String _anonymousSession() => 'anon';

  final ApiResponseCache _cache = ApiResponseCache();

  @visibleForTesting
  int get debugCacheEntryCount => _cache.entryCount;

  @visibleForTesting
  int get debugInFlightGetCount => _cache.inFlightCount;
  static const browserCookieSessionToken = '__browser_cookie_session__';

  Uri _uri(String path) {
    return resolveApiUri(
      baseUrl: backendController.effectiveBaseUrl,
      path: path,
      useSameOrigin:
          kIsWeb &&
          backendController.selectedBackendId ==
              BackendDefaults.selectedBackendId,
    );
  }

  /// Envía la petición y reporta al [BackendController] si el backend
  /// seleccionado es alcanzable o no — una respuesta HTTP (incluso 4xx/5xx)
  /// cuenta como "alcanzable"; solo un fallo de red real (sin respuesta)
  /// cuenta como problema de conexión, para no confundirlo con errores de
  /// API normales y así no fallar en silencio en el resto de la app.
  Future<http.StreamedResponse> _send(http.BaseRequest request) async {
    try {
      final streamed = await _client.send(request).timeout(_requestTimeout);
      backendController.reportConnectionOk();
      return streamed;
    } catch (error) {
      backendController.reportConnectionError(error.toString());
      rethrow;
    }
  }

  /// [cache]: si es true, sirve una respuesta reciente (< [ttl]) desde
  /// memoria en vez de golpear la red. Pensado para listados que se
  /// recargan cada vez que se entra a una vista.
  Future<ApiResponse> get(
    String path, {
    String? gaToken,
    bool cache = false,
    Duration? ttl,
  }) async {
    // La clave incluye la identidad de la sesión para que la caché nunca
    // sirva la respuesta de un usuario a otro (p. ej. tras cerrar sesión y
    // entrar con otra cuenta sin pasar por invalidateCache()). No vale el
    // token: en web es la misma constante para todas las cuentas.
    final cacheKey = (
      baseUrl: backendController.effectiveBaseUrl,
      session: sessionIdentity(),
      path: path,
    );
    final now = DateTime.now();
    if (cache) {
      final cached = _cache.read(cacheKey, now);
      if (cached != null) return cached;
      final inFlight = _cache.inFlight(cacheKey);
      if (inFlight != null) return inFlight;
    }

    final generation = _cache.generation;
    final request = _request('GET', path, gaToken: gaToken);
    if (cache) _cache.track(cacheKey, request);
    try {
      final response = await request;
      if (cache) {
        _cache.store(
          cacheKey,
          response,
          requestGeneration: generation,
          now: DateTime.now(),
          ttl: ttl ?? ApiResponseCache.defaultTtl,
        );
      }
      return response;
    } finally {
      if (cache) _cache.untrack(cacheKey, request);
    }
  }

  Future<ApiResponse> post(
    String path, {
    Map<String, dynamic>? body,
    String? gaToken,
  }) async {
    final response = await _request('POST', path, body: body, gaToken: gaToken);
    _cache.invalidateForMutation(path);
    return response;
  }

  Future<ApiResponse> put(
    String path, {
    Map<String, dynamic>? body,
    String? gaToken,
  }) async {
    final response = await _request('PUT', path, body: body, gaToken: gaToken);
    _cache.invalidateForMutation(path);
    return response;
  }

  Future<ApiResponse> patch(
    String path, {
    Map<String, dynamic>? body,
    String? gaToken,
  }) async {
    final response = await _request(
      'PATCH',
      path,
      body: body,
      gaToken: gaToken,
    );
    _cache.invalidateForMutation(path);
    return response;
  }

  Future<ApiResponse> delete(
    String path, {
    Map<String, dynamic>? body,
    String? gaToken,
  }) async {
    final response = await _request(
      'DELETE',
      path,
      body: body,
      gaToken: gaToken,
    );
    _cache.invalidateForMutation(path);
    return response;
  }

  /// Borra toda la caché (p. ej. al cerrar sesión, para no arrastrar datos
  /// de una cuenta a otra) o solo las entradas de un recurso concreto.
  void invalidateCache([String? pathPrefix]) {
    _cache.invalidate(pathPrefix);
  }

  /// Descarga un recurso binario (p. ej. un export en .zip) sin pasar el
  /// cuerpo por el decodificador UTF-8/JSON de [_request], que corrompería
  /// bytes no textuales.
  Future<({Uint8List bytes, String? filename})> getBytes(
    String path, {
    String? gaToken,
  }) async {
    final headers = <String, String>{'Accept': '*/*'};
    if (gaToken != null && gaToken.isNotEmpty) {
      headers['Cookie'] = 'ga_token=$gaToken';
    }
    final request = http.Request('GET', _uri(path));
    request.followRedirects = false;
    request.headers.addAll(headers);

    final streamed = await _send(request);
    final response = await _readBoundedResponse(
      streamed,
      maxBytes: _maxDownloadBytes,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final parsed = _parseBody(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
      throw _toApiError(
        ApiResponse(
          statusCode: response.statusCode,
          headers: response.headers,
          body: parsed,
        ),
      );
    }

    final disposition = response.headers['content-disposition'];
    final match = disposition == null
        ? null
        : RegExp('filename="?([^"; ]+)"?').firstMatch(disposition);
    return (
      bytes: response.bodyBytes,
      filename: _sanitizeDownloadFilename(match?.group(1)),
    );
  }

  /// Envía un POST y expone la respuesta como flujo de líneas crudas
  /// (Server-Sent Events: `data: {...}`). Usado por streaming de chat.
  Stream<String> postStream(
    String path, {
    Map<String, dynamic>? body,
    String? gaToken,
  }) {
    return _eventStream('POST', path, body: body, gaToken: gaToken);
  }

  /// Igual que [postStream] pero por GET, para endpoints SSE que no llevan
  /// body (p. ej. /admin/centinel/stream/{run_id}).
  Stream<String> getStream(String path, {String? gaToken}) {
    return _eventStream('GET', path, gaToken: gaToken);
  }

  Stream<String> _eventStream(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? gaToken,
  }) async* {
    final headers = <String, String>{'Accept': 'text/event-stream'};
    if (!kIsWeb && gaToken != null && gaToken.isNotEmpty) {
      headers['Cookie'] = 'ga_token=$gaToken';
    }
    if (body != null) headers['Content-Type'] = 'application/json';

    final request = http.Request(method, _uri(path));
    request.followRedirects = false;
    request.headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);

    final streamed = await _send(request);
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      final response = await _readBoundedResponse(streamed);
      final parsed = _parseBody(response.body);
      throw _toApiError(
        ApiResponse(
          statusCode: streamed.statusCode,
          headers: streamed.headers,
          body: parsed,
        ),
      );
    }

    yield* streamed.stream
        .transform(utf8.decoder)
        .transform(BoundedLineTransformer(maxLineChars: _maxStreamLineChars));
  }

  Future<ApiResponse> postMultipart(
    String path, {
    required String fieldName,
    required String fileName,
    required List<int> fileBytes,
    Map<String, String>? fields,
    String? gaToken,
  }) async {
    final request = http.MultipartRequest('POST', _uri(path));
    request.followRedirects = false;
    request.headers['Accept'] = 'application/json';
    if (!kIsWeb && gaToken != null && gaToken.isNotEmpty) {
      request.headers['Cookie'] = 'ga_token=$gaToken';
    }

    if (fields != null && fields.isNotEmpty) {
      request.fields.addAll(fields);
    }

    request.files.add(
      http.MultipartFile.fromBytes(fieldName, fileBytes, filename: fileName),
    );

    final streamed = await _send(request);
    final response = await _readBoundedResponse(streamed);
    final parsed = _parseBody(response.body);
    final apiResponse = ApiResponse(
      statusCode: response.statusCode,
      headers: response.headers,
      body: parsed,
    );

    if (!apiResponse.isOk) {
      throw _toApiError(apiResponse);
    }

    _cache.invalidateForMutation(path);
    return apiResponse;
  }

  Future<ApiResponse> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? gaToken,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (!kIsWeb && gaToken != null && gaToken.isNotEmpty) {
      headers['Cookie'] = 'ga_token=$gaToken';
    }

    if (body != null) {
      headers['Content-Type'] = 'application/json';
    }

    final request = http.Request(method, _uri(path));
    request.followRedirects = false;
    request.headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);

    final streamed = await _send(request);
    final response = await _readBoundedResponse(streamed);
    final parsed = _parseBody(response.body);
    final apiResponse = ApiResponse(
      statusCode: response.statusCode,
      headers: response.headers,
      body: parsed,
    );

    if (!apiResponse.isOk) {
      throw _toApiError(apiResponse);
    }

    return apiResponse;
  }

  Future<http.Response> _readBoundedResponse(
    http.StreamedResponse streamed, {
    int? maxBytes,
  }) async {
    final limit = maxBytes ?? _maxResponseBytes;
    final declaredLength = streamed.contentLength;
    if (declaredLength != null && declaredLength > limit) {
      throw ApiError(
        statusCode: 502,
        code: 'response_too_large',
        message: 'La respuesta del servidor supera el límite permitido',
      );
    }

    final bytes = BytesBuilder(copy: false);
    var received = 0;
    await for (final chunk in streamed.stream) {
      received += chunk.length;
      if (received > limit) {
        throw ApiError(
          statusCode: 502,
          code: 'response_too_large',
          message: 'La respuesta del servidor supera el límite permitido',
        );
      }
      bytes.add(chunk);
    }

    return http.Response.bytes(
      bytes.takeBytes(),
      streamed.statusCode,
      headers: streamed.headers,
      request: streamed.request,
      isRedirect: streamed.isRedirect,
      persistentConnection: streamed.persistentConnection,
      reasonPhrase: streamed.reasonPhrase,
    );
  }

  Object? _parseBody(String body) {
    if (body.trim().isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  ApiError _toApiError(ApiResponse response) {
    if (response.statusCode == 401) {
      onUnauthorized?.call();
    }
    final payload = response.body;
    if (payload is Map<String, dynamic>) {
      final detail = payload['detail'];
      if (detail is String) {
        return ApiError(statusCode: response.statusCode, message: detail);
      }
      if (detail is Map<String, dynamic>) {
        final message =
            detail['message'] as String? ?? 'Error ${response.statusCode}';
        return ApiError(
          statusCode: response.statusCode,
          message: message,
          code: detail['code'] as String?,
        );
      }
    }
    return ApiError(
      statusCode: response.statusCode,
      message: 'Error ${response.statusCode}',
    );
  }

  /// Proveedor de imagen para recursos que requieren sesión (avatares).
  ///
  /// Las vistas montaban `Image.network(url, headers: {'Cookie': ...})`, pero
  /// `Cookie` es un *forbidden header name*: en web el navegador la descarta
  /// y el avatar privado caía al fallback de iniciales sin ningún error
  /// visible. Ahí la cookie HttpOnly ya viaja sola en las peticiones
  /// same-origin, así que la cabecera sobra; fuera de web sí hace falta.
  ///
  /// De paso, el token deja de circular por widgets de presentación y la URL
  /// pasa por [_uri], heredando la resolución same-origin del resto de
  /// peticiones.
  ImageProvider authenticatedImage(String path, {String? gaToken}) {
    final sendCookie =
        !kIsWeb &&
        gaToken != null &&
        gaToken.isNotEmpty &&
        gaToken != browserCookieSessionToken;
    return NetworkImage(
      _uri(path).toString(),
      headers: sendCookie ? {'Cookie': 'ga_token=$gaToken'} : null,
    );
  }

  String? extractGaToken(Map<String, String> headers) {
    // Los navegadores guardan la cookie HttpOnly automáticamente, pero por
    // seguridad nunca exponen Set-Cookie a JavaScript. El marcador mantiene
    // el contrato de sesión interno; BrowserClient enviará la cookie real en
    // todas las peticiones same-origin bajo /app/.
    if (kIsWeb) return browserCookieSessionToken;

    final setCookie = headers['set-cookie'];
    if (setCookie == null || setCookie.isEmpty) return null;

    final match = RegExp(r'ga_token=([^;]+)').firstMatch(setCookie);
    return match?.group(1);
  }

  String? _sanitizeDownloadFilename(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final basename = raw.replaceAll(r'\', '/').split('/').last;
    final sanitized = basename
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    if (sanitized.isEmpty || sanitized == '.' || sanitized == '..') {
      return null;
    }
    return sanitized.length <= 255 ? sanitized : sanitized.substring(0, 255);
  }

  void close() {
    _cache.clear();
    _client.close();
  }
}
