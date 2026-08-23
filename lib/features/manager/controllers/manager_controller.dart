import 'package:flutter/foundation.dart';

import '../../../core/network/api_error.dart';
import '../../../models/manager/group_models.dart';
import '../../../shared/state/action_result.dart';
import '../../../shared/state/session_controller.dart';
import '../../../utils/i18n.dart';
import '../repositories/manager_repository.dart';

/// Orquesta la pantalla de grupos: listado, grupo activo, miembros e
/// invitaciones.
///
/// Los mensajes de resultado se **devuelven** como [ActionResult] en vez de
/// mostrarse aquí: el SnackBar necesita un `BuildContext` que el controller no
/// tiene. `null` significa que no hay nada que mostrar.
///
/// Las acciones que necesitan un dato del usuario reciben un callback
/// (`askName`, `confirm`) en vez de devolver el control a la página: así el
/// orden —comprobar el grupo, preguntar, llamar al backend, recargar— vive
/// entero aquí y se testea sin `WidgetTester`.
class ManagerController extends ChangeNotifier {
  ManagerController({
    required this._repository,
    required this._sessionController,
    required this._tx,
  });

  final ManagerRepository _repository;
  final SessionController _sessionController;
  final String Function(String path) _tx;

  bool _disposed = false;

  List<GroupItem> _groups = const [];
  List<Map<String, dynamic>> _members = const [];
  List<Map<String, dynamic>> _invitations = const [];
  GroupItem? _activeGroup;
  bool _loading = true;
  String? _error;
  String? _switchingGroupId;

  // Colecciones vivas, no copias: `build` las recorre una vez por elemento y
  // copiarlas en cada lectura sería cuadrático. Sólo el controller las muta.
  List<GroupItem> get groups => _groups;
  List<Map<String, dynamic>> get members => _members;
  List<Map<String, dynamic>> get invitations => _invitations;
  GroupItem? get activeGroup => _activeGroup;
  bool get loading => _loading;
  String? get error => _error;

  bool isSwitching(GroupItem item) => _switchingGroupId == item.id;

  /// Miembros e invitaciones sólo se gestionan sobre un grupo compartido: el
  /// grupo Personal es de un único usuario por definición.
  bool get canManageMembers {
    final active = _activeGroup;
    return active != null && !active.isPersonal;
  }

  String? get _token => _sessionController.gaToken;

