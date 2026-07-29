import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../models/manager/workspace_models.dart';
import '../repositories/manager_repository.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/widgets/action_icon_button.dart';

class ManagerPage extends StatefulWidget {
  const ManagerPage({
    required this.apiClient,
    required this.sessionController,
    super.key,
  });

  final ApiClient apiClient;
  final SessionController sessionController;

  @override
  State<ManagerPage> createState() => _ManagerPageState();
}

class _ManagerPageState extends State<ManagerPage> {
  late final ManagerRepository _repository;
  List<WorkspaceItem> _workspaces = const [];
  List<Map<String, dynamic>> _members = const [];
  List<Map<String, dynamic>> _invitations = const [];
  WorkspaceItem? _activeWorkspace;
  bool _loading = true;
  String? _error;
  String? _switchingWorkspaceId;

  @override
  void initState() {
    super.initState();
    _repository = ManagerRepository(apiClient: widget.apiClient);
    _load();
  }

  String? get _token => widget.sessionController.gaToken;

  Future<void> _load() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'No hay sesión activa';
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final workspaces = await _repository.listWorkspaces(token);
      WorkspaceItem? active;
      for (final item in workspaces) {
        if (item.active) {
          active = item;
          break;
        }
      }
      List<Map<String, dynamic>> members = const [];
      List<Map<String, dynamic>> invitations = const [];
      if (active != null && !active.isPersonal) {
        try {
          final results = await Future.wait([
            _repository.listMembers(token, active.id),
            _repository.listInvitations(token, active.id),
          ]);
          members = results[0];
          invitations = results[1];
        } catch (_) {
          // Si no hay permiso o falla detalle, mantenemos panel principal operativo.
        }
      }
      if (!mounted) return;
      setState(() {
        _workspaces = workspaces;
        _activeWorkspace = active;
        _members = members;
        _invitations = invitations;
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
        _error = 'No se pudo cargar Manager';
        _loading = false;
      });
    }
  }

  Future<void> _createWorkspace() async {
    final name = await _askName(title: 'Crear workspace', initial: '');
    if (name == null) return;

    final token = _token;
    if (token == null || token.isEmpty) return;

    try {
      await _repository.createWorkspace(token, name);
      _showMessage('Workspace creado');
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo crear el workspace', isError: true);
    }
  }

  Future<void> _renameWorkspace(WorkspaceItem item) async {
    if (item.isPersonal) {
      _showMessage('El workspace personal no se renombra desde aquí');
      return;
    }

    final name = await _askName(
      title: 'Renombrar workspace',
      initial: item.name,
    );
    if (name == null) return;

    final token = _token;
    if (token == null || token.isEmpty) return;

    try {
      await _repository.renameWorkspace(token, item.id, name);
      _showMessage('Workspace actualizado');
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo renombrar el workspace', isError: true);
    }
  }

  Future<void> _deleteWorkspace(WorkspaceItem item) async {
    if (item.isPersonal) {
      _showMessage('El workspace personal no se puede eliminar');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar workspace'),
        content: Text('¿Seguro que quieres eliminar "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final token = _token;
    if (token == null || token.isEmpty) return;

    try {
      await _repository.deleteWorkspace(token, item.id);
      _showMessage('Workspace eliminado');
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo eliminar el workspace', isError: true);
    }
  }

  Future<void> _switchWorkspace(WorkspaceItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    if (item.active) return;

    setState(() => _switchingWorkspaceId = item.id);
    try {
      final nextToken = await _repository.switchWorkspace(token, item.id);
      final user = widget.sessionController.user;
      if (nextToken != null && user != null) {
        await widget.sessionController.login(token: nextToken, user: user);
      }
      _showMessage('Workspace activo cambiado a ${item.name}');
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo cambiar el workspace activo', isError: true);
    } finally {
      if (mounted) setState(() => _switchingWorkspaceId = null);
    }
  }

  Future<void> _inviteMember() async {
    final active = _activeWorkspace;
    if (active == null || active.isPersonal) {
      _showMessage(
        'Activa un workspace de equipo para invitar miembros',
        isError: true,
      );
      return;
    }
    final username = await _askName(title: 'Invitar miembro', initial: '');
    if (username == null) return;

    final token = _token;
    if (token == null || token.isEmpty) return;
    try {
      await _repository.inviteMember(
        token,
        active.id,
        username.trim().toLowerCase(),
      );
      _showMessage('Invitación enviada');
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo enviar la invitación', isError: true);
    }
  }

  Future<void> _addMemberDirect() async {
    final active = _activeWorkspace;
    if (active == null || active.isPersonal) {
      _showMessage(
        'Activa un workspace de equipo para añadir miembros',
        isError: true,
      );
      return;
    }
    final username = await _askName(
      title: 'Añadir miembro directo',
      initial: '',
    );
    if (username == null) return;

    final token = _token;
    if (token == null || token.isEmpty) return;
    try {
      await _repository.addMember(
        token,
        active.id,
        username: username.trim().toLowerCase(),
        role: 'member',
      );
      _showMessage('Miembro añadido');
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo añadir el miembro', isError: true);
    }
  }

  Future<void> _removeMember(String username) async {
    final active = _activeWorkspace;
    if (active == null || active.isPersonal) return;
    final token = _token;
    if (token == null || token.isEmpty) return;
    try {
      await _repository.removeMember(token, active.id, username);
      _showMessage('Miembro eliminado');
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo eliminar miembro', isError: true);
    }
  }

  Future<void> _cancelInvitation(String invitationId) async {
    final active = _activeWorkspace;
    if (active == null || active.isPersonal) return;
    final token = _token;
    if (token == null || token.isEmpty) return;
    try {
      await _repository.cancelInvitation(token, active.id, invitationId);
      _showMessage('Invitación cancelada');
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo cancelar invitación', isError: true);
    }
  }

  Future<String?> _askName({
    required String title,
    required String initial,
  }) async {
    final controller = TextEditingController(text: initial);
    final formKey = GlobalKey<FormState>();

    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Nombre'),
            validator: (text) {
              final v = text?.trim() ?? '';
              if (v.isEmpty) return 'Nombre obligatorio';
              if (v.length > 80) return 'Máximo 80 caracteres';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              Navigator.of(context).pop(controller.text.trim());
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    controller.dispose();
    return value;
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Error cargando Manager',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(_error!),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  IconButton.filled(
                    onPressed: _createWorkspace,
                    icon: const Icon(Icons.add),
                    tooltip: 'Nuevo workspace',
                  ),
                  IconButton.outlined(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Actualizar',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Workspaces: ${_workspaces.length}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              if (_workspaces.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No hay workspaces disponibles.'),
                  ),
                )
              else
                ..._workspaces.map(_buildWorkspaceCard),
              const SizedBox(height: 14),
              _buildMembersCard(),
              const SizedBox(height: 14),
              _buildInvitationsCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkspaceCard(WorkspaceItem item) {
    final switching = _switchingWorkspaceId == item.id;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _chip(item.type),
                _chip(item.role),
                if (item.active) _chip('activo'),
              ],
            ),
            const SizedBox(height: 8),
            Text('ID: ${item.id}'),
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: item.active || switching
                      ? null
                      : () => _switchWorkspace(item),
                  icon: const Icon(Icons.swap_horiz_outlined),
                  label: Text(switching ? 'Cambiando...' : 'Activar'),
                ),
                const Spacer(),
                ActionIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: 'Renombrar',
                  onPressed: item.isPersonal
                      ? null
                      : () => _renameWorkspace(item),
                ),
                ActionIconButton(
                  icon: Icons.delete_outline,
                  tooltip: 'Eliminar',
                  danger: true,
                  onPressed: item.isPersonal
                      ? null
                      : () => _deleteWorkspace(item),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _buildMembersCard() {
    final active = _activeWorkspace;
    final canManage = active != null && !active.isPersonal;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Miembros',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              active == null
                  ? 'No hay workspace activo detectado.'
                  : (active.isPersonal
                        ? 'Workspace activo: Personal (sin miembros de equipo).'
                        : 'Workspace activo: ${active.name}'),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                IconButton.filled(
                  onPressed: canManage ? _inviteMember : null,
                  icon: const Icon(Icons.add),
                  tooltip: 'Invitar',
                ),
                IconButton.outlined(
                  onPressed: canManage ? _addMemberDirect : null,
                  icon: const Icon(Icons.add),
                  tooltip: 'Añadir directo',
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_members.isEmpty)
              const Text('Sin miembros listados')
            else
              ..._members.map((member) {
                final username = (member['username'] ?? '').toString();
                final role = (member['role'] ?? 'member').toString();
                return ListTile(
                  dense: true,
                  title: Text(username),
                  subtitle: Text('Rol: $role'),
                  trailing: ActionIconButton(
                    icon: Icons.person_remove_outlined,
                    tooltip: 'Quitar',
                    danger: true,
                    onPressed: canManage ? () => _removeMember(username) : null,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildInvitationsCard() {
    final active = _activeWorkspace;
    final canManage = active != null && !active.isPersonal;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Invitaciones',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (!canManage)
              const Text(
                'Activa un workspace de equipo para gestionar invitaciones.',
              )
            else if (_invitations.isEmpty)
              const Text('No hay invitaciones pendientes.')
            else
              ..._invitations.map((inv) {
                final id = (inv['id'] ?? '').toString();
                final username = (inv['username'] ?? inv['to_username'] ?? '')
                    .toString();
                final createdAt = (inv['created_at'] ?? '').toString();
                return ListTile(
                  dense: true,
                  title: Text(username.isEmpty ? id : username),
                  subtitle: Text(
                    'id: $id${createdAt.isEmpty ? '' : ' · $createdAt'}',
                  ),
                  trailing: ActionIconButton(
                    icon: Icons.close,
                    tooltip: 'Cancelar',
                    danger: true,
                    onPressed: () => _cancelInvitation(id),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
