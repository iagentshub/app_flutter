import 'dart:convert';

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
  ApiClient(this.backendController, {http.Client? client})
    : _client = client ?? http.Client();

  final BackendController backendController;
  final http.Client _client;

  /// Caché en memoria de respuestas GET, igual de espíritu que el staleTime
  /// de react-query en el frontend: evita repetir la misma consulta de
  /// listado cada vez que se revisita una vista, y se invalida sola cuando
  /// una mutación (POST/PUT/PATCH/DELETE) toca el mismo recurso.
  final Map<String, ({DateTime at, ApiResponse response})> _cache = {};
  static const _defaultCacheTtl = Duration(seconds: 60);

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
      final streamed = await _client.send(request);
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
    if (cache) {
      final cached = _cache[path];
      if (cached != null &&
          DateTime.now().difference(cached.at) < (ttl ?? _defaultCacheTtl)) {
        return cached.response;
      }
    }
    final response = await _request('GET', path, gaToken: gaToken);
    if (cache) _cache[path] = (at: DateTime.now(), response: response);
    return response;
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
    if (pathPrefix == null) {
      _cache.clear();
      return;
    }
    _cache.removeWhere((key, _) => key.startsWith(pathPrefix));
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

    var buffer = '';
    await for (final chunk in streamed.stream.transform(utf8.decoder)) {
      buffer += chunk;
      final lines = buffer.split('\n');
      buffer = lines.removeLast();
      for (final line in lines) {
        yield line;
      }
    }
    if (buffer.isNotEmpty) yield buffer;
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
}