  Future<void> load() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      _error = _tx('common.no_session');
      _loading = false;
      _notify();
      return;
    }

    _loading = true;
    _error = null;
    _notify();

    try {
      final groups = await _repository.listGroups(token);
      GroupItem? active;
      for (final item in groups) {
        if (item.active) {
          active = item;
          break;
        }
      }
      List<Map<String, dynamic>> members = const [];
      List<Map<String, dynamic>> invitations = const [];
      if (active != null) {
        try {
          final results = await Future.wait([
            _repository.listMembers(token, active.id),
            _repository.listInvitations(token, active.id),
          ]);
          members = results[0];
          invitations = results[1];
        } catch (_) {
          // Si no hay permiso o falla el detalle, el panel principal sigue
          // operativo: los grupos ya están cargados.
        }
      }
      _groups = groups;
      _activeGroup = active;
      _members = members;
      _invitations = invitations;
      _loading = false;
    } on ApiError catch (error) {
      _error = error.message;
      _loading = false;
    } catch (_) {
      _error = _tx('manager.error_generic');
      _loading = false;
    }
    _notify();
  }

  Future<ActionResult?> createGroup({
    required Future<String?> Function() askName,
  }) async {
    final name = await askName();
    if (name == null) return null;
    final token = _token;
    if (token == null || token.isEmpty) return null;

    return _run(
      () => _repository.createGroup(token, name),
      okKey: 'manager.create_success',
      errorKey: 'manager.create_error',
    );
  }

  Future<ActionResult?> renameGroup(
    GroupItem item, {
    required Future<String?> Function(String initial) askName,
  }) async {
    if (item.isPersonal) {
      return ActionResult(_tx('manager.personal_no_rename'));
    }
    final name = await askName(item.name);
    if (name == null) return null;
    final token = _token;
    if (token == null || token.isEmpty) return null;

    return _run(
      () => _repository.renameGroup(token, item.id, name),
      okKey: 'manager.rename_success',
      errorKey: 'manager.rename_error',
    );
  }

  Future<ActionResult?> deleteGroup(
    GroupItem item, {
    required Future<bool> Function() confirm,
  }) async {
    if (item.isPersonal) {
      return ActionResult(_tx('manager.personal_no_delete'));
    }
    if (!await confirm()) return null;
    final token = _token;
    if (token == null || token.isEmpty) return null;

    return _run(
      () => _repository.deleteGroup(token, item.id),
      okKey: 'manager.delete_success',
      errorKey: 'manager.delete_error',
    );
  }

  /// Cambiar de grupo devuelve un token nuevo: el anterior sigue apuntando al
  /// grupo viejo, así que hay que renovar la sesión antes de recargar.
  Future<ActionResult?> switchGroup(GroupItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return null;
    if (item.active) return null;

    _switchingGroupId = item.id;
    _notify();
    try {
      final nextToken = await _repository.switchGroup(token, item.id);
      final user = _sessionController.user;
      if (nextToken != null && user != null) {
        await _sessionController.login(token: nextToken, user: user);
      }
      await load();
      return ActionResult(
        _tx('manager.switch_success').replaceAll('{{name}}', item.name),
      );
    } on ApiError catch (error) {
      return ActionResult.error(error.message);
    } catch (_) {
      return ActionResult.error(_tx('manager.switch_error'));
    } finally {
      _switchingGroupId = null;
      _notify();
    }
  }

  Future<ActionResult?> inviteMember({
    required Future<String?> Function() askName,
  }) async {
    if (!canManageMembers) {
      return ActionResult.error(_tx('manager.invite_need_team'));
    }
    final username = await askName();
    if (username == null) return null;
    final token = _token;
    if (token == null || token.isEmpty) return null;

    return _run(
      () => _repository.inviteMember(
        token,
        _activeGroup!.id,
        _normalizeUsername(username),
      ),
      okKey: 'manager.invite_success',
      errorKey: 'manager.invite_error',
    );
  }

  Future<ActionResult?> addMemberDirect({
    required Future<String?> Function() askName,
  }) async {
    if (!canManageMembers) {
      return ActionResult.error(_tx('manager.add_member_need_team'));
    }
    final username = await askName();
    if (username == null) return null;
    final token = _token;
    if (token == null || token.isEmpty) return null;

    return _run(
      () => _repository.addMember(
        token,
        _activeGroup!.id,
        username: _normalizeUsername(username),
        role: 'member',
      ),
      okKey: 'manager.add_member_success',
      errorKey: 'manager.add_member_error',
    );
  }

  Future<ActionResult?> removeMember(String username) async {
    if (!canManageMembers) return null;
    final token = _token;
    if (token == null || token.isEmpty) return null;

    return _run(
      () => _repository.removeMember(token, _activeGroup!.id, username),
      okKey: 'manager.remove_member_success',
      errorKey: 'manager.remove_member_error',
    );
  }

  Future<ActionResult?> cancelInvitation(String invitationId) async {
    if (!canManageMembers) return null;
    final token = _token;
    if (token == null || token.isEmpty) return null;

    return _run(
      () => _repository.cancelInvitation(token, _activeGroup!.id, invitationId),
      okKey: 'manager.cancel_invitation_success',
      errorKey: 'manager.cancel_invitation_error',
    );
  }

  /// Las mutaciones comparten forma: llamar, recargar y avisar. El mensaje del
  /// backend gana al genérico cuando viene como [ApiError].
  Future<ActionResult> _run(
    Future<void> Function() action, {
    required String okKey,
    required String errorKey,
  }) async {
    try {
      await action();
      await load();
      return ActionResult(tr(okKey));
    } on ApiError catch (error) {
      return ActionResult.error(error.message);
    } catch (_) {
      return ActionResult.error(tr(errorKey));
    }
  }

  String _normalizeUsername(String value) => value.trim().toLowerCase();

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
