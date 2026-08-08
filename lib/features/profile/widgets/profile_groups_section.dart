import 'package:flutter/material.dart';

import '../../../app/theme/fnc_colors.dart';
import '../../../app/theme/fnc_fonts.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../models/manager/group_models.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/widgets/buttons/action_icon_button.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/confirm_action_dialog.dart';
import '../../../shared/widgets/responsive_dialog.dart';
import '../../../shared/widgets/state_messaging_mixin.dart';
import '../../manager/repositories/manager_repository.dart';

part '../dialogs/group_members_dialog.dart';
part '../dialogs/invite_user_dialog.dart';
part '../dialogs/manage_group_dialog.dart';

/// Sección "Grupos" de Profile: mis grupos (con gestión inline: miembros,
/// invitar, abandonar, eliminar) e invitaciones recibidas pendientes.
/// Sección de grupos del perfil.
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

class _ProfileGroupsSectionState extends State<ProfileGroupsSection>
    with StateMessaging {
  late final ManagerRepository _repository;
  late final TranslatedTexts _t;

  String _tab = 'mine';
  List<GroupItem> _groups = const [];
  List<Map<String, dynamic>> _invitations = const [];
  bool _loading = true;

  String _tx(String path, String fallback) => _t.text(path, fallback: fallback);

  @override
  void initState() {
    super.initState();
    _repository = ManagerRepository(apiClient: widget.apiClient);
    _t = TranslatedTexts(
      localeController: widget.localeController,
      namespace: 'resources',
    )..addListener(_onTextsChanged);
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
        _repository.listGroups(widget.token),
        _repository.listMyInvitations(widget.token),
      ]);
      if (!mounted) return;
      setState(() {
        _groups = (results[0] as List<GroupItem>)
            .where((w) => !w.isPersonal)
            .toList();
        _invitations = results[1] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
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
          decoration: InputDecoration(
            labelText: _tx('groups.dialog_name_label', 'Nombre del grupo'),
          ),
        ),
        actions: [
          TertiaryButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_tx('common.cancel', 'Cancelar')),
          ),
          PrimaryButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(_tx('common.create', 'Crear')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    try {
      await _repository.createGroup(widget.token, name);
      widget.apiClient.invalidateCache('/api/groups');
      await _load();
    } catch (_) {
      showMessage(
        _tx('groups.create_error', 'No se pudo crear el grupo'),
        isError: true,
      );
    }
  }

  Future<void> _acceptInvitation(Map<String, dynamic> inv) async {
    try {
      await _repository.acceptInvitation(
        widget.token,
        (inv['id'] ?? '').toString(),
      );
      widget.apiClient.invalidateCache('/api/groups');
      showMessage(_tx('groups.invitation_accepted', 'Invitación aceptada'));
      await _load();
    } catch (_) {
      showMessage(
        _tx('groups.create_error', 'No se pudo crear el grupo'),
        isError: true,
      );
    }
  }

  Future<void> _rejectInvitation(Map<String, dynamic> inv) async {
    try {
      await _repository.rejectInvitation(
        widget.token,
        (inv['id'] ?? '').toString(),
      );
      showMessage(_tx('groups.invitation_rejected', 'Invitación rechazada'));
      await _load();
    } catch (_) {
      showMessage(
        _tx('groups.create_error', 'No se pudo crear el grupo'),
        isError: true,
      );
    }
  }

  Future<void> _openManageDialog(GroupItem group) async {
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ChoiceChip(
              label: Text(_tx('groups.mine', 'Mis grupos')),
              selected: _tab == 'mine',
              onSelected: (_) => setState(() => _tab = 'mine'),
            ),
            ChoiceChip(
              label: Text(
                '${_tx('groups.invitations', 'Invitaciones')}${_invitations.isEmpty ? '' : ' (${_invitations.length})'}',
              ),
              selected: _tab == 'invitations',
              onSelected: (_) => setState(() => _tab = 'invitations'),
            ),
            if (_tab == 'mine')
              PrimaryButton.icon(
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
      return [
        Text(_tx('groups.empty_mine', 'No perteneces a ningún grupo todavía.')),
      ];
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
                    Text(
                      group.name,
                      style: const TextStyle(
                        fontSize: FncFonts.size15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      roleLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              SecondaryButton(
                onPressed: () => _openManageDialog(group),
                child: Text(
                  canManage
                      ? _tx('groups.manage', 'Gestionar')
                      : _tx('groups.view', 'Ver'),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildInvitations() {
    if (_invitations.isEmpty) {
      return [
        Text(
          _tx('groups.empty_invitations', 'No tienes invitaciones pendientes.'),
        ),
      ];
    }
    return _invitations.map((inv) {
      final name = (inv['group_name'] ?? inv['group_id'] ?? '').toString();
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
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: FncFonts.size15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
