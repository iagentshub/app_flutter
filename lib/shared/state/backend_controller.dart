import 'package:flutter/foundation.dart';

import '../../core/config/backend_defaults.dart';
import '../../core/config/backend_option.dart';
import '../../core/storage/local_store.dart';

class BackendController extends ChangeNotifier {
  BackendController._({
    required String selectedBackendId,
    required String customBackendUrl,
    required List<String> savedBackendUrls,
  })  : _selectedBackendId = selectedBackendId,
        _customBackendUrl = customBackendUrl,
        _savedBackendUrls = savedBackendUrls;

  static const _selectedKey = 'selected_backend_id';
  static const _customUrlKey = 'custom_backend_url';
  static const _savedBackendsKey = 'saved_backend_urls';

  String _selectedBackendId;
  String _customBackendUrl;
  final List<String> _savedBackendUrls;

  static Future<BackendController> bootstrap() async {
    final prefs = await LocalStore.instance();
    final selected = prefs.getString(_selectedKey) ?? BackendDefaults.selectedBackendId;
    final customUrl = prefs.getString(_customUrlKey) ?? '';
    final savedUrls = prefs.getStringList(_savedBackendsKey) ?? <String>[];

    final migratedCustomUrl = _migrateLegacyBackend(customUrl);
    final migratedSaved = savedUrls.map(_migrateLegacyBackend).toList();

    final controller = BackendController._(
      selectedBackendId: selected,
      customBackendUrl: migratedCustomUrl,
      savedBackendUrls: _normalizeSavedBackends(migratedSaved),
    );

    if (controller._selectedBackendId == 'iagentshub_web') {
      controller._selectedBackendId = BackendDefaults.selectedBackendId;
    }

    if (!controller.options.any((option) => option.id == controller._selectedBackendId)) {
      controller._selectedBackendId = BackendDefaults.selectedBackendId;
    }

    await prefs.setString(_customUrlKey, controller._customBackendUrl);
    await prefs.setStringList(_savedBackendsKey, controller._savedBackendUrls);
    await prefs.setString(_selectedKey, controller._selectedBackendId);

    return controller;
  }

  List<BackendOption> get options => [
        ...BackendDefaults.options.where((option) => option.id != BackendDefaults.customBackendId),
        ..._savedBackendUrls.map(_savedOptionFromUrl),
        BackendDefaults.options.firstWhere((option) => option.id == BackendDefaults.customBackendId),
      ];

  List<String> get savedBackendUrls => List.unmodifiable(_savedBackendUrls);

  String get selectedBackendId => _selectedBackendId;
  String get customBackendUrl => _customBackendUrl;

  BackendOption get selectedOption {
    return options.firstWhere(
      (option) => option.id == _selectedBackendId,
      orElse: () => BackendDefaults.options.first,
    );
  }

  String get effectiveBaseUrl {
    if (selectedOption.id == BackendDefaults.customBackendId) {
      final normalized = normalizeBackendInput(_customBackendUrl);
      return normalized.isEmpty ? _customBackendUrl.trim() : normalized;
    }
    return selectedOption.baseUrl;
  }

  String? backendInputError(String? value) {
    if (value == null || value.trim().isEmpty) return 'La URL o host del backend es obligatoria';
    final normalized = normalizeBackendInput(value);
    if (normalized.isEmpty) return 'Backend invalido. Usa dominio/IP y puerto opcional';
    return null;
  }

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

    final path = (uri.path == '/' ? '' : uri.path).replaceFirst(RegExp(r'/$'), '');

    final normalized = Uri(
      scheme: uri.scheme.toLowerCase(),
      host: uri.host.toLowerCase(),
      port: uri.hasPort ? uri.port : null,
      path: path,
    ).toString();

    return normalized.endsWith('/') ? normalized.substring(0, normalized.length - 1) : normalized;
  }

  Future<void> setSelectedBackend(String id) async {
    _selectedBackendId = id;
    notifyListeners();
    final prefs = await LocalStore.instance();
    await prefs.setString(_selectedKey, id);
  }

  Future<void> setCustomBackendUrl(String url) async {
    _customBackendUrl = url.trim();
    notifyListeners();
    final prefs = await LocalStore.instance();
    await prefs.setString(_customUrlKey, _customBackendUrl);
  }

  Future<void> saveCustomBackend(String rawInput, {bool selectSaved = true}) async {
    final normalized = normalizeBackendInput(rawInput);
    if (normalized.isEmpty) {
      throw const FormatException('Backend invalido');
    }

    _customBackendUrl = normalized;
    if (!_savedBackendUrls.contains(normalized)) {
      _savedBackendUrls.insert(0, normalized);
    } else {
      _savedBackendUrls.remove(normalized);
      _savedBackendUrls.insert(0, normalized);
    }

    if (_savedBackendUrls.length > 12) {
      _savedBackendUrls.removeRange(12, _savedBackendUrls.length);
    }

    if (selectSaved) {
      _selectedBackendId = _savedBackendId(normalized);
    }

    notifyListeners();
    final prefs = await LocalStore.instance();
    await prefs.setString(_customUrlKey, _customBackendUrl);
    await prefs.setStringList(_savedBackendsKey, _savedBackendUrls);
    await prefs.setString(_selectedKey, _selectedBackendId);
  }

  static List<String> _normalizeSavedBackends(List<String> rawValues) {
    final unique = <String>[];
    for (final item in rawValues) {
      final value = item.trim();
      if (value.isEmpty || unique.contains(value)) continue;
      unique.add(value);
    }
    return unique;
  }

  static BackendOption _savedOptionFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) {
      return BackendOption(id: _savedBackendId(url), label: url, baseUrl: url);
    }

    final hostWithPort = uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
    final label = '${uri.scheme.toUpperCase()} $hostWithPort';
    return BackendOption(id: _savedBackendId(url), label: label, baseUrl: url);
  }

  static String _savedBackendId(String url) => 'saved:${Uri.encodeComponent(url)}';

  static String _migrateLegacyBackend(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return normalized;
    if (normalized == 'https://iagentshub.com' || normalized == 'http://iagentshub.com') {
      return 'https://www.iagentshub.com';
    }
    return normalized;
  }
}
