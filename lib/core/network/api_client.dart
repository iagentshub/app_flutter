import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_error.dart';
import '../../shared/state/backend_controller.dart';

class ApiResponse {
  const ApiResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
  });

  final int statusCode;
  final Map<String, String> headers;
  final Object? body;

  bool get isOk => statusCode >= 200 && statusCode < 300;

  Map<String, dynamic> get json {
    if (body is Map<String, dynamic>) return body as Map<String, dynamic>;
    return <String, dynamic>{'data': body};
  }
}

class ApiClient {
  ApiClient(
    this.backendController, {
    http.Client? client,
    Duration requestTimeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client(),
       _requestTimeout = requestTimeout;

  final BackendController backendController;
  final http.Client _client;
  final Duration _requestTimeout;

  /// Caché en memoria de respuestas GET, igual de espíritu que el staleTime
  /// de react-query en el frontend: evita repetir la misma consulta de
  /// listado cada vez que se revisita una vista, y se invalida sola cuando
  /// una mutación (POST/PUT/PATCH/DELETE) toca el mismo recurso.
  final Map<
    ({String baseUrl, String? gaToken, String path}),
    ({DateTime expiresAt, ApiResponse response})
  >
  _cache = {};
  final Map<
    ({String baseUrl, String? gaToken, String path}),
    Future<ApiResponse>
  >
  _inFlightGets = {};
  static const _defaultCacheTtl = Duration(seconds: 60);
  static const _maxCacheEntries = 200;
  int _cacheGeneration = 0;

  @visibleForTesting
  int get debugCacheEntryCount => _cache.length;

  @visibleForTesting
  int get debugInFlightGetCount => _inFlightGets.length;

  Uri _uri(String path) {
    final base = backendController.effectiveBaseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$normalizedPath');
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
    // La clave incluye el token para que la caché nunca sirva la respuesta
    // de un usuario a otro (p. ej. tras cerrar sesión y entrar con otra
    // cuenta sin pasar por invalidateCache()).
    final cacheKey = (
      baseUrl: backendController.effectiveBaseUrl,
      gaToken: gaToken,
      path: path,
    );
    final now = DateTime.now();
    if (cache) {
      final cached = _cache[cacheKey];
      if (cached != null && now.isBefore(cached.expiresAt)) {
        return cached.response;
      }
      if (cached != null) _cache.remove(cacheKey);

      final inFlight = _inFlightGets[cacheKey];
      if (inFlight != null) return inFlight;
    }

    final generation = _cacheGeneration;
    final request = _request('GET', path, gaToken: gaToken);
    if (cache) _inFlightGets[cacheKey] = request;
    try {
      final response = await request;
      if (cache && generation == _cacheGeneration) {
        _storeCache(
          cacheKey,
          response,
          now: DateTime.now(),
          ttl: ttl ?? _defaultCacheTtl,
        );
      }
      return response;
    } finally {
      if (cache && identical(_inFlightGets[cacheKey], request)) {
        _inFlightGets.remove(cacheKey);
      }
    }
  }

  Future<ApiResponse> post(
    String path, {
    Map<String, dynamic>? body,
    String? gaToken,
  }) async {
    final response = await _request('POST', path, body: body, gaToken: gaToken);
    _invalidateForMutation(path);
    return response;
  }

  Future<ApiResponse> put(
    String path, {
    Map<String, dynamic>? body,
    String? gaToken,
  }) async {
    final response = await _request('PUT', path, body: body, gaToken: gaToken);
    _invalidateForMutation(path);
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
    _invalidateForMutation(path);
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
    _invalidateForMutation(path);
    return response;
  }

  /// Borra toda la caché (p. ej. al cerrar sesión, para no arrastrar datos
  /// de una cuenta a otra) o solo las entradas de un recurso concreto.
  void invalidateCache([String? pathPrefix]) {
    _cacheGeneration += 1;
    if (pathPrefix == null) {
      _cache.clear();
      return;
    }
    _cache.removeWhere((key, _) => key.path.startsWith(pathPrefix));
  }

  void _storeCache(
    ({String baseUrl, String? gaToken, String path}) key,
    ApiResponse response, {
    required DateTime now,
    required Duration ttl,
  }) {
    _cache.removeWhere((_, entry) => !now.isBefore(entry.expiresAt));
    _cache[key] = (expiresAt: now.add(ttl), response: response);
    while (_cache.length > _maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
  }

  void _invalidateForMutation(String path) {
    final withoutQuery = path.split('?').first;
    final segments = withoutQuery
        .split('/')
        .where((s) => s.isNotEmpty)
        .toList();
    final root = segments.length >= 2 ? '/${segments[0]}/${segments[1]}' : path;
    invalidateCache(root);
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
    final response = await http.Response.fromStream(streamed);
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
    if (gaToken != null && gaToken.isNotEmpty) {
      headers['Cookie'] = 'ga_token=$gaToken';
    }
    if (body != null) headers['Content-Type'] = 'application/json';

    final request = http.Request(method, _uri(path));
    request.followRedirects = false;
    request.headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);

    final streamed = await _send(request);
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      final raw = await streamed.stream.bytesToString();
      final parsed = _parseBody(raw);
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
        .transform(const LineSplitter());
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
    if (gaToken != null && gaToken.isNotEmpty) {
      request.headers['Cookie'] = 'ga_token=$gaToken';
    }

    if (fields != null && fields.isNotEmpty) {
      request.fields.addAll(fields);
    }

    request.files.add(
      http.MultipartFile.fromBytes(fieldName, fileBytes, filename: fileName),
    );

    final streamed = await _send(request);
    final response = await http.Response.fromStream(streamed);
    final parsed = _parseBody(response.body);
    final apiResponse = ApiResponse(
      statusCode: response.statusCode,
      headers: response.headers,
      body: parsed,
    );

    if (!apiResponse.isOk) {
      throw _toApiError(apiResponse);
    }

    _invalidateForMutation(path);
    return apiResponse;
  }

  Future<ApiResponse> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? gaToken,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (gaToken != null && gaToken.isNotEmpty) {
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
    final response = await http.Response.fromStream(streamed);
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

  Object? _parseBody(String body) {
    if (body.trim().isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  ApiError _toApiError(ApiResponse response) {
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

  String? extractGaToken(Map<String, String> headers) {
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
    _inFlightGets.clear();
    _client.close();
  }
}
