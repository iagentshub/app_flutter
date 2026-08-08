import 'package:flutter/widgets.dart';

import '../../../core/network/api_error.dart';
import '../../../models/connections/connection_models.dart';
import '../../../shared/state/action_result.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/utils/debouncer.dart';
import '../repositories/connections_repository.dart';

const connectionCategoryIds = ['llm', 'machine', 'database'];

enum ConnectionTestStatus { ok, error, pending }

typedef ConnectionFormPresenter =
    Future<Map<String, dynamic>?> Function(
      List<ConnectionProvider> providers,
      Map<String, dynamic>? initial,
      Future<List<String>> Function(String host) discoverOllamaModels,
    );

class ConnectionsMassTestSummary {
  const ConnectionsMassTestSummary({
    required this.results,
    required this.namesById,
  });

  final List<ConnectionTestResult> results;
  final Map<String, String> namesById;

  int get passed => results.where((result) => result.ok).length;
  int get failed => results.length - passed;
}

/// Orquesta el listado de conexiones, sus filtros y todas las mutaciones.
///
/// Los formularios, confirmaciones y el resumen del test masivo se inyectan
/// como callbacks porque necesitan `BuildContext`. El controller mantiene el
/// ciclo completo —preguntar, llamar, recargar— y devuelve [ActionResult] para
/// que la página decida cómo presentar el mensaje.
class ConnectionsController extends ChangeNotifier {
  ConnectionsController({
    required ConnectionsRepository repository,
    required SessionController sessionController,
    required String Function(String path, String fallback) tx,
  }) : _repository = repository,
       _sessionController = sessionController,
       _tx = tx;

  final ConnectionsRepository _repository;
  final SessionController _sessionController;
  final String Function(String path, String fallback) _tx;
  final Debouncer _searchDebouncer = Debouncer();

  final TextEditingController queryController = TextEditingController();

  bool _disposed = false;
  List<ConnectionItem> _connections = const [];
  List<ConnectionProvider> _providers = const [];
  bool _loading = true;
  bool _testingAll = false;
  String? _error;
  String _query = '';
  String? _activeGroupId;
  String _providerFilter = 'all';
  int _categoryIndex = 0;
  final Map<String, ConnectionTestStatus> _testStatus = {};
  final Map<String, String> _testMessages = {};

  // Colecciones vivas, no copias. Sólo este controller las muta.
  List<ConnectionItem> get connections => _connections;
  List<ConnectionProvider> get providers => _providers;
  bool get loading => _loading;
  bool get testingAll => _testingAll;
  String? get error => _error;
  String? get activeGroupId => _activeGroupId;
  String get providerFilter => _providerFilter;
  String get currentCategory => connectionCategoryIds[_categoryIndex];
  int get activeFilterCount => _providerFilter == 'all' ? 0 : 1;
  String? get token => _sessionController.gaToken;

  ConnectionTestStatus? testStatus(String id) => _testStatus[id];
  String? testMessage(String id) => _testMessages[id];

  String categoryOf(String type) {
    for (final provider in _providers) {
      if (provider.type == type) return provider.category;
    }
    return 'llm';
  }

  String providerLabel(String type) {
    for (final provider in _providers) {
      if (provider.type == type) return provider.label;
    }
    return type;
  }

  List<ConnectionProvider> providersForCategory(String category) =>
      _providers.where((provider) => provider.category == category).toList();

