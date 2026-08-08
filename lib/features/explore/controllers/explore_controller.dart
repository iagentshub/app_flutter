import 'package:flutter/widgets.dart';

import '../../../core/network/api_error.dart';
import '../../../models/explore/explore_models.dart';
import '../../../models/manager/group_models.dart';
import '../../../shared/state/action_result.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/utils/debouncer.dart';
import '../../manager/repositories/manager_repository.dart';
import '../repositories/explore_repository.dart';

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
    required ExploreRepository repository,
    required ManagerRepository managerRepository,
    required SessionController sessionController,
    required String Function(String path, String fallback) tx,
  }) : _repository = repository,
       _managerRepository = managerRepository,
       _sessionController = sessionController,
       _tx = tx;

  static const usersPageSize = 20;

  final ExploreRepository _repository;
  final ManagerRepository _managerRepository;
  final SessionController _sessionController;
  final String Function(String path, String fallback) _tx;

  final TextEditingController queryController = TextEditingController();
  final TextEditingController userQueryController = TextEditingController();
  final Debouncer _userSearchDebouncer = Debouncer();

  bool _disposed = false;

  // ── Pestaña Recursos ──────────────────────────────────────────────────

  List<ExploreItem> _items = const [];
  bool _loading = true;
  String? _error;
  String _type = 'all';
  String _category = '';
  final Set<String> _labels = <String>{};
  final Map<String, int> _typeCounts = <String, int>{};
  final Set<String> _busyKeys = <String>{};
  final Set<String> _linkedKeys = <String>{};
  final Set<String> _starredKeys = <String>{};

  // Los getters devuelven la colección viva, no una copia: `build` los
  // consulta una vez por elemento y copiar aquí sería cuadrático. Sólo el
  // controller tiene la referencia mutable.
  List<ExploreItem> get items => _items;
  bool get loading => _loading;
  String? get error => _error;
  String get type => _type;
  String get category => _category;
  int typeCount(String type) => _typeCounts[type] ?? 0;

  bool hasLabel(String label) => _labels.contains(label);
  bool isBusy(ExploreItem item) => _busyKeys.contains(itemKey(item));
  bool isLinked(ExploreItem item) => _linkedKeys.contains(itemKey(item));
  bool isStarred(ExploreItem item) => _starredKeys.contains(itemKey(item));

  String itemKey(ExploreItem item) => '${item.resourceType}:${item.resourceId}';

  /// Categorías presentes en los resultados actuales, para poblar el filtro.
  List<String> get categoryOptions {
    final set = <String>{};
    for (final item in _items) {
      if (item.category.isNotEmpty) set.add(item.category);
    }
    return set.toList()..sort();
  }

  int get secondaryActiveFilterCount =>
      (_category.isNotEmpty ? 1 : 0) + _labels.length;

  // ── Pestaña Usuarios ──────────────────────────────────────────────────

  List<ExploreUserItem> _users = const [];
  bool _usersLoading = true;
  bool _usersLoadingMore = false;
  String? _usersError;
  bool _usersHasMore = false;
  int _usersOffset = 0;
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
    return load();
  }

  Future<void> setCategory(String value) {
    _category = value;
    _notify();
    return load();
  }

  Future<void> toggleLabel(String label, {required bool selected}) {
    if (selected) {
      _labels.add(label);
    } else {
      _labels.remove(label);
    }
    _notify();
    return load();
  }

  Future<void> clearFilters() {
    _type = 'all';
    _category = '';
    _labels.clear();
    _notify();
    return load();
  }

  Future<void> clearSecondaryFilters() {
    _category = '';
    _labels.clear();
    _notify();
    return load();
  }

  // ── Carga y acciones ──────────────────────────────────────────────────

  String? get _token => _sessionController.gaToken;

  Future<void> load() async {
    final token = _token;
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
      final items = await _repository.listResources(
        token,
        type: _type,
        query: queryController.text,
        category: _category,
        labels: _labels.toList(),
      );
      _items = items;
      if (_type == 'all') {
        _typeCounts.clear();
        for (final item in items) {
          _typeCounts.update(
            item.resourceType,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        }
      }
      _loading = false;
      if (_category.isNotEmpty && !categoryOptions.contains(_category)) {
        _category = '';
      }
    } on ApiError catch (error) {
      _error = error.message;
      _loading = false;
    } catch (_) {
      _error = _tx('explore.error_title', 'No se pudo cargar Explore');
      _loading = false;
    }
    _notify();
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
      return ActionResult.error(
        _tx('explore.preview_error', 'No se pudo cargar la vista previa'),
      );
    } finally {
      _busyKeys.remove(key);
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
        _tx(
          'explore.link_ok',
          'Recurso enlazado: {{name}}',
        ).replaceAll('{{name}}', '${result['name'] ?? item.name}'),
      );
    } on ApiError catch (error) {
      return ActionResult.error(error.message);
    } catch (_) {
      return ActionResult.error(
        _tx('explore.link_error', 'No se pudo enlazar el recurso'),
      );
    } finally {
      _busyKeys.remove(key);
      _notify();
    }
  }

  Future<ActionResult?> toggleStar(ExploreItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return null;
    final key = itemKey(item);
    final remove = _starredKeys.contains(key);
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
      if (remove) {
        _starredKeys.remove(key);
      } else {
        _starredKeys.add(key);
      }
      return ActionResult(
        remove
            ? _tx('explore.star_removed', 'Quitado de favoritos')
            : _tx('explore.star_added', 'Añadido a favoritos'),
      );
    } on ApiError catch (error) {
      return ActionResult.error(error.message);
    } catch (_) {
      return ActionResult.error(
        _tx('explore.star_error', 'No se pudo actualizar el favorito'),
      );
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
      _usersError = _tx('common.no_session', 'No hay sesión activa');
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
        offset: 0,
      );
      _users = users;
      _usersOffset = users.length;
      _usersHasMore = users.length >= usersPageSize;
      _usersLoading = false;
    } on ApiError catch (error) {
      _usersError = error.message;
      _usersLoading = false;
    } catch (_) {
      _usersError = _tx('explore.users_error_title', 'No se pudo cargar');
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
        offset: _usersOffset,
      );
      _users = [..._users, ...next];
      _usersOffset += next.length;
      _usersHasMore = next.length >= usersPageSize;
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
        return ActionResult.error(
          _tx(
            'explore.users_invite_no_group',
            'Activa un grupo de equipo para invitar usuarios',
          ),
        );
      }
      await _managerRepository.inviteMember(token, active.id, username);
      return ActionResult(
        '${_tx('explore.users_invite_sent', 'Invitación enviada a')} $username',
      );
    } on ApiError catch (error) {
      return ActionResult.error(error.message);
    } catch (_) {
      return ActionResult.error(
        _tx('explore.users_invite_error', 'No se pudo enviar la invitación'),
      );
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
    queryController.dispose();
    userQueryController.dispose();
    _userSearchDebouncer.dispose();
    super.dispose();
  }
}
