import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show ImageProvider, NetworkImage;
import 'package:http/http.dart' as http;

import '../../shared/state/backend_controller.dart';
import '../../shared/state/resource_events.dart';
import '../../utils/i18n.dart';
import '../config/backend_defaults.dart';
import 'api_error.dart';
import 'api_response.dart';
import 'api_response_cache.dart';
import 'api_uri.dart';
import 'bounded_line_transformer.dart';
import 'csrf_token.dart';
import 'http_client_factory.dart';

export 'api_response.dart';

class _ProgressMultipartRequest extends http.MultipartRequest {
  _ProgressMultipartRequest(super.method, super.url, this.onProgress);

  final void Function(int sent, int total) onProgress;

  @override
  http.ByteStream finalize() {
    final total = contentLength;
    var sent = 0;
    final stream = super.finalize().transform(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (chunk, sink) {
          sent += chunk.length;
          onProgress(sent.clamp(0, total), total);
          sink.add(chunk);
        },
      ),
    );
    return http.ByteStream(stream);
  }
}

class ApiClient {
  ApiClient(
    this.backendController, {
    http.Client? client,
    this._requestTimeout = const Duration(seconds: 30),
    int maxResponseBytes = 20 * 1024 * 1024,
    int maxDownloadBytes = 200 * 1024 * 1024,
    int maxStreamLineChars = 1024 * 1024,
    this.onUnauthorized,
    this.onSessionRenewed,
    this.onRefreshTokenSeen,
    this.refreshTokenProvider,
    this.sessionIdentity = _anonymousSession,
    ResourceEvents? resourceEvents,
  }) : resourceEvents = resourceEvents ?? ResourceEvents(),
       _client = client ?? createHttpClient(),
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

  /// Se invoca con el `ga_token` nuevo cuando una renovación sale bien, para
  /// que la sesión en curso siga usándolo. Fuera de web la app guarda las
  /// cookies a mano, así que sin esto la renovación valdría solo para la
  /// petición que la disparó.
  final void Function(String gaToken)? onSessionRenewed;

  /// Se invoca con cada `ga_refresh` que llega en un `Set-Cookie`. Fuera de
  /// web es lo único que hace persistente la sesión más allá del access.
  final void Function(String refreshToken)? onRefreshTokenSeen;

  /// El `ga_refresh` guardado, que fuera de web hay que enviar a mano. En web
  /// devuelve null: la cookie es HttpOnly y la manda el navegador.
  final String? Function()? refreshTokenProvider;

  /// Identidad de la sesión activa, usada para separar la caché por usuario.
  /// La aporta el [SessionController]; sin sesión (splash, login) basta el
  /// valor anónimo por defecto.
  final String Function() sessionIdentity;

  static String _anonymousSession() => 'anon';

  /// Avisa a las pantallas montadas de que un recurso cambió.
  ///
  /// Se emite aquí y no en cada controlador porque aquí ya se sabe qué se ha
  /// tocado —es el mismo dato con el que se invalida la caché— y así nadie
  /// tiene que acordarse de avisar después de mutar.
  final ResourceEvents resourceEvents;

  final ApiResponseCache _cache = ApiResponseCache();

  void _afterMutation(String path) {
    _cache.invalidateForMutation(path);
    resourceEvents.changed(ResourceEvents.typeFromPath(path));
  }

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

  /// Envía la petición, renovando la sesión y reintentando una vez si el
  /// backend contesta 401.
  ///
  /// [build] recibe el token de sesión vigente y construye la petición. Es una
  /// función y no una petición ya hecha porque puede enviarse dos veces: si la
  /// primera devuelve 401 y la sesión se renueva, la segunda tiene que llevar
  /// el token nuevo y un cuerpo sin consumir — un `BaseRequest` ya finalizado
  /// no se puede reenviar.
  Future<http.StreamedResponse> _send(
    http.BaseRequest Function(String? gaToken) build, {
    String? gaToken,
    Duration? timeout,
  }) async {
    final streamed = await _sendOnce(build(gaToken), timeout: timeout);
    if (streamed.statusCode != 401) return streamed;

    final renovado = await _refreshSession(gaToken);
    if (renovado == null) return streamed;

    // El 401 anterior queda sin consumir; el stream de una respuesta que no se
    // lee mantiene la conexión abierta hasta el timeout.
    await streamed.stream.drain<void>();
    return _sendOnce(build(renovado), timeout: timeout);
  }

