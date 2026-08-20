import 'package:flutter/material.dart';

import '../../../app/theme/fnc_colors.dart';
import '../../../app/theme/fnc_fonts.dart';
import '../../../models/manager/group_models.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/action_result.dart';
import '../../../shared/state/app_services_scope.dart';
import '../../../shared/widgets/async_state_panel.dart';
import '../../../shared/widgets/buttons/action_icon_button.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/confirm_action_dialog.dart';
import '../../../shared/widgets/resource_collection_view.dart';
import '../../../shared/widgets/state_messaging_mixin.dart';
import '../controllers/manager_controller.dart';
import '../repositories/manager_repository.dart';

part '../cards/group_card.dart';
part '../cards/group_invitations_card.dart';
part '../cards/group_members_card.dart';

class ManagerPage extends StatefulWidget {
  const ManagerPage({super.key});

  @override
  State<ManagerPage> createState() => _ManagerPageState();
}

class _ManagerPageState extends State<ManagerPage> with StateMessaging {
  /// Servicios globales (cliente HTTP, sesión, idioma): los aporta el
  /// AppServicesScope montado en App, no el router.
  late final _services = AppServicesScope.of(context);

  late final ManagerController _controller;
  late final TranslatedTexts _t;

  String _tx(String path) => _t.text(path);

  @override
  void initState() {
    super.initState();
    // `_t` primero: el controller recibe `_tx` y lo usa para sus mensajes.
    _t = TranslatedTexts(
      localeController: _services.localeController,
      namespace: 'resources',
    )..addListener(_onTextsChanged);
    _controller = ManagerController(
      repository: ManagerRepository(apiClient: _services.apiClient),
      sessionController: _services.sessionController,
      tx: _tx,
    )..addListener(_onControllerChanged);
    _controller.load();
  }

  void _onTextsChanged() {
    if (mounted) setState(() {});
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _t.removeListener(_onTextsChanged);
    _t.dispose();
    super.dispose();
  }

  /// Ejecuta una acción del controller y muestra su mensaje, si lo hay.
  Future<void> _runAction(Future<ActionResult?> action) async {
    final result = await action;
    if (result == null) return;
    showMessage(result.message, isError: result.isError);
  }

  /// Diálogo de un solo campo con validación, reutilizado por crear grupo,
  /// renombrar, invitar y añadir miembro directo.
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
            decoration: InputDecoration(labelText: _tx('manager.name_label')),
            validator: (text) {
              final v = text?.trim() ?? '';
              if (v.isEmpty) {
                return _tx('manager.name_required');
              }
              if (v.length > 80) {
                return _tx('manager.name_max_length');
              }
              return null;
            },
          ),
        ),
        actions: [
          TertiaryButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_tx('common.cancel')),
          ),
          PrimaryButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              Navigator.of(context).pop(controller.text.trim());
            },
            child: Text(_tx('common.save')),
          ),
        ],
      ),
    );

    controller.dispose();
    return value;
  }

  Future<void> _createGroup() => _runAction(
    _controller.createGroup(
      askName: () =>
          _askName(title: _tx('manager.create_group_title'), initial: ''),
    ),
  );

  Future<void> _renameGroup(GroupItem item) => _runAction(
    _controller.renameGroup(
      item,
      askName: (initial) =>
          _askName(title: _tx('manager.rename_title'), initial: initial),
    ),
  );

  Future<void> _deleteGroup(GroupItem item) => _runAction(
    _controller.deleteGroup(
      item,
      confirm: () => showConfirmActionDialog(
        context,
        title: _tx('manager.delete_dialog_title'),
        message: _tx(
          'manager.delete_dialog_body',
        ).replaceAll('{{name}}', item.name),
        cancelLabel: _tx('common.cancel'),
        confirmLabel: _tx('common.delete'),
      ),
    ),
  );

  Future<void> _inviteMember() => _runAction(
    _controller.inviteMember(
      askName: () => _askName(title: _tx('manager.invite_title'), initial: ''),
    ),
  );

  Future<void> _addMemberDirect() => _runAction(
    _controller.addMemberDirect(
      askName: () =>
          _askName(title: _tx('manager.add_member_title'), initial: ''),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_controller.loading) return const AsyncStatePanel.loading();
    final error = _controller.error;
    if (error != null) {
      return ListView(
        children: [
          AsyncStatePanel.error(
            title: _tx('manager.error_loading_title'),
            message: error,
            retryLabel: _tx('common.retry'),
            onRetry: _controller.load,
          ),
        ],
      );
    }

    final groups = _controller.groups;

    return ResourceCollectionView(
      onRefresh: _controller.load,
      gridPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              AppIconButton.filled(
                onPressed: _createGroup,
                icon: const Icon(Icons.add),
                tooltip: _tx('manager.new_group_tooltip'),
              ),
              AppIconButton.outlined(
                onPressed: _controller.load,
                icon: const Icon(Icons.refresh),
                tooltip: _tx('manager.refresh_tooltip'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${_tx('manager.groups_count')}: ${groups.length}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
      empty: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_tx('manager.empty_groups')),
        ),
      ),
      itemCount: groups.length,
      itemBuilder: (context, index) => _buildGroupCard(groups[index]),
      trailingSlivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
          sliver: SliverToBoxAdapter(child: _buildMembersCard()),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverToBoxAdapter(child: _buildInvitationsCard()),
        ),
      ],
    );
  }
}
