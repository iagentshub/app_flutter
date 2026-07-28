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
  ApiClient(this.backendController, {http.Client? client}) : _client = client ?? http.Client();

  final BackendController backendController;
  final http.Client _client;

  Uri _uri(String path) {
    final base = backendController.effectiveBaseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$normalizedPath');
  }

  Future<ApiResponse> get(String path, {String? gaToken}) {
    return _request('GET', path, gaToken: gaToken);
  }

  Future<ApiResponse> post(String path, {Map<String, dynamic>? body, String? gaToken}) {
    return _request('POST', path, body: body, gaToken: gaToken);
  }

  Future<ApiResponse> put(String path, {Map<String, dynamic>? body, String? gaToken}) {
    return _request('PUT', path, body: body, gaToken: gaToken);
  }

  Future<ApiResponse> patch(String path, {Map<String, dynamic>? body, String? gaToken}) {
    return _request('PATCH', path, body: body, gaToken: gaToken);
  }

  Future<ApiResponse> delete(String path, {Map<String, dynamic>? body, String? gaToken}) {
    return _request('DELETE', path, body: body, gaToken: gaToken);
  }

  /// Envía un POST y expone la respuesta como flujo de líneas crudas
  /// (Server-Sent Events: `data: {...}`). Usado por streaming de chat.
  Stream<String> postStream(String path, {Map<String, dynamic>? body, String? gaToken}) async* {
    final headers = <String, String>{'Accept': 'text/event-stream'};
    if (gaToken != null && gaToken.isNotEmpty) {
      headers['Cookie'] = 'ga_token=$gaToken';
    }
    if (body != null) headers['Content-Type'] = 'application/json';

    final request = http.Request('POST', _uri(path));
    request.headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);

    final streamed = await _client.send(request);
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      final raw = await streamed.stream.bytesToString();
      final parsed = _parseBody(raw);
      throw _toApiError(ApiResponse(statusCode: streamed.statusCode, headers: streamed.headers, body: parsed));
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

    request.files.add(http.MultipartFile.fromBytes(fieldName, fileBytes, filename: fileName));

    final streamed = await _client.send(request);
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

    final streamed = await _client.send(request);
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
        final message = detail['message'] as String? ?? 'Error ${response.statusCode}';
        return ApiError(
          statusCode: response.statusCode,
          message: message,
          code: detail['code'] as String?,
        );
      }
    }
    return ApiError(statusCode: response.statusCode, message: 'Error ${response.statusCode}');
  }

  String? extractGaToken(Map<String, String> headers) {
    final setCookie = headers['set-cookie'];
    if (setCookie == null || setCookie.isEmpty) return null;

    final match = RegExp(r'ga_token=([^;]+)').firstMatch(setCookie);
    return match?.group(1);
  }
}