  /// Envía la petición y reporta al [BackendController] si el backend
  /// seleccionado es alcanzable o no — una respuesta HTTP (incluso 4xx/5xx)
  /// cuenta como "alcanzable"; solo un fallo de red real (sin respuesta)
  /// cuenta como problema de conexión, para no confundirlo con errores de
  /// API normales y así no fallar en silencio en el resto de la app.
  Future<http.StreamedResponse> _sendOnce(
    http.BaseRequest request, {
    Duration? timeout,
  }) async {
    try {
      final streamed = await _client
          .send(request)
          .timeout(timeout ?? _requestTimeout);
      backendController.reportConnectionOk();
      // Punto único de captura del token anti-CSRF fuera de web. No basta con
      // leerlo al iniciar sesión: el backend reemite `ga_csrf` en cualquier
      // respuesta cuando falta o no cuadra —así se curan las sesiones abiertas
      // antes del despliegue— y también al cambiar de grupo o impersonar.
      if (!kIsWeb) {
        rememberCsrfToken(_csrfFromSetCookie(streamed.headers));
        // Mismo criterio que la línea de arriba: un punto único de captura.
        // El `ga_refresh` llega en el login, en el registro, en el alta de
        // invitado, al verificar el email, al entrar con GitHub y en cada
        // renovación; recogerlo en cada uno de esos seis sitios es la forma
        // de que al séptimo se le olvide.
        final refresh = _refreshFromSetCookie(streamed.headers);
        if (refresh != null) onRefreshTokenSeen?.call(refresh);
      }
      return streamed;
    } catch (error) {
      backendController.reportConnectionError(error.toString());
      rethrow;
    }
  }

