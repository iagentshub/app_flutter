import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/config/backend_defaults.dart';
import '../../core/config/backend_option.dart';
import '../../core/config/backend_url.dart';
import '../../core/storage/local_store.dart';
import '../../models/backend/backend_models.dart';
import '../../utils/i18n.dart';

export '../../models/backend/backend_models.dart';

class BackendController extends ChangeNotifier {
  BackendController._({
    required String selectedBackendId,
    required List<SavedBackend> savedBackends,
    http.Client? pingClient,
  }) : _selectedBackendId = selectedBackendId,
       _savedBackends = savedBackends,
       _pingClient = pingClient;

  static const _selectedKey = 'selected_backend_id';
  static const _savedBackendsJsonKey = 'saved_backends_json';
  // Claves del esquema anterior (URL suelta sin nombre), solo para migración.
  static const _legacyCustomUrlKey = 'custom_backend_url';
  static const _legacySavedUrlsKey = 'saved_backend_urls';

  String _selectedBackendId;
  final List<SavedBackend> _savedBackends;
  final http.Client? _pingClient;

  // Último fallo de conexión detectado por ApiClient contra el backend
  // seleccionado (fallo de red real, no una respuesta HTTP de error) — se
  // limpia solo cuando una petición vuelve a tener éxito o al cambiar de
  // backend, para no mostrar un aviso obsoleto de un backend distinto.
  String? _lastConnectionError;
  DateTime? _lastConnectionErrorAt;

  static Future<BackendController> bootstrap({http.Client? pingClient}) async {
    final prefs = await LocalStore.instance();
    var selected =
        prefs.getString(_selectedKey) ?? BackendDefaults.selectedBackendId;

    List<SavedBackend> saved;
    final savedJson = prefs.getString(_savedBackendsJsonKey);
    if (savedJson != null) {
      saved = _decodeSaved(savedJson);
    } else {
      saved = _migrateLegacySaved(
        prefs.getStringList(_legacySavedUrlsKey) ?? const <String>[],
      );
      // El backend "custom" del esquema anterior guardaba su URL activa aparte,
      // sin necesariamente estar en la lista de guardados: si era el
      // seleccionado, se migra también para no perder la conexión activa.
      final legacyCustomUrl = _migrateLegacyUrl(
        prefs.getString(_legacyCustomUrlKey) ?? '',
      );
      if (selected == 'custom' &&
          legacyCustomUrl.isNotEmpty &&
          !saved.any((b) => b.url == legacyCustomUrl)) {
        saved = [
          SavedBackend(
            id: _newId(),
            name: _labelFromUrl(legacyCustomUrl),
            url: legacyCustomUrl,
          ),
          ...saved,
        ];
      }
    }

    if (selected == 'iagentshub_web') {
      selected = BackendDefaults.selectedBackendId;
    }
    if (selected == 'custom') {
      selected = saved.isNotEmpty
          ? saved.first.id
          : BackendDefaults.selectedBackendId;
    }

    final controller = BackendController._(
      selectedBackendId: selected,
      savedBackends: saved,
      pingClient: pingClient,
    );
    for (var i = controller._savedBackends.length - 1; i >= 0; i--) {
      final entry = controller._savedBackends[i];
      final normalized = controller.normalizeBackendInput(entry.url);
      if (normalized.isEmpty) {
        controller._savedBackends.removeAt(i);
      } else if (normalized != entry.url) {
        controller._savedBackends[i] = SavedBackend(
          id: entry.id,
          name: entry.name,
          url: normalized,
        );
      }
    }

    if (!controller.options.any(
      (option) => option.id == controller._selectedBackendId,
    )) {
      controller._selectedBackendId = BackendDefaults.selectedBackendId;
    }

    await controller._persist();
    return controller;
  }

