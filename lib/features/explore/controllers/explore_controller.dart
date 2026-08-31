import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../core/network/api_error.dart';
import '../../../core/network/cursor_pagination_exception.dart';
import '../../../core/network/page_result.dart';
import '../../../models/explore/explore_models.dart';
import '../../../models/manager/group_models.dart';
import '../../../shared/graph/resource_graph_builder.dart';
import '../../../shared/state/action_result.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/utils/debouncer.dart';
import '../../manager/repositories/manager_repository.dart';
import '../repositories/explore_repository.dart';

part 'explore_resource_loading.dart';

/// Orquesta las dos pestañas de Explore (recursos y usuarios).
///
/// Saca del `State` de la página la carga, los filtros y las acciones sobre
/// cada recurso o usuario. La página se limita a escuchar y pintar.
///
/// Los mensajes de resultado se **devuelven** como [ActionResult] en vez de
/// mostrarse aquí: el SnackBar necesita un `BuildContext` que el controller
/// no tiene. `null` significa que no hay nada que mostrar.
class ExploreController extends ChangeNotifier {
  ExploreController({
    required this._repository,
    required this._managerRepository,
    required this._sessionController,
    required this._tx,
  });

  static const usersPageSize = 20;
  static const resourcesPageSize = 40;

  final ExploreRepository _repository;
  final ManagerRepository _managerRepository;
  final SessionController _sessionController;
  final String Function(String path) _tx;

  final TextEditingController queryController = TextEditingController();
  final TextEditingController userQueryController = TextEditingController();
  final Debouncer _userSearchDebouncer = Debouncer();

  bool _disposed = false;

  // ── Pestaña Recursos ──────────────────────────────────────────────────

  List<ExploreItem> _items = const [];
  List<ExploreOfficialPack> _officialPacks = const [];
  bool _officialPacksMode = true;
  bool _loading = true;
  bool _resourcesLoadingMore = false;
  bool _resourcesHasMore = false;
  String? _nextResourcesCursor;
  final Set<String> _seenResourceCursors = <String>{};
  String? _error;
  String _type = 'all';
  String _relation = ExploreRelation.nuevo;
  int _linkedMatches = 0;
  String _category = '';
  final Set<String> _labels = <String>{};
  final Set<String> _languages = <String>{};
  final Map<String, int> _typeCounts = <String, int>{};
  final Set<String> _busyKeys = <String>{};
  final Set<String> _linkedKeys = <String>{};
  // La estrella se puede poner y quitar, así que no basta un conjunto de
  // «marcados en esta pantalla»: el override guarda los dos sentidos sobre lo
  // que trajo el catálogo.
  final Map<String, bool> _starOverride = <String, bool>{};
  final Set<String> _busyPackIds = <String>{};
  int _resourceLoadGeneration = 0;
  Timer? _resourceFilterTimer;
  Completer<void>? _resourceFilterCompleter;

  // Los getters devuelven la colección viva, no una copia: `build` los
  // consulta una vez por elemento y copiar aquí sería cuadrático. Sólo el
  // controller tiene la referencia mutable.
  List<ExploreItem> get items => _items;
  List<ExploreOfficialPack> get officialPacks => _officialPacks;
  bool get officialPacksMode => _officialPacksMode;
  int get resultCount => _items.length + _officialPacks.length;
  bool get loading => _loading;
  bool get resourcesLoadingMore => _resourcesLoadingMore;
  bool get resourcesHasMore => _resourcesHasMore;
  String? get error => _error;
  String get type => _type;
  String get relation => _relation;
  String get category => _category;

  /// Cuántos resultados de la búsqueda actual quedaron fuera por estar ya
  /// enlazados. Solo se calcula cuando «Nuevos» no devuelve nada: sin este
  /// dato el vacío parece un buscador roto.
  int get linkedMatches => _linkedMatches;
  Set<String> get selectedLabels => Set.unmodifiable(_labels);
  Set<String> get selectedLanguages => Set.unmodifiable(_languages);
  int typeCount(String type) => _typeCounts[type] ?? 0;

  bool hasLabel(String label) => _labels.contains(label);
  bool hasLanguage(String language) => _languages.contains(language);
  bool isBusy(ExploreItem item) => _busyKeys.contains(itemKey(item));

