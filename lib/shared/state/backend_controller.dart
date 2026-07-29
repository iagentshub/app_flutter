import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/config/backend_defaults.dart';
import '../../core/config/backend_option.dart';
import '../../core/storage/local_store.dart';

/// Resultado de comprobar si un backend responde, usado tanto por el diálogo
/// de añadir/editar (comprobación manual) como por el chequeo periódico de
/// salud de la lista.
class BackendPingResult {
  const BackendPingResult({required this.ok, this.statusCode, this.error});

  final bool ok;
  final int? statusCode;
  final String? error;
}

/// Backend añadido a mano por el usuario (nombre + URL), a diferencia de los
/// oficiales en [BackendDefaults] que vienen predefinidos y no se eliminan.
class SavedBackend {
  const SavedBackend({required this.id, required this.name, required this.url});

  final String id;
  final String name;
  final String url;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'url': url};

  factory SavedBackend.fromJson(Map<String, dynamic> json) => SavedBackend(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    url: json['url']?.toString() ?? '',
  );
}

class BackendController extends ChangeNotifier {
  BackendController._({
    required String selectedBackendId,
    required List<SavedBackend> savedBackends,
  }) : _selectedBackendId = selectedBackendId,
       _savedBackends = savedBackends;

  static const _selectedKey = 'selected_backend_id';
  static const _savedBackendsJsonKey = 'saved_backends_json';
  // Claves del esquema anterior (URL suelta sin nombre), solo para migración.
  static const _legacyCustomUrlKey = 'custom_backend_url';
  static const _legacySavedUrlsKey = 'saved_backend_urls';

  String _selectedBackendId;
  final List<SavedBackend> _savedBackends;

  // Último fallo de conexión detectado por ApiClient contra el backend
  // seleccionado (fallo de red real, no una respuesta HTTP de error) — se
  // limpia solo cuando una petición vuelve a tener éxito o al cambiar de
  // backend, para no mostrar un aviso obsoleto de un backend distinto.
  String? _lastConnectionError;
  DateTime? _lastConnectionErrorAt;

  static Future<BackendController> bootstrap() async {
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
    );

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
    var value = input.trim();
    if (value.isEmpty) return '';

    if (!value.contains('://')) {
      final hostPart = value.split('/').first.toLowerCase();
      final localOrIp = RegExp(
        r'^(localhost|127\.|10\.|192\.168\.|172\.(1[6-9]|2\d|3[0-1])\.|\d{1,3}(?:\.\d{1,3}){3})',
      );
      final scheme = localOrIp.hasMatch(hostPart) ? 'http' : 'https';
      value = '$scheme://$value';
    }

    final uri = Uri.tryParse(value);
    if (uri == null) return '';
    if (uri.host.isEmpty) return '';
    if (uri.scheme != 'http' && uri.scheme != 'https') return '';

    final path = (uri.path == '/' ? '' : uri.path).replaceFirst(
      RegExp(r'/$'),
      '',
    );

    final normalized = Uri(
      scheme: uri.scheme.toLowerCase(),
      host: uri.host.toLowerCase(),
      port: uri.hasPort ? uri.port : null,
      path: path,
    ).toString();

    return normalized.endsWith('/')
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
  }

  /// Combina host + puerto opcional en una única cadena para normalizar.
  String composeHostAndPort(String host, String port) {
    final trimmedHost = host.trim();
    final trimmedPort = port.trim();
    if (trimmedHost.isEmpty) return '';
    if (trimmedPort.isEmpty) return trimmedHost;
    return '$trimmedHost:$trimmedPort';
  }

  /// Descompone una URL guardada en host + puerto para precargar el
  /// formulario de edición. `port` viene vacío si la URL no especifica uno.
  ({String host, String port}) splitHostAndPort(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return (host: url, port: '');
    return (host: uri.host, port: uri.hasPort ? '${uri.port}' : '');
  }

  /// Comprueba si un backend responde en `/api/settings/platform/public`,
  /// sin necesidad de sesión. Usado tanto por el test manual del diálogo
  /// como por el chequeo periódico de salud de la lista.
  Future<BackendPingResult> pingBackend(String baseUrl) async {
    try {
      final uri = Uri.parse('$baseUrl/api/settings/platform/public');
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return BackendPingResult(ok: true, statusCode: response.statusCode);
      }
      return BackendPingResult(ok: false, statusCode: response.statusCode);
    } catch (error) {
      return BackendPingResult(ok: false, error: error.toString());
    }
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
    final entry = SavedBackend(
      id: _newId(),
      name: name.trim().isEmpty ? _labelFromUrl(url) : name.trim(),
      url: url,
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
    final updated = SavedBackend(
      id: id,
      name: name.trim().isEmpty ? _labelFromUrl(url) : name.trim(),
      url: url,
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