  List<ConnectionItem> get filteredConnections {
    final query = _query.trim().toLowerCase();
    return _connections.where((item) {
      if (categoryOf(item.type) != currentCategory) return false;
      if (_providerFilter != 'all' && item.type != _providerFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      return item.name.toLowerCase().contains(query) ||
          item.type.toLowerCase().contains(query) ||
          item.model.toLowerCase().contains(query);
    }).toList();
  }

  /// Agrupa el resultado filtrado por el label legible del proveedor.
  List<MapEntry<String, List<ConnectionItem>>> get connectionsByProvider {
    final groups = <String, List<ConnectionItem>>{};
    for (final item in filteredConnections) {
      groups.putIfAbsent(providerLabel(item.type), () => []).add(item);
    }
    return groups.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
  }

  void setCategoryIndex(int value) {
    if (value == _categoryIndex) return;
    _categoryIndex = value;
    _providerFilter = 'all';
    _notify();
  }

  void setProviderFilter(String value) {
    if (value == _providerFilter) return;
    _providerFilter = value;
    _notify();
  }

  void clearProviderFilter() => setProviderFilter('all');

  void setQuery(String value) {
    _query = value;
    _searchDebouncer.run(_notify);
  }

  Future<void> selectGroup(String? groupId) async {
    _activeGroupId = groupId;
    _notify();
    await load();
  }

  Future<void> load() async {
    final token = this.token;
    if (token == null || token.isEmpty) {
      _error = _tx('common.no_session', 'No hay sesión activa');
      _loading = false;
      _notify();
      return;
    }

    _loading = true;
    _error = null;
    _notify();
    try {
      final results = await Future.wait([
        _repository.listConnections(
          token,
          groupId: _activeGroupId,
          includeInactive: true,
        ),
        _repository.listProviders(token),
      ]);
      if (_disposed) return;
      _connections = results[0] as List<ConnectionItem>;
      _providers = results[1] as List<ConnectionProvider>;
      _loading = false;
    } on ApiError catch (error) {
      if (_disposed) return;
      _error = error.message;
      _loading = false;
    } catch (_) {
      if (_disposed) return;
      _error = _tx(
        'connections.error_generic',
        'No se pudieron cargar las conexiones',
      );
      _loading = false;
    }
    _notify();
  }

  Future<ActionResult?> createConnection({
    required ConnectionFormPresenter present,
  }) async {
    final categoryProviders = providersForCategory(currentCategory);
    final payload = await present(
      categoryProviders.isEmpty ? _providers : categoryProviders,
      null,
      discoverOllamaModels,
    );
    if (payload == null) return null;
    return _saveConnection(payload);
  }

  Future<ActionResult?> editConnection(
    ConnectionItem item, {
    required ConnectionFormPresenter present,
  }) async {
    if (item.isVirtual) {
      return ActionResult(
        _tx(
          'connections.virtual_edit',
          'Esta conexión es derivada de Ollama y no se edita directamente',
        ),
      );
    }
    final token = this.token;
    if (token == null || token.isEmpty) return null;

    Map<String, dynamic> initial = item.raw;
    try {
      initial = await _repository.getConnection(token, item.id);
    } catch (_) {
      // El formulario puede abrirse con los datos ya presentes en el listado.
    }
    if (_disposed) return null;
    final payload = await present(_providers, initial, discoverOllamaModels);
    if (payload == null) return null;
    return _saveConnection({...payload, 'id': item.id});
  }

  Future<List<String>> discoverOllamaModels(String host) async {
    final token = this.token;
    if (token == null || token.isEmpty) return const [];
    try {
      return await _repository.fetchOllamaModels(token, host);
    } catch (_) {
      return const [];
    }
  }

  Future<ActionResult?> _saveConnection(Map<String, dynamic> payload) async {
    final token = this.token;
    if (token == null || token.isEmpty) return null;
    try {
      await _repository.saveConnection(token, payload);
      await load();
      return ActionResult(_tx('connections.saved', 'Conexión guardada'));
    } on ApiError catch (error) {
      return ActionResult.error(error.message);
    } catch (_) {
      return ActionResult.error(
        _tx('connections.save_error', 'No se pudo guardar la conexión'),
      );
    }
  }

  Future<ActionResult?> toggleActive(ConnectionItem item) async {
    final token = this.token;
    if (token == null || token.isEmpty) return null;
    final activate = !item.isActive;
    try {
      await _repository.setConnectionActive(token, item.id, activate);
      await load();
      return ActionResult(
        activate
            ? _tx('connections.activated', 'Conexión activada')
            : _tx('connections.deactivated', 'Conexión desactivada'),
      );
    } on ApiError catch (error) {
      return ActionResult.error(error.message);
    } catch (_) {
      return ActionResult.error(
        _tx(
          'connections.toggle_error',
          'No se pudo cambiar el estado de la conexión',
        ),
      );
    }
  }

  Future<ActionResult?> syncHub(ConnectionItem item) async {
    final token = this.token;
    if (token == null || token.isEmpty) return null;
    try {
      final result = await _repository.syncHub(token, item.id);
      await load();
      return ActionResult(
        _tx(
              'connections.sync_success',
              'Sincronizado: {{agents}} agentes · {{skills}} skills · '
                  '{{knowledge}} conocimiento · {{connections}} conexiones',
            )
            .replaceAll('{{agents}}', '${result['agents'] ?? 0}')
            .replaceAll('{{skills}}', '${result['skills'] ?? 0}')
            .replaceAll('{{knowledge}}', '${result['knowledge'] ?? 0}')
            .replaceAll('{{connections}}', '${result['connections'] ?? 0}'),
      );
    } on ApiError catch (error) {
      return ActionResult.error(error.message);
    } catch (_) {
      return ActionResult.error(
        _tx('connections.sync_error', 'No se pudo sincronizar con el hub'),
      );
    }
  }

  Future<ActionResult?> deleteConnection(
    ConnectionItem item, {
    required Future<bool> Function() confirm,
  }) async {
    if (item.isVirtual) {
      return ActionResult(
        _tx(
          'connections.virtual_delete',
          'Esta conexión es derivada de Ollama y no se elimina directamente',
        ),
      );
    }
    if (!await confirm()) return null;
    final token = this.token;
    if (token == null || token.isEmpty) return null;
    try {
      await _repository.deleteConnection(token, item.id);
      await load();
      return ActionResult(_tx('connections.deleted', 'Conexión eliminada'));
    } on ApiError catch (error) {
      return ActionResult.error(error.message);
    } catch (_) {
      return ActionResult.error(
        _tx('connections.delete_error', 'No se pudo eliminar la conexión'),
      );
    }
  }

  Future<ActionResult?> testConnection(ConnectionItem item) async {
    if (item.isVirtual) {
      return ActionResult(
        _tx(
          'connections.virtual_test',
          'Esta conexión es derivada de Ollama y no se testea directamente',
        ),
      );
    }
    final token = this.token;
    if (token == null || token.isEmpty) return null;
    _testStatus[item.id] = ConnectionTestStatus.pending;
    _testMessages[item.id] = '';
    _notify();
    try {
      final result = await _repository.testConnection(token, item.id);
      if (_disposed) return null;
      _testStatus[item.id] = result.ok
          ? ConnectionTestStatus.ok
          : ConnectionTestStatus.error;
      _testMessages[item.id] = _testResultMessage(result);
    } on ApiError catch (error) {
      if (_disposed) return null;
      _testStatus[item.id] = ConnectionTestStatus.error;
      _testMessages[item.id] = error.message;
    } catch (_) {
      if (_disposed) return null;
      _testStatus[item.id] = ConnectionTestStatus.error;
      _testMessages[item.id] = _tx(
        'connections.test_error',
        'No se pudo testear la conexión',
      );
    }
    _notify();
    return null;
  }

  Future<ActionResult?> testAll({
    required Future<void> Function(ConnectionsMassTestSummary summary) present,
  }) async {
    final token = this.token;
    if (token == null || token.isEmpty) return null;
    final candidates = filteredConnections;
    final ids = candidates.map((item) => item.id).toList();
    if (ids.isEmpty) return null;
    final namesById = {for (final item in candidates) item.id: item.name};

    _testingAll = true;
    for (final id in ids) {
      _testStatus[id] = ConnectionTestStatus.pending;
      _testMessages[id] = '';
    }
    _notify();
    try {
      final results = await _repository.testAllConnections(token, ids: ids);
      if (_disposed) return null;
      for (final result in results) {
        _testStatus[result.id] = result.ok
            ? ConnectionTestStatus.ok
            : ConnectionTestStatus.error;
        _testMessages[result.id] = _testResultMessage(result);
      }
      // Un backend parcial tampoco debe dejar puntos en pending para siempre.
      _resetPendingStatus(ids);
      _notify();
      await present(
        ConnectionsMassTestSummary(results: results, namesById: namesById),
      );
      return null;
    } on ApiError catch (error) {
      _resetPendingStatus(ids);
      _notify();
      return ActionResult.error(error.message);
    } catch (_) {
      _resetPendingStatus(ids);
      _notify();
      return ActionResult.error(
        _tx('connections.mass_test_error', 'No se pudo ejecutar test masivo'),
      );
    } finally {
      if (!_disposed) {
        _testingAll = false;
        _notify();
      }
    }
  }

  String _testResultMessage(ConnectionTestResult result) {
    final detail = result.detail?.trim();
    return detail == null || detail.isEmpty
        ? result.message
        : '${result.message}\n$detail';
  }

  void _resetPendingStatus(List<String> ids) {
    for (final id in ids) {
      if (_testStatus[id] == ConnectionTestStatus.pending) {
        _testStatus.remove(id);
        _testMessages.remove(id);
      }
    }
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _searchDebouncer.dispose();
    queryController.dispose();
    super.dispose();
  }
}