  /// El catálogo ya trae el estado (`linked_by_me`); `_linkedKeys` solo cubre
  /// lo enlazado en esta pantalla, para que la tarjeta cambie sin esperar a
  /// la siguiente carga.
  bool isLinked(ExploreItem item) =>
      item.linkedByMe || _linkedKeys.contains(itemKey(item));
  bool isStarred(ExploreItem item) =>
      _starOverride[itemKey(item)] ?? item.starred;
  bool isPackBusy(ExploreOfficialPack pack) =>
      _busyPackIds.contains(pack.sourceId);

  String itemKey(ExploreItem item) => '${item.resourceType}:${item.resourceId}';

  /// Categorías presentes en los resultados actuales, para poblar el filtro.
  List<String> get categoryOptions {
    final set = <String>{};
    for (final item in _items) {
      if (item.category.isNotEmpty) set.add(item.category);
    }
    return set.toList()..sort();
  }

  // La relación cuenta como filtro activo cuando no es el valor por defecto:
  // si no, «Todos» y «Enlazados» esconderían o añadirían resultados sin que
  // nada en la barra lo indique.
  int get secondaryActiveFilterCount =>
      (_category.isNotEmpty ? 1 : 0) +
      _labels.length +
      _languages.length +
      (_relation == ExploreRelation.nuevo ? 0 : 1);

  // ── Pestaña Usuarios ──────────────────────────────────────────────────

  List<ExploreUserItem> _users = const [];
  bool _usersLoading = true;
  bool _usersLoadingMore = false;
  String? _usersError;
  bool _usersHasMore = false;
  String? _nextUsersCursor;
  final Set<String> _seenUserCursors = <String>{};
  final Set<String> _invitingUsernames = <String>{};

  List<ExploreUserItem> get users => _users;
  bool get usersLoading => _usersLoading;
  bool get usersLoadingMore => _usersLoadingMore;
  String? get usersError => _usersError;
  bool get usersHasMore => _usersHasMore;

  bool isInviting(String username) => _invitingUsernames.contains(username);

  // ── Filtros ───────────────────────────────────────────────────────────

  Future<void> setType(String value) {
    _type = value;
    _notify();
    return _scheduleResourceLoad();
  }

  Future<void> setOfficialPacksMode(bool value) {
    if (_officialPacksMode == value) return Future.value();
    _officialPacksMode = value;
    _notify();
    return _scheduleResourceLoad();
  }

  Future<void> setRelation(String value) {
    if (_relation == value) return Future.value();
    _relation = value;
    _notify();
    return _scheduleResourceLoad();
  }

  Future<void> setCategory(String value) {
    _category = value;
    _notify();
    return _scheduleResourceLoad();
  }

  Future<void> toggleLabel(String label, {required bool selected}) {
    if (selected) {
      _labels.add(label);
    } else {
      _labels.remove(label);
    }
    _notify();
    return _scheduleResourceLoad();
  }

  Future<void> toggleLanguage(String language, {required bool selected}) {
    if (selected) {
      _languages.add(language);
    } else {
      _languages.remove(language);
    }
    _notify();
    return _scheduleResourceLoad();
  }

  Future<void> setLabels(Set<String> labels) {
    _labels
      ..clear()
      ..addAll(labels);
    _notify();
    return _scheduleResourceLoad();
  }

  Future<void> setLanguages(Set<String> languages) {
    _languages
      ..clear()
      ..addAll(languages);
    _notify();
    return _scheduleResourceLoad();
  }

  Future<void> clearFilters() {
    _type = 'all';
    _category = '';
    _labels.clear();
    _languages.clear();
    _relation = ExploreRelation.nuevo;
    _notify();
    return _scheduleResourceLoad();
  }

  Future<void> clearSecondaryFilters() {
    _category = '';
    _labels.clear();
    _languages.clear();
    _relation = ExploreRelation.nuevo;
    _notify();
    return _scheduleResourceLoad();
  }

  Future<void> clearExploreFilters() {
    _category = '';
    _labels.clear();
    _languages.clear();
    _officialPacksMode = true;
    _relation = ExploreRelation.nuevo;
    _notify();
    return _scheduleResourceLoad();
  }

