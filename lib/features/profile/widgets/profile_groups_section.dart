import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../models/manager/workspace_models.dart';
import '../../manager/repositories/manager_repository.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/widgets/action_icon_button.dart';

/// Sección "Grupos" de Profile: mis grupos (con gestión inline: miembros,
/// invitar, abandonar, eliminar) e invitaciones recibidas pendientes.
/// Equivalente a profile-workspaces.js en frontend_vanilla.
class ProfileGroupsSection extends StatefulWidget {
  const ProfileGroupsSection({
    required this.apiClient,
    required this.token,
    required this.currentUsername,
    required this.localeController,
    super.key,
  });

  final ApiClient apiClient;
  final String token;
  final String currentUsername;
  final LocaleController localeController;

  @override
  State<ProfileGroupsSection> createState() => _ProfileGroupsSectionState();
}

class _ProfileGroupsSectionState extends State<ProfileGroupsSection> {
  late final ManagerRepository _repository;
  late final TranslatedTexts _t;

  String _tab = 'mine';
  List<WorkspaceItem> _groups = const [];
  List<Map<String, dynamic>> _invitations = const [];
  bool _loading = true;

  String _tx(String path, String fallback) => _t.text(path, fallback: fallback);

  @override
  void initState() {
    super.initState();
    _repository = ManagerRepository(apiClient: widget.apiClient);
    _t = TranslatedTexts(localeController: widget.localeController, namespace: 'resources')
      ..addListener(_onTextsChanged);
    _load();
  }