  /// Renueva la sesión tras un 401 y devuelve el token nuevo, o null si no se
  /// pudo (no hay refresh, caducó, o la sesión estaba revocada).
  ///
  /// El cerrojo no es opcional. El access dura 30 minutos y una pantalla puede
  /// disparar seis peticiones a la vez: sin él, las seis reciben 401 casi
  /// simultáneamente y lanzan seis renovaciones. Como el backend **rota** el
  /// refresh en cada canje, la segunda llegaría con uno ya rotado — que es
  /// exactamente la señal de robo que tumba la sesión entera. El cerrojo hace
  /// que las seis esperen a la misma renovación.
  Future<String?> _refreshSession(String? gaToken) {
    return _refreshInFlight ??= _doRefresh(gaToken).whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<String?>? _refreshInFlight;

  Future<String?> _doRefresh(String? gaToken) async {
    // Sin sesión no hay nada que renovar: el 401 de la pantalla de login o del
    // splash es la respuesta correcta, no una credencial caducada.
    if (gaToken == null || gaToken.isEmpty) return null;
    if (!kIsWeb && (refreshTokenProvider?.call() ?? '').isEmpty) return null;
    final http.StreamedResponse streamed;
    try {
      streamed = await _sendOnce(_refreshRequest(gaToken));
    } on Object {
      // Un fallo de red al renovar no es una sesión cerrada: el 401 original
      // sigue su curso y lo trata quien lo recibió.
      return null;
    }
    final response = await _readBoundedResponse(streamed);
    if (response.statusCode != 200) return null;

    // En web las cookies las guarda el navegador y la app nunca ve el valor:
    // el token efectivo sigue siendo el marcador de sesión de navegador.
    if (kIsWeb) return browserCookieSessionToken;

    final nuevo = extractGaToken(response.headers);
    if (nuevo == null) return null;
    onSessionRenewed?.call(nuevo);
    return nuevo;
  }

  http.Request _refreshRequest(String? gaToken) {
    final request = http.Request('POST', _uri('/api/auth/refresh'));
    request.followRedirects = false;
    request.headers.addAll(
      _sessionHeaders(
        accept: 'application/json',
        gaToken: gaToken,
        mutation: true,
        refreshToken: refreshTokenProvider?.call(),
      ),
    );
    return request;
  }

  /// [cache]: si es true, sirve una respuesta reciente (< [ttl]) desde
  /// memoria en vez de golpear la red. Pensado para listados que se
  /// recargan cada vez que se entra a una vista.
  Future<ApiResponse> get(
    String path, {
    String? gaToken,
    bool cache = false,
    Duration? ttl,
    Duration? timeout,
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
    final request = _request('GET', path, gaToken: gaToken, timeout: timeout);
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
    _afterMutation(path);
    return response;
  }

  Future<ApiResponse> put(
    String path, {
    Map<String, dynamic>? body,
    String? gaToken,
  }) async {
    final response = await _request('PUT', path, body: body, gaToken: gaToken);
    _afterMutation(path);
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
    _afterMutation(path);
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
    _afterMutation(path);
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
    http.Request build(String? token) {
      final request = http.Request('GET', _uri(path));
      request.followRedirects = false;
      request.headers.addAll(_sessionHeaders(accept: '*/*', gaToken: token));
      return request;
    }

    final streamed = await _send(build, gaToken: gaToken);
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

  /// Variante binaria de POST para exportaciones cuyo cuerpo contiene una
  /// selección de componentes. Comparte límites y saneado con [getBytes].
  Future<({Uint8List bytes, String? filename})> postBytes(
    String path, {
    Map<String, dynamic>? body,
    String? gaToken,
  }) async {
    http.Request build(String? token) {
      final request = http.Request('POST', _uri(path));
      request.followRedirects = false;
      request.headers.addAll(
        _sessionHeaders(
          accept: 'application/zip',
          gaToken: token,
          mutation: true,
          jsonBody: body != null,
        ),
      );
      if (body != null) request.body = jsonEncode(body);
      return request;
    }

    final streamed = await _send(build, gaToken: gaToken);
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
    http.Request build(String? token) {
      final request = http.Request(method, _uri(path));
      request.followRedirects = false;
      request.headers.addAll(
        _sessionHeaders(
          accept: 'text/event-stream',
          gaToken: token,
          mutation: method != 'GET',
          jsonBody: body != null,
        ),
      );
      if (body != null) request.body = jsonEncode(body);
      return request;
    }

    final streamed = await _send(build, gaToken: gaToken);
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
    Duration? timeout,
  }) async {
    http.MultipartRequest build(String? token) {
      final request = http.MultipartRequest('POST', _uri(path));
      request.followRedirects = false;
      request.headers.addAll(
        _sessionHeaders(
          accept: 'application/json',
          gaToken: token,
          mutation: true,
        ),
      );
      if (fields != null && fields.isNotEmpty) {
        request.fields.addAll(fields);
      }
      request.files.add(
        http.MultipartFile.fromBytes(fieldName, fileBytes, filename: fileName),
      );
      return request;
    }

    final streamed = await _send(build, gaToken: gaToken, timeout: timeout);
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

    _afterMutation(path);
    return apiResponse;
  }

  Future<ApiResponse> postMultipartWithProgress(
    String path, {
    required String fieldName,
    required String fileName,
    required List<int> fileBytes,
    required void Function(double progress) onProgress,
    Map<String, String>? fields,
    String? gaToken,
    Duration? timeout,
  }) async {
    _ProgressMultipartRequest build(String? token) {
      final request = _ProgressMultipartRequest('POST', _uri(path), (
        sent,
        total,
      ) {
        onProgress(total <= 0 ? 0 : (sent / total).clamp(0, 1));
      });
      request.followRedirects = false;
      request.headers.addAll(
        _sessionHeaders(
          accept: 'application/json',
          gaToken: token,
          mutation: true,
        ),
      );
      if (fields != null) request.fields.addAll(fields);
      request.files.add(
        http.MultipartFile.fromBytes(fieldName, fileBytes, filename: fileName),
      );
      return request;
    }

    final streamed = await _send(build, gaToken: gaToken, timeout: timeout);
    final response = await _readBoundedResponse(streamed);
    final apiResponse = ApiResponse(
      statusCode: response.statusCode,
      headers: response.headers,
      body: _parseBody(response.body),
    );
    if (!apiResponse.isOk) throw _toApiError(apiResponse);
    _afterMutation(path);
    onProgress(1);
    return apiResponse;
  }

  Future<ApiResponse> postMultipartFiles(
    String path, {
    required String fieldName,
    required List<({String fileName, List<int> bytes})> files,
    Map<String, String>? fields,
    String? gaToken,
    Duration? timeout,
  }) async {
    http.MultipartRequest build(String? token) {
      final request = http.MultipartRequest('POST', _uri(path));
      request.followRedirects = false;
      request.headers.addAll(
        _sessionHeaders(
          accept: 'application/json',
          gaToken: token,
          mutation: true,
        ),
      );
      if (fields != null && fields.isNotEmpty) request.fields.addAll(fields);
      for (final file in files) {
        request.files.add(
          http.MultipartFile.fromBytes(
            fieldName,
            file.bytes,
            filename: file.fileName,
          ),
        );
      }
      return request;
    }

    final streamed = await _send(build, gaToken: gaToken, timeout: timeout);
    final response = await _readBoundedResponse(streamed);
    final parsed = _parseBody(response.body);
    final apiResponse = ApiResponse(
      statusCode: response.statusCode,
      headers: response.headers,
      body: parsed,
    );
    if (!apiResponse.isOk) throw _toApiError(apiResponse);
    _afterMutation(path);
    return apiResponse;
  }

  Future<ApiResponse> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? gaToken,
    Duration? timeout,
  }) async {
    http.Request build(String? token) {
      final request = http.Request(method, _uri(path));
      request.followRedirects = false;
      request.headers.addAll(
        _sessionHeaders(
          accept: 'application/json',
          gaToken: token,
          mutation: method != 'GET',
          jsonBody: body != null,
        ),
      );
      if (body != null) request.body = jsonEncode(body);
      return request;
    }

    final streamed = await _send(build, gaToken: gaToken, timeout: timeout);
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
        message: tr('common.response_too_large'),
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
          message: tr('common.response_too_large'),
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
        final fallback =
            detail['message'] as String? ?? 'Error ${response.statusCode}';
        final code = detail['code'] as String?;
        return ApiError(
          statusCode: response.statusCode,
          message: trErrorOr(code, fallback),
          code: code,
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

  static String? _csrfFromSetCookie(Map<String, String> headers) {
    final setCookie = headers['set-cookie'];
    if (setCookie == null || setCookie.isEmpty) return null;
    return RegExp(r'ga_csrf=([^;]+)').firstMatch(setCookie)?.group(1);
  }

  /// Cabeceras comunes a todas las peticiones.
  ///
  /// Existe porque el bloque `Cookie: ga_token=…` estaba copiado en siete
  /// métodos: con una sola cabecera era duplicación tolerable, pero en cuanto
  /// hay que añadir `X-CSRF-Token` a los métodos con efectos, olvidarse de uno
  /// no rompe nada visible —solo devuelve 403 en esa ruta concreta—.
  Map<String, String> _sessionHeaders({
    required String accept,
    String? gaToken,
    bool mutation = false,
    bool jsonBody = false,
    String? refreshToken,
  }) {
    final headers = <String, String>{'Accept': accept};
    if (!kIsWeb && gaToken != null && gaToken.isNotEmpty) {
      final cookies = <String>['ga_token=$gaToken'];
      // Solo en la petición que lo canjea: el backend acota su cookie a
      // `path=/api/auth` por lo mismo — es la credencial de largo recorrido y
      // no tiene por qué viajar en el resto de rutas.
      if (refreshToken != null && refreshToken.isNotEmpty) {
        cookies.add('ga_refresh=$refreshToken');
      }
      headers['Cookie'] = cookies.join('; ');
    }
    if (jsonBody) headers['Content-Type'] = 'application/json';
    if (mutation) {
      final csrf = readCsrfToken();
      if (csrf != null) headers['X-CSRF-Token'] = csrf;
    }
    return headers;
  }

  /// El `ga_refresh` de un `Set-Cookie`, para persistirlo fuera de web.
  String? _refreshFromSetCookie(Map<String, String> headers) {
    final setCookie = headers['set-cookie'];
    if (setCookie == null || setCookie.isEmpty) return null;
    return RegExp(r'ga_refresh=([^;]+)').firstMatch(setCookie)?.group(1);
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