  // ── Carga y acciones ──────────────────────────────────────────────────

  String? get _token => _sessionController.gaToken;

  Future<ActionResult?> linkOfficialPack(
    ExploreOfficialPack pack, {
    List<String>? componentKeys,
  }) async {
    final token = _token;
    if (token == null ||
        token.isEmpty ||
        _busyPackIds.contains(pack.sourceId)) {
      return null;
    }
    _busyPackIds.add(pack.sourceId);
    _notify();
    try {
      final result = await _repository.linkOfficialPack(
        token,
        pack.sourceId,
        commitSha: pack.commitSha,
        componentKeys: componentKeys,
      );
      await load();
      return ActionResult(
        _tx('explore.pack_link_ok')
            .replaceAll('{{count}}', '${result.createdCount}'),
      );
    } on ApiError catch (error) {
      return ActionResult.error(error.message);
    } catch (_) {
      return ActionResult.error(_tx('explore.pack_link_error'));
    } finally {
      _busyPackIds.remove(pack.sourceId);
      _notify();
    }
  }

  /// Pide la vista previa y se la pasa a [present], que es quien abre el
  /// diálogo. El recurso sigue marcado como ocupado hasta que [present]
  /// termina, igual que cuando el diálogo se abría desde la página.
  Future<ActionResult?> preview(
    ExploreItem item, {
    required Future<void> Function(Map<String, dynamic> payload) present,
  }) async {
    final token = _token;
    if (token == null || token.isEmpty) return null;
    final key = itemKey(item);
    _busyKeys.add(key);
    _notify();
    try {
      final payload = await _repository.getPreview(
        token,
        resourceType: item.resourceType,
        resourceId: item.resourceId,
      );
      await present(payload);
      return null;
    } on ApiError catch (error) {
      return ActionResult.error(error.message);
    } catch (_) {
      return ActionResult.error(_tx('explore.preview_error'));
    } finally {
      _busyKeys.remove(key);
      _notify();
    }
  }

  Future<ActionResult?> showResourceGraph(
    ExploreItem item, {
    required Future<void> Function(GraphBuild graph) present,
  }) async {
    final token = _token;
    if (token == null || token.isEmpty) return null;
    final key = itemKey(item);
    _busyKeys.add(key);
    _notify();
    try {
      final graph = await _repository.getResourceGraph(
        token,
        resourceType: item.resourceType,
        resourceId: item.resourceId,
      );
      await present(graph);
      return null;
    } on ApiError catch (error) {
      return ActionResult.error(error.message);
    } catch (_) {
      return ActionResult.error(_tx('explore.graph_error'));
    } finally {
      _busyKeys.remove(key);
      _notify();
    }
  }

  Future<ActionResult?> showOfficialPackGraph(
    ExploreOfficialPack pack, {
    required Future<void> Function(GraphBuild graph) present,
  }) async {
    final token = _token;
    if (token == null || token.isEmpty) return null;
    if (_busyPackIds.contains(pack.sourceId)) return null;
    _busyPackIds.add(pack.sourceId);
    _notify();
    try {
      final graph = await _repository.getOfficialPackGraph(
        token,
        pack.sourceId,
      );
      await present(graph);
      return null;
    } on ApiError catch (error) {
      return ActionResult.error(error.message);
    } catch (_) {
      return ActionResult.error(_tx('explore.graph_error'));
    } finally {
      _busyPackIds.remove(pack.sourceId);
      _notify();
    }
  }

  Future<ActionResult?> link(ExploreItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return null;
    final key = itemKey(item);
    if (_linkedKeys.contains(key)) return null;
    _busyKeys.add(key);
    _notify();
    try {
      final result = await _repository.linkResource(
        token,
        resourceType: item.resourceType,
        resourceId: item.resourceId,
      );
      _linkedKeys.add(key);
      return ActionResult(
        _tx('explore.link_ok')
            .replaceAll('{{name}}', '${result['name'] ?? item.name}'),
      );
    } on ApiError catch (error) {
      return ActionResult.error(error.message);
    } catch (_) {
      return ActionResult.error(_tx('explore.link_error'));
    } finally {
      _busyKeys.remove(key);
      _notify();
    }
  }