  /// Oficiales primero (fijos, no editables), luego los añadidos por el
  /// usuario en el orden en que se añadieron.
  List<BackendOption> get options => [
    ...BackendDefaults.options,
    ..._savedBackends.map(
      (b) => BackendOption(id: b.id, label: b.name, baseUrl: b.url),
    ),
  ];

  List<SavedBackend> get savedBackends => List.unmodifiable(_savedBackends);

  bool isOfficial(String id) =>
      BackendDefaults.options.any((option) => option.id == id);

  String? get lastConnectionError => _lastConnectionError;
  DateTime? get lastConnectionErrorAt => _lastConnectionErrorAt;
  bool get hasConnectionIssue => _lastConnectionError != null;

  /// Llamado por [ApiClient] cuando una petición falla por no poder
  /// alcanzar la red (no por un 4xx/5xx del servidor, eso es un error de
  /// API normal, no un problema de backend).
  void reportConnectionError(String message) {
    _lastConnectionError = message;
    _lastConnectionErrorAt = DateTime.now();
    notifyListeners();
  }

  /// Llamado por [ApiClient] tras cualquier respuesta HTTP recibida
  /// (incluidos 4xx/5xx): si llegó respuesta, el backend es alcanzable.
  void reportConnectionOk() {
    if (_lastConnectionError == null) return;
    _lastConnectionError = null;
    _lastConnectionErrorAt = null;
    notifyListeners();
  }

  String get selectedBackendId => _selectedBackendId;

  BackendOption get selectedOption {
    return options.firstWhere(
      (option) => option.id == _selectedBackendId,
      orElse: () => BackendDefaults.options.first,
    );
  }

  String get effectiveBaseUrl => selectedOption.baseUrl;

  /// Normaliza "host[:puerto]" (o una URL completa) a una URL absoluta.
  /// Localhost/IPs privadas usan http por defecto; el resto, https.
  /// Devuelve cadena vacía si el input no es un host válido.
  String normalizeBackendInput(String input) {
    return BackendUrl.normalize(input);
  }

  /// Combina host + puerto opcional en una única cadena para normalizar.
  String composeHostAndPort(String host, String port) {
    return BackendUrl.composeHostAndPort(host, port);
  }

  /// Descompone una URL guardada en host + puerto para precargar el
  /// formulario de edición. `port` viene vacío si la URL no especifica uno.
  ({String host, String port}) splitHostAndPort(String url) {
    return BackendUrl.splitHostAndPort(url);
  }

  /// Comprueba si un backend responde en `/api/settings/platform/public`,
  /// sin necesidad de sesión, y valida que la respuesta tenga el contrato
  /// público de iAgents Hub. Usado tanto por el test manual del diálogo como
  /// por el chequeo periódico de salud de la lista.
  Future<BackendPingResult> pingBackend(String baseUrl) async {
    final normalized = normalizeBackendInput(baseUrl);
    if (normalized.isEmpty) {
      return const BackendPingResult(ok: false, error: 'URL no permitida');
    }
    try {
      final uri = Uri.parse('$normalized/api/settings/platform/public');
      final response = await (_pingClient?.get(uri) ?? http.get(uri)).timeout(
        const Duration(seconds: 8),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Object? payload;
        try {
          payload = jsonDecode(response.body);
        } catch (_) {
          return BackendPingResult(
            ok: false,
            statusCode: response.statusCode,
            error: tr('auth.backend_not_json'),
          );
        }
        if (!_isCompatibleBackend(payload)) {
          return BackendPingResult(
            ok: false,
            statusCode: response.statusCode,
            error: tr('auth.backend_incompatible'),
          );
        }
        return BackendPingResult(ok: true, statusCode: response.statusCode);
      }
      return BackendPingResult(ok: false, statusCode: response.statusCode);
    } catch (error) {
      return BackendPingResult(ok: false, error: error.toString());
    }
  }

