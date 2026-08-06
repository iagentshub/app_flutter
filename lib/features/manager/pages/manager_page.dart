import 'package:flutter/material.dart';

import '../../../app/theme/fnc_colors.dart';
import '../../../app/theme/fnc_fonts.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../models/manager/group_models.dart';
import '../repositories/manager_repository.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/widgets/buttons/action_icon_button.dart';
import '../../../shared/widgets/async_state_panel.dart';
import '../../../shared/widgets/confirm_action_dialog.dart';
import '../../../shared/widgets/responsive_masonry_grid.dart';

part '../cards/group_card.dart';
part '../cards/group_invitations_card.dart';
part '../cards/group_members_card.dart';

class ManagerPage extends StatefulWidget {
  const ManagerPage({
    required this.apiClient,
    required this.sessionController,
    required this.localeController,
    super.key,
  });

  final ApiClient apiClient;
  final SessionController sessionController;
  final LocaleController localeController;

  @override
  State<ManagerPage> createState() => _ManagerPageState();
}

class _ManagerPageState extends State<ManagerPage> {
  late final ManagerRepository _repository;
  late final TranslatedTexts _t;
  List<GroupItem> _groups = const [];
  List<Map<String, dynamic>> _members = const [];
  List<Map<String, dynamic>> _invitations = const [];
  GroupItem? _activeGroup;
  bool _loading = true;
  String? _error;
  String? _switchingGroupId;

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
          // Si no hay permiso o falla detalle, mantenemos panel principal operativo.
        }
      }
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _activeGroup = active;
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
        _error = _tx('manager.error_generic', 'No se pudo cargar Manager');
        _loading = false;
      });
    }
  }

  Future<void> _createGroup() async {
    final name = await _askName(
      title: _tx('manager.create_group_title', 'Crear grupo'),
      initial: '',
    );
    if (name == null) return;

    final token = _token;
    if (token == null || token.isEmpty) return;

    try {
      await _repository.createGroup(token, name);
      _showMessage(_tx('manager.create_success', 'Grupo creado'));
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage(
        _tx('manager.create_error', 'No se pudo crear el grupo'),
        isError: true,
      );
    }
  }

  Future<void> _renameGroup(GroupItem item) async {
    if (item.isPersonal) {
      _showMessage(
        _tx(
          'manager.personal_no_rename',
          'El grupo Personal no se puede renombrar',
        ),
      );
      return;
    }

    final name = await _askName(
      title: _tx('manager.rename_title', 'Renombrar grupo'),
      initial: item.name,
    );
    if (name == null) return;

    final token = _token;
    if (token == null || token.isEmpty) return;

    try {
      await _repository.renameGroup(token, item.id, name);
      _showMessage(_tx('manager.rename_success', 'Grupo actualizado'));
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage(
        _tx('manager.rename_error', 'No se pudo renombrar el grupo'),
        isError: true,
      );
    }
  }

  Future<void> _deleteGroup(GroupItem item) async {
    if (item.isPersonal) {
      _showMessage(
        _tx(
          'manager.personal_no_delete',
          'El grupo Personal no se puede eliminar',
        ),
      );
      return;
    }

    final confirm = await showConfirmActionDialog(
      context,
      title: _tx('manager.delete_dialog_title', 'Eliminar grupo'),
      message: _tx(
        'manager.delete_dialog_body',
        '¿Seguro que quieres eliminar "{{name}}"?',
      ).replaceAll('{{name}}', item.name),
      cancelLabel: _tx('common.cancel', 'Cancelar'),
      confirmLabel: _tx('common.delete', 'Eliminar'),
    );
    if (!confirm) return;

    final token = _token;
    if (token == null || token.isEmpty) return;

    try {
      await _repository.deleteGroup(token, item.id);
      _showMessage(_tx('manager.delete_success', 'Grupo eliminado'));
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage(
        _tx('manager.delete_error', 'No se pudo eliminar el grupo'),
        isError: true,
      );
    }
  }

  Future<void> _switchGroup(GroupItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    if (item.active) return;

    setState(() => _switchingGroupId = item.id);
    try {
      final nextToken = await _repository.switchGroup(token, item.id);
      final user = widget.sessionController.user;
      if (nextToken != null && user != null) {
        await widget.sessionController.login(token: nextToken, user: user);
      }
      _showMessage(
        _tx(
          'manager.switch_success',
          'Grupo activo cambiado a {{name}}',
        ).replaceAll('{{name}}', item.name),
      );
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage(
        _tx('manager.switch_error', 'No se pudo cambiar el grupo activo'),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _switchingGroupId = null);
    }
  }

  Future<void> _inviteMember() async {
    final active = _activeGroup;
    if (active == null || active.isPersonal) {
      _showMessage(
        _tx(
          'manager.invite_need_team',
          'Activa un grupo compartido para invitar miembros',
        ),
        isError: true,
      );
      return;
    }
    final username = await _askName(
      title: _tx('manager.invite_title', 'Invitar miembro'),
      initial: '',
    );
    if (username == null) return;

    final token = _token;
    if (token == null || token.isEmpty) return;
    try {
      await _repository.inviteMember(
        token,
        active.id,
        username.trim().toLowerCase(),
      );
      _showMessage(_tx('manager.invite_success', 'Invitación enviada'));
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage(
        _tx('manager.invite_error', 'No se pudo enviar la invitación'),
        isError: true,
      );
    }
  }

  Future<void> _addMemberDirect() async {
    final active = _activeGroup;
    if (active == null || active.isPersonal) {
      _showMessage(
        _tx(
          'manager.add_member_need_team',
          'Activa un grupo compartido para añadir miembros',
        ),
        isError: true,
      );
      return;
    }
    final username = await _askName(
      title: _tx('manager.add_member_title', 'Añadir miembro directo'),
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
      _showMessage(_tx('manager.add_member_success', 'Miembro añadido'));
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage(
        _tx('manager.add_member_error', 'No se pudo añadir el miembro'),
        isError: true,
      );
    }
  }

  Future<void> _removeMember(String username) async {
    final active = _activeGroup;
    if (active == null || active.isPersonal) return;
    final token = _token;
    if (token == null || token.isEmpty) return;
    try {
      await _repository.removeMember(token, active.id, username);
      _showMessage(_tx('manager.remove_member_success', 'Miembro eliminado'));
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage(
        _tx('manager.remove_member_error', 'No se pudo eliminar miembro'),
        isError: true,
      );
    }
  }

  Future<void> _cancelInvitation(String invitationId) async {
    final active = _activeGroup;
    if (active == null || active.isPersonal) return;
    final token = _token;
    if (token == null || token.isEmpty) return;
    try {
      await _repository.cancelInvitation(token, active.id, invitationId);
      _showMessage(
        _tx('manager.cancel_invitation_success', 'Invitación cancelada'),
      );
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage(
        _tx(
          'manager.cancel_invitation_error',
          'No se pudo cancelar invitación',
        ),
        isError: true,
      );
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
            decoration: InputDecoration(
              labelText: _tx('manager.name_label', 'Nombre'),
            ),
            validator: (text) {
              final v = text?.trim() ?? '';
              if (v.isEmpty) {
                return _tx('manager.name_required', 'Nombre obligatorio');
              }
              if (v.length > 80) {
                return _tx('manager.name_max_length', 'Máximo 80 caracteres');
              }
              return null;
            },
          ),
        ),
        actions: [
          TertiaryButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_tx('common.cancel', 'Cancelar')),
          ),
          PrimaryButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              Navigator.of(context).pop(controller.text.trim());
            },
            child: Text(_tx('common.save', 'Guardar')),
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
        backgroundColor: isError ? FncColors.materialRed.shade700 : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AsyncStatePanel.loading();
    if (_error != null) {
      return ListView(
        children: [
          AsyncStatePanel.error(
            title: _tx('manager.error_loading_title', 'Error cargando Manager'),
            message: _error!,
            retryLabel: _tx('common.retry', 'Reintentar'),
            onRetry: _load,
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      AppIconButton.filled(
                        onPressed: _createGroup,
                        icon: const Icon(Icons.add),
                        tooltip: _tx(
                          'manager.new_group_tooltip',
                          'Nuevo grupo',
                        ),
                      ),
                      AppIconButton.outlined(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        tooltip: _tx('manager.refresh_tooltip', 'Actualizar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${_tx('manager.groups_count', 'Grupos')}: ${_groups.length}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          if (_groups.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              sliver: SliverToBoxAdapter(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _tx('manager.empty_groups', 'No hay grupos disponibles.'),
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              sliver: ResponsiveSliverMasonryGrid(
                itemCount: _groups.length,
                itemBuilder: (context, index) =>
                    _buildGroupCard(_groups[index]),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
            sliver: SliverToBoxAdapter(child: _buildMembersCard()),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverToBoxAdapter(child: _buildInvitationsCard()),
          ),
        ],
      ),
    );
  }
}