  void _onTextsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _t.removeListener(_onTextsChanged);
    _t.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _repository.listWorkspaces(widget.token),
        _repository.listMyInvitations(widget.token),
      ]);
      if (!mounted) return;
      setState(() {
        _groups = (results[0] as List<WorkspaceItem>).where((w) => !w.isPersonal).toList();
        _invitations = results[1] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _showMessage(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: isError ? Colors.red.shade700 : null),
    );
  }

  Future<void> _createGroup() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_tx('groups.dialog_title', 'Nuevo grupo')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: _tx('groups.dialog_name_label', 'Nombre del grupo')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(_tx('common.cancel', 'Cancelar'))),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(_tx('common.create', 'Crear')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    try {
      await _repository.createWorkspace(widget.token, name);
      widget.apiClient.invalidateCache('/api/workspaces');
      await _load();
    } catch (_) {
      _showMessage(_tx('groups.create_error', 'No se pudo crear el grupo'), isError: true);
    }
  }

  Future<void> _acceptInvitation(Map<String, dynamic> inv) async {
    try {
      await _repository.acceptInvitation(widget.token, (inv['id'] ?? '').toString());
      widget.apiClient.invalidateCache('/api/workspaces');
      _showMessage(_tx('groups.invitation_accepted', 'Invitación aceptada'));
      await _load();
    } catch (_) {
      _showMessage(_tx('groups.create_error', 'No se pudo crear el grupo'), isError: true);
    }
  }

  Future<void> _rejectInvitation(Map<String, dynamic> inv) async {
    try {
      await _repository.rejectInvitation(widget.token, (inv['id'] ?? '').toString());
      _showMessage(_tx('groups.invitation_rejected', 'Invitación rechazada'));
      await _load();
    } catch (_) {
      _showMessage(_tx('groups.create_error', 'No se pudo crear el grupo'), isError: true);
    }
  }

  Future<void> _openManageDialog(WorkspaceItem group) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _ManageGroupDialog(
        apiClient: widget.apiClient,
        token: widget.token,
        group: group,
        currentUsername: widget.currentUsername,
        tx: _tx,
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ChoiceChip(
              label: Text(_tx('groups.mine', 'Mis grupos')),
              selected: _tab == 'mine',
              onSelected: (_) => setState(() => _tab = 'mine'),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text('${_tx('groups.invitations', 'Invitaciones')}${_invitations.isEmpty ? '' : ' (${_invitations.length})'}'),
              selected: _tab == 'invitations',
              onSelected: (_) => setState(() => _tab = 'invitations'),
            ),
            const Spacer(),
            if (_tab == 'mine')
              FilledButton.icon(
                onPressed: _createGroup,
                icon: const Icon(Icons.add),
                label: Text(_tx('groups.new_group', 'Nuevo grupo')),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_tab == 'mine') ..._buildMine() else ..._buildInvitations(),
      ],
    );
  }

  List<Widget> _buildMine() {
    if (_groups.isEmpty) {
      return [Text(_tx('groups.empty_mine', 'No perteneces a ningún grupo todavía.'))];
    }
    return _groups.map((group) {
      final canManage = group.role == 'owner' || group.role == 'admin';
      final roleLabel = switch (group.role) {
        'owner' => _tx('groups.role_owner', 'Propietario'),
        'admin' => _tx('groups.role_admin', 'Admin'),
        _ => _tx('groups.role_member', 'Miembro'),
      };
      return Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(roleLabel, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () => _openManageDialog(group),
                child: Text(canManage ? _tx('groups.manage', 'Gestionar') : _tx('groups.view', 'Ver')),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildInvitations() {
    if (_invitations.isEmpty) {
      return [Text(_tx('groups.empty_invitations', 'No tienes invitaciones pendientes.'))];
    }
    return _invitations.map((inv) {
      final name = (inv['workspace_name'] ?? inv['workspace_id'] ?? '').toString();
      final invitedBy = (inv['invited_by'] ?? '').toString();
      return Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      '${_tx('groups.invited_by', 'Invitado por')}: $invitedBy',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              ActionIconButton(
                icon: Icons.check,
                tooltip: _tx('groups.accept', 'Aceptar'),
                onPressed: () => _acceptInvitation(inv),
              ),
              ActionIconButton(
                icon: Icons.close,
                tooltip: _tx('groups.reject', 'Rechazar'),
                danger: true,
                onPressed: () => _rejectInvitation(inv),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}

/// Diálogo de gestión de un grupo: miembros, invitar, invitaciones
/// pendientes del grupo, zona de peligro (eliminar) y abandonar.
class _ManageGroupDialog extends StatefulWidget {
  const _ManageGroupDialog({
    required this.apiClient,
    required this.token,
    required this.group,
    required this.currentUsername,
    required this.tx,
  });

  final ApiClient apiClient;
  final String token;
  final WorkspaceItem group;
  final String currentUsername;
  final String Function(String path, String fallback) tx;

  @override
  State<_ManageGroupDialog> createState() => _ManageGroupDialogState();
}

class _ManageGroupDialogState extends State<_ManageGroupDialog> {
  late final ManagerRepository _repository;
  List<Map<String, dynamic>> _members = const [];
  List<Map<String, dynamic>> _invitations = const [];
  bool _loading = true;
  final _inviteController = TextEditingController();

  bool get _isOwner => widget.group.role == 'owner';
  bool get _canManage => widget.group.role == 'owner' || widget.group.role == 'admin';

  @override
  void initState() {
    super.initState();
    _repository = ManagerRepository(apiClient: widget.apiClient);
    _load();
  }

  @override
  void dispose() {
    _inviteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _repository.listMembers(widget.token, widget.group.id),
        if (_canManage) _repository.listInvitations(widget.token, widget.group.id) else Future.value(const <Map<String, dynamic>>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _members = results[0];
        _invitations = results[1];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _showMessage(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: isError ? Colors.red.shade700 : null),
    );
  }

  Future<void> _invite() async {
    final username = _inviteController.text.trim();
    if (username.isEmpty) return;
    try {
      await _repository.inviteMember(widget.token, widget.group.id, username);
      _inviteController.clear();
      _showMessage(widget.tx('groups.invite_sent', 'Invitación enviada'));
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage(widget.tx('groups.create_error', 'No se pudo crear el grupo'), isError: true);
    }
  }

  Future<void> _removeMember(String username) async {
    try {
      await _repository.removeMember(widget.token, widget.group.id, username);
      _showMessage(widget.tx('groups.member_removed', 'Miembro eliminado'));
      await _load();
    } catch (_) {
      _showMessage(widget.tx('groups.create_error', 'No se pudo crear el grupo'), isError: true);
    }
  }

  Future<void> _cancelInvitation(String id) async {
    try {
      await _repository.cancelInvitation(widget.token, widget.group.id, id);
      await _load();
    } catch (_) {}
  }

  Future<void> _deleteGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.tx('groups.delete_confirm_title', 'Eliminar grupo')),
        content: Text(widget.tx('groups.delete_confirm_body', '¿Seguro que quieres eliminar este grupo? Esta acción no se puede deshacer.')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(widget.tx('common.cancel', 'Cancelar'))),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(widget.tx('common.delete', 'Eliminar'))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _repository.deleteWorkspace(widget.token, widget.group.id);
      widget.apiClient.invalidateCache('/api/workspaces');
      _showMessage(widget.tx('groups.group_deleted', 'Grupo eliminado'));
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      _showMessage(widget.tx('groups.create_error', 'No se pudo crear el grupo'), isError: true);
    }
  }

  Future<void> _leave() async {
    final otherMembers = _members.where((m) => (m['username'] ?? '') != widget.currentUsername).toList();

    if (!_isOwner) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(widget.tx('groups.leave_confirm_title', 'Abandonar grupo')),
          content: Text(widget.tx('groups.leave_confirm_body', '¿Seguro que quieres abandonar este grupo?')),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(widget.tx('common.cancel', 'Cancelar'))),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(widget.tx('groups.leave', 'Abandonar'))),
          ],
        ),
      );
      if (confirm != true) return;
      try {
        await _repository.removeMember(widget.token, widget.group.id, widget.currentUsername);
        widget.apiClient.invalidateCache('/api/workspaces');
        _showMessage(widget.tx('groups.left_group', 'Has salido del grupo'));
        if (!mounted) return;
        Navigator.of(context).pop();
      } catch (_) {
        _showMessage(widget.tx('groups.create_error', 'No se pudo crear el grupo'), isError: true);
      }
      return;
    }

    if (otherMembers.isEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(widget.tx('groups.leave_owner_sole_title', 'Eliminar grupo')),
          content: Text(
            widget.tx('groups.leave_owner_sole_body', 'Eres el único miembro. Al salir se eliminará el grupo por completo. ¿Continuar?'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(widget.tx('common.cancel', 'Cancelar'))),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(widget.tx('common.delete', 'Eliminar'))),
          ],
        ),
      );
      if (confirm != true) return;
      await _deleteGroup();
      return;
    }

    final newOwner = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(widget.tx('groups.leave_owner_title', 'Transferir propiedad y salir')),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(widget.tx('groups.leave_owner_body', 'Eres el propietario. Elige quién será el nuevo propietario antes de salir.')),
          ),
          for (final m in otherMembers)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop((m['username'] ?? '').toString()),
              child: Text((m['username'] ?? '').toString()),
            ),
        ],
      ),
    );
    if (newOwner == null || newOwner.isEmpty) return;
    try {
      await _repository.transferOwnership(widget.token, widget.group.id, newOwner);
      await _repository.removeMember(widget.token, widget.group.id, widget.currentUsername);
      widget.apiClient.invalidateCache('/api/workspaces');
      _showMessage(widget.tx('groups.ownership_transferred', 'Propiedad transferida'));
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      _showMessage(widget.tx('groups.create_error', 'No se pudo crear el grupo'), isError: true);
    }
  }

  Widget _sectionLabel(BuildContext context, IconData icon, String text, {Color? color}) {
    final resolvedColor = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 16, color: resolvedColor),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: resolvedColor),
        ),
      ],
    );
  }

  Widget _panel({required Widget child, Color? borderColor, Color? background}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: borderColor ?? Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(widget.group.name),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      content: SizedBox(
        width: 520,
        child: _loading
            ? const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()))
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel(context, Icons.group_outlined, widget.tx('groups.members', 'Miembros').toUpperCase()),
                    const SizedBox(height: 8),
                    _panel(
                      child: Column(
                        children: [
                          for (var i = 0; i < _members.length; i++) ...[
                            if (i > 0) const Divider(height: 20),
                            Builder(
                              builder: (context) {
                                final m = _members[i];
                                final username = (m['username'] ?? '').toString();
                                final role = (m['role'] ?? 'member').toString();
                                final canRemove = _canManage && role != 'owner' && username != widget.currentUsername;
                                return Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      child: Text(username.isNotEmpty ? username[0].toUpperCase() : '?', style: const TextStyle(fontSize: 12)),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(username, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: scheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(role, style: Theme.of(context).textTheme.bodySmall),
                                    ),
                                    if (canRemove) ...[
                                      const SizedBox(width: 4),
                                      ActionIconButton(
                                        icon: Icons.person_remove_outlined,
                                        tooltip: widget.tx('common.delete', 'Eliminar'),
                                        danger: true,
                                        onPressed: () => _removeMember(username),
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_canManage) ...[
                      const SizedBox(height: 24),
                      _sectionLabel(context, Icons.person_add_alt_outlined, widget.tx('groups.invite_username', 'Invitar por usuario').toUpperCase()),
                      const SizedBox(height: 8),
                      _panel(
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _inviteController,
                                decoration: const InputDecoration(isDense: true),
                                onSubmitted: (_) => _invite(),
                              ),
                            ),
                            const SizedBox(width: 10),
                            FilledButton(onPressed: _invite, child: Text(widget.tx('common.create', 'Crear'))),
                          ],
                        ),
                      ),
                      if (_invitations.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _sectionLabel(context, Icons.mail_outline, widget.tx('groups.pending_invitations', 'Invitaciones pendientes').toUpperCase()),
                        const SizedBox(height: 8),
                        _panel(
                          child: Column(
                            children: [
                              for (var i = 0; i < _invitations.length; i++) ...[
                                if (i > 0) const Divider(height: 20),
                                Builder(
                                  builder: (context) {
                                    final inv = _invitations[i];
                                    final username = (inv['username'] ?? '').toString();
                                    return Row(
                                      children: [
                                        Expanded(child: Text(username)),
                                        ActionIconButton(
                                          icon: Icons.close,
                                          tooltip: widget.tx('common.cancel', 'Cancelar'),
                                          onPressed: () => _cancelInvitation((inv['id'] ?? '').toString()),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                    if (_isOwner) ...[
                      const SizedBox(height: 24),
                      _sectionLabel(context, Icons.warning_amber_outlined, widget.tx('groups.danger_zone', 'Zona de peligro').toUpperCase(), color: Colors.red),
                      const SizedBox(height: 8),
                      _panel(
                        borderColor: Colors.red.withValues(alpha: 0.35),
                        background: Colors.red.withValues(alpha: 0.06),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.tx('groups.delete_confirm_body', '¿Seguro que quieres eliminar este grupo? Esta acción no se puede deshacer.'),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              onPressed: _deleteGroup,
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                              label: Text(widget.tx('groups.delete_group', 'Eliminar grupo'), style: const TextStyle(color: Colors.red)),
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton.icon(
          onPressed: _leave,
          icon: const Icon(Icons.logout, color: Colors.red),
          label: Text(widget.tx('groups.leave', 'Abandonar'), style: const TextStyle(color: Colors.red)),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.tx('common.cancel', 'Cancelar')),
        ),
      ],
    );
  }
}