  static bool _isCompatibleBackend(Object? payload) {
    if (payload is! Map<String, dynamic>) return false;
    if (payload['service'] == 'iagentshub') {
      return payload['api_version'] is int;
    }

    // Compatibilidad con backends anteriores al identificador explícito. Son
    // campos estables y tipados del mismo endpoint que consume el login.
    return payload['registration'] is String &&
        payload['guest_enabled'] is bool &&
        payload['billing_enabled'] is bool;
  }

  Future<void> setSelectedBackend(String id) async {
    if (!options.any((option) => option.id == id)) return;
    _selectedBackendId = id;
    // El aviso de fallo de conexión pertenecía al backend anterior.
    _lastConnectionError = null;
    _lastConnectionErrorAt = null;
    notifyListeners();
    final prefs = await LocalStore.instance();
    await prefs.setString(_selectedKey, id);
  }

  /// Añade un backend ya verificado (conexión OK) a la lista de guardados.
  /// No lo selecciona automáticamente: el usuario lo elige aparte.
  Future<SavedBackend> addBackend({
    required String name,
    required String url,
  }) async {
    final normalized = normalizeBackendInput(url);
    if (normalized.isEmpty) {
      throw ArgumentError.value(url, 'url', 'URL de backend no permitida');
    }
    final entry = SavedBackend(
      id: _newId(),
      name: name.trim().isEmpty ? _labelFromUrl(normalized) : name.trim(),
      url: normalized,
    );
    _savedBackends.add(entry);
    notifyListeners();
    await _persist();
    return entry;
  }

  /// Igual que [addBackend] pero sobre una entrada ya guardada. Solo aplica
  /// a backends del usuario; los oficiales no son editables (ver [isOfficial]).
  Future<SavedBackend> updateBackend(
    String id, {
    required String name,
    required String url,
  }) async {
    final index = _savedBackends.indexWhere((b) => b.id == id);
    if (index == -1) {
      throw StateError('Backend no encontrado: $id');
    }
    final normalized = normalizeBackendInput(url);
    if (normalized.isEmpty) {
      throw ArgumentError.value(url, 'url', 'URL de backend no permitida');
    }
    final updated = SavedBackend(
      id: id,
      name: name.trim().isEmpty ? _labelFromUrl(normalized) : name.trim(),
      url: normalized,
    );
    _savedBackends[index] = updated;
    notifyListeners();
    await _persist();
    return updated;
  }

  /// Solo los backends añadidos por el usuario se pueden eliminar; los
  /// oficiales de [BackendDefaults] no pasan por aquí (ver [isOfficial]).
  Future<void> removeBackend(String id) async {
    _savedBackends.removeWhere((b) => b.id == id);
    if (_selectedBackendId == id) {
      _selectedBackendId = BackendDefaults.selectedBackendId;
    }
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await LocalStore.instance();
    await prefs.setString(_selectedKey, _selectedBackendId);
    await prefs.setString(
      _savedBackendsJsonKey,
      jsonEncode(_savedBackends.map((b) => b.toJson()).toList()),
    );
  }

  static List<SavedBackend> _decodeSaved(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(SavedBackend.fromJson)
          .where((b) => b.url.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static List<SavedBackend> _migrateLegacySaved(List<String> rawUrls) {
    final seen = <String>{};
    final result = <SavedBackend>[];
    for (final raw in rawUrls) {
      final url = _migrateLegacyUrl(raw);
      if (url.isEmpty || !seen.add(url)) continue;
      result.add(
        SavedBackend(id: _newId(), name: _labelFromUrl(url), url: url),
      );
    }
    return result;
  }

  static String _labelFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return url;
    final hostWithPort = uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
    return hostWithPort;
  }

  static String _migrateLegacyUrl(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return normalized;
    if (normalized == 'https://iagentshub.com' ||
        normalized == 'http://iagentshub.com') {
      return 'https://www.iagentshub.com';
    }
    return normalized;
  }

  static int _idCounter = 0;

  static String _newId() {
    _idCounter += 1;
    return 'saved:${DateTime.now().microsecondsSinceEpoch}_$_idCounter';
  }
}