  Future<ActionResult?> toggleStar(ExploreItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return null;
    final key = itemKey(item);
    final remove = isStarred(item);
    _busyKeys.add(key);
    _notify();
    try {
      final stars = remove
          ? await _repository.unstar(
              token,
              resourceType: item.resourceType,
              resourceId: item.resourceId,
            )
          : await _repository.star(
              token,
              resourceType: item.resourceType,
              resourceId: item.resourceId,
            );

      final index = _items.indexWhere(
        (element) =>
            element.resourceType == item.resourceType &&
            element.resourceId == item.resourceId,
      );
      if (index >= 0) _items[index].raw['stars_count'] = stars;
      _starOverride[key] = !remove;
      return ActionResult(
        remove ? _tx('explore.star_removed') : _tx('explore.star_added'),
      );
    } on ApiError catch (error) {
      return ActionResult.error(error.message);
    } catch (_) {
      return ActionResult.error(_tx('explore.star_error'));
    } finally {
      _busyKeys.remove(key);
      _notify();
    }
  }

  /// Relanza la búsqueda de usuarios con debounce: el campo filtra en vivo.
  void onUserSearchChanged() {
    _userSearchDebouncer.run(loadUsers);
  }

  Future<void> loadUsers() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      _usersError = _tx('common.no_session');
      _usersLoading = false;
      _notify();
      return;
    }

    _usersLoading = true;
    _usersError = null;
    _notify();

    try {
      final users = await _repository.searchUsers(
        token,
        query: userQueryController.text,
        limit: usersPageSize,
      );
      _users = users.items;
      _seenUserCursors.clear();
      _nextUsersCursor = users.nextCursor;
      if (_nextUsersCursor != null) _seenUserCursors.add(_nextUsersCursor!);
      _usersHasMore = users.hasMore;
      _usersLoading = false;
    } on ApiError catch (error) {
      _usersError = error.message;
      _usersLoading = false;
    } catch (_) {
      _usersError = _tx('explore.users_error_title');
      _usersLoading = false;
    }
    _notify();
  }

  Future<ActionResult?> loadMoreUsers() async {
    final token = _token;
    if (token == null || token.isEmpty || _usersLoadingMore || !_usersHasMore) {
      return null;
    }
    _usersLoadingMore = true;
    _notify();
    try {
      final next = await _repository.searchUsers(
        token,
        query: userQueryController.text,
        limit: usersPageSize,
        cursor: _nextUsersCursor,
      );
      final nextCursor = next.nextCursor;
      if (nextCursor != null && !_seenUserCursors.add(nextCursor)) {
        throw const CursorPaginationException.repeatedCursor();
      }
      final known = _users.map((user) => user.username).toSet();
      _users = [
        ..._users,
        ...next.items.where((user) => known.add(user.username)),
      ];
      _nextUsersCursor = nextCursor;
      _usersHasMore = next.hasMore;
      return null;
    } on ApiError catch (error) {
      return ActionResult.error(error.message);
    } catch (_) {
      return null;
    } finally {
      _usersLoadingMore = false;
      _notify();
    }
  }

  Future<ActionResult?> inviteUser(String username) async {
    final token = _token;
    if (token == null || token.isEmpty) return null;

    _invitingUsernames.add(username);
    _notify();
    try {
      final groups = await _managerRepository.listGroups(token);
      GroupItem? active;
      for (final group in groups) {
        if (group.active) {
          active = group;
          break;
        }
      }
      if (active == null || active.isPersonal) {
        return ActionResult.error(_tx('explore.users_invite_no_group'));
      }
      await _managerRepository.inviteMember(token, active.id, username);
      return ActionResult('${_tx('explore.users_invite_sent')} $username');
    } on ApiError catch (error) {
      return ActionResult.error(error.message);
    } catch (_) {
      return ActionResult.error(_tx('explore.users_invite_error'));
    } finally {
      _invitingUsernames.remove(username);
      _notify();
    }
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _resourceLoadGeneration++;
    _resourceFilterTimer?.cancel();
    final pendingFilter = _resourceFilterCompleter;
    if (pendingFilter != null && !pendingFilter.isCompleted) {
      pendingFilter.complete();
    }
    queryController.dispose();
    userQueryController.dispose();
    _userSearchDebouncer.dispose();
    super.dispose();
  }
}
