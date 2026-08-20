part of '../widgets/profile_groups_section.dart';

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
  final GroupItem group;
  final String currentUsername;
  final String Function(String path) tx;

  @override
  State<_ManageGroupDialog> createState() => _ManageGroupDialogState();
}

class _ManageGroupDialogState extends State<_ManageGroupDialog>
    with StateMessaging {
  late final ManagerRepository _repository;
  List<Map<String, dynamic>> _members = const [];
  bool _loading = true;

  bool get _isOwner => widget.group.role == 'owner';
  bool get _canManage =>
      widget.group.role == 'owner' || widget.group.role == 'admin';

  @override
  void initState() {
    super.initState();
    _repository = ManagerRepository(apiClient: widget.apiClient);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final members = await _repository.listMembers(
        widget.token,
        widget.group.id,
      );
      if (!mounted) return;
      setState(() {
        _members = members;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _openMembersDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => _MembersDialog(
        apiClient: widget.apiClient,
        token: widget.token,
        group: widget.group,
        currentUsername: widget.currentUsername,
        canManage: _canManage,
        tx: widget.tx,
      ),
    );
    await _load();
  }

  Future<void> _openInviteDialog() async {
    final username = await showDialog<String>(
      context: context,
      builder: (context) => _InviteUserDialog(tx: widget.tx),
    );
    if (username == null || username.isEmpty) return;
    try {
      await _repository.inviteMember(widget.token, widget.group.id, username);
      showMessage(widget.tx('groups.invite_sent'));
      await _load();
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(widget.tx('groups.create_error'), isError: true);
    }
  }

  Future<void> _deleteGroup() async {
    final confirm = await showConfirmActionDialog(
      context,
      title: widget.tx('groups.delete_confirm_title'),
      message: widget.tx('groups.delete_confirm_body'),
      cancelLabel: widget.tx('common.cancel'),
      confirmLabel: widget.tx('common.delete'),
      destructive: true,
    );
    if (!confirm) return;
    try {
      await _repository.deleteGroup(widget.token, widget.group.id);
      widget.apiClient.invalidateCache('/api/groups');
      showMessage(widget.tx('groups.group_deleted'));
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      showMessage(widget.tx('groups.create_error'), isError: true);
    }
  }

  Future<void> _leave() async {
    final otherMembers = _members
        .where((m) => (m['username'] ?? '') != widget.currentUsername)
        .toList();

    if (!_isOwner) {
      final confirm = await showConfirmActionDialog(
        context,
        title: widget.tx('groups.leave_confirm_title'),
        message: widget.tx('groups.leave_confirm_body'),
        cancelLabel: widget.tx('common.cancel'),
        confirmLabel: widget.tx('groups.leave'),
        destructive: true,
      );
      if (!confirm) return;
      try {
        await _repository.removeMember(
          widget.token,
          widget.group.id,
          widget.currentUsername,
        );
        widget.apiClient.invalidateCache('/api/groups');
        showMessage(widget.tx('groups.left_group'));
        if (!mounted) return;
        Navigator.of(context).pop();
      } catch (_) {
        showMessage(widget.tx('groups.create_error'), isError: true);
      }
      return;
    }

    if (otherMembers.isEmpty) {
      final confirm = await showConfirmActionDialog(
        context,
        title: widget.tx('groups.leave_owner_sole_title'),
        message: widget.tx('groups.leave_owner_sole_body'),
        cancelLabel: widget.tx('common.cancel'),
        confirmLabel: widget.tx('common.delete'),
        destructive: true,
      );
      if (!confirm) return;
      await _deleteGroup();
      return;
    }

    final newOwner = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(widget.tx('groups.leave_owner_title')),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(widget.tx('groups.leave_owner_body')),
          ),
          for (final m in otherMembers)
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.of(context).pop((m['username'] ?? '').toString()),
              child: Text((m['username'] ?? '').toString()),
            ),
        ],
      ),
    );
    if (newOwner == null || newOwner.isEmpty) return;
    try {
      await _repository.transferOwnership(
        widget.token,
        widget.group.id,
        newOwner,
      );
      await _repository.removeMember(
        widget.token,
        widget.group.id,
        widget.currentUsername,
      );
      widget.apiClient.invalidateCache('/api/groups');
      showMessage(widget.tx('groups.ownership_transferred'));
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      showMessage(widget.tx('groups.create_error'), isError: true);
    }
  }

  Widget _sectionLabel(
    BuildContext context,
    IconData icon,
    String text, {
    Color? color,
  }) {
    final resolvedColor =
        color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 16, color: resolvedColor),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: FncFonts.size12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            color: resolvedColor,
          ),
        ),
      ],
    );
  }

  Widget _panel({
    required Widget child,
    Color? borderColor,
    Color? background,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(
          color: borderColor ?? Theme.of(context).dividerColor,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.group.name),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      content: SizedBox(
        width: dialogContentWidth(context, 480),
        child: _loading
            ? const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Puede haber muchos miembros: se listan en un diálogo aparte
                    // en vez de todos incrustados aquí.
                    SizedBox(
                      width: double.infinity,
                      child: SecondaryButton.icon(
                        onPressed: _openMembersDialog,
                        icon: const Icon(Icons.group_outlined),
                        label: Text(
                          '${widget.tx('groups.view_members')} (${_members.length})',
                        ),
                      ),
                    ),
                    if (_canManage) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: SecondaryButton.icon(
                          onPressed: _openInviteDialog,
                          icon: const Icon(Icons.person_add_alt_outlined),
                          label: Text(widget.tx('groups.invite_user')),
                        ),
                      ),
                    ],
                    if (_isOwner) ...[
                      const SizedBox(height: 24),
                      _sectionLabel(
                        context,
                        Icons.warning_amber_outlined,
                        widget.tx('groups.danger_zone').toUpperCase(),
                        color: FncColors.materialRed,
                      ),
                      const SizedBox(height: 8),
                      _panel(
                        borderColor: FncColors.materialRed.withValues(
                          alpha: 0.35,
                        ),
                        background: FncColors.materialRed.withValues(
                          alpha: 0.06,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.tx('groups.delete_confirm_body'),
                                style: const TextStyle(
                                  fontSize: FncFonts.size12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SecondaryButton.icon(
                              onPressed: _deleteGroup,
                              icon: const Icon(
                                Icons.delete_outline,
                                color: FncColors.materialRed,
                                size: 18,
                              ),
                              label: Text(
                                widget.tx('groups.delete_group'),
                                style: const TextStyle(
                                  color: FncColors.materialRed,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: FncColors.materialRed,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Abandonar va al final, en su propio panel neutro — no en
                    // la barra de acciones, para que no quede al lado de
                    // Cerrar donde es fácil pulsarlo sin querer.
                    const SizedBox(height: 24),
                    _sectionLabel(
                      context,
                      Icons.logout,
                      widget.tx('groups.leave_panel_title').toUpperCase(),
                    ),
                    const SizedBox(height: 8),
                    _panel(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.tx('groups.leave_panel_body'),
                              style: const TextStyle(fontSize: FncFonts.size12),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SecondaryButton(
                            onPressed: _leave,
                            child: Text(widget.tx('groups.leave')),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      actions: [
        PrimaryButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.tx('common.cancel')),
        ),
      ],
    );
  }
}

/// Lista de miembros de un grupo (aparte del diálogo principal porque un
/// grupo puede tener muchos) con acción de quitar, más las invitaciones
/// pendientes del grupo con acción de cancelar.
