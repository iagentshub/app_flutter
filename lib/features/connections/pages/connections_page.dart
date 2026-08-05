import 'package:flutter/material.dart';

import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/async_state_panel.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../models/connections/connection_models.dart';
import '../cards/connection_card.dart';
import '../repositories/connections_repository.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/utils/debouncer.dart';
import '../../../shared/widgets/buttons/filter_button.dart';
import '../../../shared/widgets/confirm_action_dialog.dart';
import '../../../shared/widgets/group_filter_panel.dart';
import '../../../shared/widgets/responsive_dialog.dart';
import '../../../shared/widgets/responsive_masonry_grid.dart';
import '../../../shared/widgets/resource_toolbar.dart';
import '../../../shared/widgets/share_to_group_dialog.dart';
import '../../../shared/widgets/status_dot.dart';

part '../dialogs/connection_form_dialog.dart';
part '../widgets/connections_page_view.dart';

class ConnectionsPage extends StatefulWidget {
  const ConnectionsPage({
    required this.apiClient,
    required this.sessionController,
    required this.localeController,
    super.key,
  });

  final ApiClient apiClient;
  final SessionController sessionController;
  final LocaleController localeController;

  @override
  State<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends State<ConnectionsPage>
    with SingleTickerProviderStateMixin {
  late final ConnectionsRepository _repository;
  late final TranslatedTexts _t;
  late final TabController _tabController;
  final TextEditingController _queryController = TextEditingController();
  final Debouncer _searchDebouncer = Debouncer();
  List<ConnectionItem> _connections = const [];
  List<ConnectionProvider> _providers = const [];
  bool _loading = true;
  bool _testingAll = false;
  String? _error;
  String _query = '';
  String? _activeGroupId;
  String _providerFilter = 'all';
  int _lastCategoryIndex = 0;

  /// Resultado del último test por conexión, solo en memoria de esta
  /// sesión — sin entrada = aún no se ha probado, la card no pinta punto.
  final Map<String, StatusDotState> _testStatus = {};
  final Map<String, String> _testMessages = {};

  static const _categoryIds = ['llm', 'machine', 'database'];

  String _tx(String path, String fallback) => _t.text(path, fallback: fallback);

  String _categoryOf(String type) {
    for (final provider in _providers) {
      if (provider.type == type) return provider.category;
    }
    return 'llm';
  }

  String _providerLabel(String type) {
    for (final provider in _providers) {
      if (provider.type == type) return provider.label;
    }
    return type;
  }

  List<ConnectionProvider> _providersForCategory(String category) {
    return _providers.where((p) => p.category == category).toList();
  }

  /// Agrupa las conexiones filtradas por proveedor (label legible, orden
  /// alfabético) — para pintar una cabecera por grupo en vez de una rejilla
  /// plana con todos los tipos mezclados.
  List<MapEntry<String, List<ConnectionItem>>> get _connectionsByProvider {
    final groups = <String, List<ConnectionItem>>{};
    for (final item in _filteredConnections) {
      groups.putIfAbsent(_providerLabel(item.type), () => []).add(item);
    }
    final entries = groups.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    return entries;
  }

  int get _activeFilterCount => _providerFilter != 'all' ? 1 : 0;

  List<ConnectionItem> get _filteredConnections {
    final category = _categoryIds[_tabController.index];
    final query = _query.trim().toLowerCase();
    return _connections.where((item) {
      if (_categoryOf(item.type) != category) return false;
      if (_providerFilter != 'all' && item.type != _providerFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      return item.name.toLowerCase().contains(query) ||
          item.type.toLowerCase().contains(query) ||
          item.model.toLowerCase().contains(query);
    }).toList();
  }

  void _openFiltersDialog() {
    final category = _categoryIds[_tabController.index];
    final providerOptions = [
      ('all', _tx('explore.option_all', 'Todas')),
      ..._providersForCategory(
        category,
      ).map((p) => (p.type, p.label.isEmpty ? p.type : p.label)),
    ];

    showFilterDialog(
      context,
      title: _tx('common.filters', 'Filtros'),
      clearLabel: _tx('common.clear_filters', 'Limpiar filtros'),
      closeLabel: _tx('common.close', 'Cerrar'),
      onClear: () => setState(() => _providerFilter = 'all'),
      buildFields: (setDialogState) => [
        FilterDropdown(
          label: _tx('connections.provider_label', 'Proveedor'),
          value: _providerFilter,
          options: providerOptions,
          onChanged: (v) {
            setState(() => _providerFilter = v);
            setDialogState(() {});
          },
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _repository = ConnectionsRepository(apiClient: widget.apiClient);
    _tabController = TabController(length: _categoryIds.length, vsync: this)
      ..addListener(_onTabChanged);
    _t = TranslatedTexts(
      localeController: widget.localeController,
      namespace: 'resources',
    )..addListener(_onTextsChanged);
    _load();
  }

  void _onTabChanged() {
    if (!mounted) return;
    final index = _tabController.index;
    if (index != _lastCategoryIndex) {
      _lastCategoryIndex = index;
      _providerFilter = 'all';
    }
    setState(() {});
  }

  void _onTextsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchDebouncer.dispose();
    _queryController.dispose();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _t.removeListener(_onTextsChanged);
    _t.dispose();
    super.dispose();
  }

  String? get _token => widget.sessionController.gaToken;

  Future<void> _load() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = _tx('common.no_session', 'No hay sesión activa');
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _repository.listConnections(
          token,
          groupId: _activeGroupId,
          includeInactive: true,
        ),
        _repository.listProviders(token),
      ]);

      if (!mounted) return;
      setState(() {
        _connections = results[0] as List<ConnectionItem>;
        _providers = results[1] as List<ConnectionProvider>;
        _loading = false;
      });
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = _tx(
          'connections.error_generic',
          'No se pudieron cargar las conexiones',
        );
        _loading = false;
      });
    }
  }

  void _onGroupSelect(String? groupId) {
    setState(() => _activeGroupId = groupId);
    _load();
  }

  Future<void> _shareConnection(ConnectionItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    await showShareToGroupDialog(
      context: context,
      apiClient: widget.apiClient,
      token: token,
      resourceType: 'connection',
      resourceId: item.id,
      localeController: widget.localeController,
      onShared: _load,
    );
  }

  Future<void> _openCreateDialog() async {
    final category = _categoryIds[_tabController.index];
    final providers = _providersForCategory(category);
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ConnectionFormDialog(
        providers: providers.isEmpty ? _providers : providers,
        tx: _tx,
        onDiscoverOllamaModels: _discoverOllamaModels,
      ),
    );

    if (payload == null) return;
    await _saveConnection(payload);
  }

  /// Modelos instalados en un host Ollama en vivo, para el selector del
  /// formulario de alta/edición — lista vacía si falla (host no accesible,
  /// timeout, etc.), el diálogo se encarga de avisar al usuario.
  Future<List<String>> _discoverOllamaModels(String host) async {
    final token = _token;
    if (token == null || token.isEmpty) return const [];
    try {
      return await _repository.fetchOllamaModels(token, host);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _openEditDialog(ConnectionItem item) async {
    if (item.isVirtual) {
      _showMessage(
        'Esta conexión es derivada de Ollama y no se edita directamente',
      );
      return;
    }

    final token = _token;
    if (token == null || token.isEmpty) return;

    Map<String, dynamic> initial = item.raw;
    try {
      initial = await _repository.getConnection(token, item.id);
    } catch (_) {
      // Si falla detalle, intentamos editar con lo ya cargado en lista.
    }

    if (!mounted) return;
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ConnectionFormDialog(
        providers: _providers,
        initial: initial,
        tx: _tx,
        onDiscoverOllamaModels: _discoverOllamaModels,
      ),
    );

    if (payload == null) return;
    payload['id'] = item.id;
    await _saveConnection(payload);
  }

  Future<void> _saveConnection(Map<String, dynamic> payload) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    try {
      await _repository.saveConnection(token, payload);
      _showMessage('Conexión guardada');
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo guardar la conexión', isError: true);
    }
  }

  Future<void> _toggleConnectionActive(ConnectionItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    final activate = !item.isActive;
    try {
      await _repository.setConnectionActive(token, item.id, activate);
      _showMessage(activate ? 'Conexión activada' : 'Conexión desactivada');
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage(
        'No se pudo cambiar el estado de la conexión',
        isError: true,
      );
    }
  }

  Future<void> _syncHub(ConnectionItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    try {
      final result = await _repository.syncHub(token, item.id);
      final parts = <String>[
        '${result['agents'] ?? 0} agentes',
        '${result['skills'] ?? 0} skills',
        '${result['knowledge'] ?? 0} conocimiento',
        '${result['connections'] ?? 0} conexiones',
      ];
      _showMessage('Sincronizado: ${parts.join(' · ')}');
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo sincronizar con el hub', isError: true);
    }
  }

  Future<void> _deleteConnection(ConnectionItem item) async {
    if (item.isVirtual) {
      _showMessage(
        'Esta conexión es derivada de Ollama y no se elimina directamente',
      );
      return;
    }

    final confirm = await showConfirmActionDialog(
      context,
      title: 'Eliminar conexión',
      message: '¿Seguro que quieres eliminar "${item.name}"?',
      cancelLabel: 'Cancelar',
      confirmLabel: 'Eliminar',
    );
    if (!confirm) return;

    final token = _token;
    if (token == null || token.isEmpty) return;

    try {
      await _repository.deleteConnection(token, item.id);
      _showMessage('Conexión eliminada');
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo eliminar la conexión', isError: true);
    }
  }

  Future<void> _testConnection(ConnectionItem item) async {
    if (item.isVirtual) {
      _showMessage(
        'Esta conexión es derivada de Ollama y no se testea directamente',
      );
      return;
    }

    final token = _token;
    if (token == null || token.isEmpty) return;
    setState(() {
      _testStatus[item.id] = StatusDotState.pending;
      _testMessages[item.id] = '';
    });
    try {
      final result = await _repository.testConnection(token, item.id);
      final detail = result.detail?.trim().isNotEmpty == true
          ? '\n${result.detail}'
          : '';
      if (!mounted) return;
      setState(() {
        _testStatus[item.id] = result.ok
            ? StatusDotState.ok
            : StatusDotState.error;
        _testMessages[item.id] = '${result.message}$detail';
      });
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _testStatus[item.id] = StatusDotState.error;
        _testMessages[item.id] = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _testStatus[item.id] = StatusDotState.error;
        _testMessages[item.id] = 'No se pudo testear la conexión';
      });
    }
  }

  /// Si el test masivo falla antes de traer resultados por conexión, los
  /// puntos que se dejaron en "pending" no deben quedarse así para siempre.
  void _resetPendingStatus(List<String> ids) {
    if (!mounted) return;
    setState(() {
      for (final id in ids) {
        if (_testStatus[id] == StatusDotState.pending) {
          _testStatus.remove(id);
        }
      }
    });
  }

  Future<void> _testAll() async {
    final token = _token;
    if (token == null || token.isEmpty) return;

    final connections = _filteredConnections;
    final ids = connections.map((item) => item.id).toList();
    if (ids.isEmpty) return;
    final namesById = {for (final c in connections) c.id: c.name};

    setState(() {
      _testingAll = true;
      for (final id in ids) {
        _testStatus[id] = StatusDotState.pending;
        _testMessages[id] = '';
      }
    });
    try {
      final results = await _repository.testAllConnections(token, ids: ids);
      if (!mounted) return;
      setState(() {
        for (final r in results) {
          _testStatus[r.id] = r.ok ? StatusDotState.ok : StatusDotState.error;
          final detail = r.detail?.trim().isNotEmpty == true
              ? '\n${r.detail}'
              : '';
          _testMessages[r.id] = '${r.message}$detail';
        }
      });
      final ok = results.where((r) => r.ok).length;
      final fail = results.length - ok;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Test masivo (${results.length})'),
          content: SizedBox(
            width: dialogContentWidth(context, 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Correctas: $ok | Fallidas: $fail'),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: results
                        .map(
                          (r) => ListTile(
                            dense: true,
                            leading: Icon(
                              r.ok
                                  ? Icons.check_circle_outline
                                  : Icons.error_outline,
                            ),
                            title: Text(namesById[r.id] ?? r.id),
                            subtitle: Text(r.message),
                            trailing: r.latencyMs == null
                                ? null
                                : Text('${r.latencyMs}ms'),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            PrimaryButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } on ApiError catch (error) {
      _resetPendingStatus(ids);
      _showMessage(error.message, isError: true);
    } catch (_) {
      _resetPendingStatus(ids);
      _showMessage('No se pudo ejecutar test masivo', isError: true);
    } finally {
      if (mounted) {
        setState(() => _testingAll = false);
      }
    }
  }

  void _showMessage(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.red.shade700 : null,
      ),
    );
  }

  void _refresh(VoidCallback update) => setState(update);

  @override
  Widget build(BuildContext context) => _buildPage(context);
}
