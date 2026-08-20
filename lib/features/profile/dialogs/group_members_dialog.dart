part of '../widgets/profile_groups_section.dart';

class _MembersDialog extends StatefulWidget {
  const _MembersDialog({
    required this.apiClient,
    required this.token,
    required this.group,
    required this.currentUsername,
    required this.canManage,
    required this.tx,
  });

  final ApiClient apiClient;
  final String token;
  final GroupItem group;
  final String currentUsername;
  final bool canManage;
  final String Function(String path) tx;

  @override
  State<_MembersDialog> createState() => _MembersDialogState();
}

class _MembersDialogState extends State<_MembersDialog>
    with StateMessaging, WatchesResourceChanges {
  @override
  Set<String> get watchedResources => const {'groups'};

  @override
  Future<void> onResourcesChanged(Set<String> changed) => _load();

  late final ManagerRepository _repository;
  List<Map<String, dynamic>> _members = const [];
  List<Map<String, dynamic>> _invitations = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repository = ManagerRepository(apiClient: widget.apiClient);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _repository.listMembers(widget.token, widget.group.id),
        if (widget.canManage)
          _repository.listInvitations(widget.token, widget.group.id)
        else
          Future.value(const <Map<String, dynamic>>[]),
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

  Future<void> _removeMember(String username) async {
    try {
      await _repository.removeMember(widget.token, widget.group.id, username);
      showMessage(widget.tx('groups.member_removed'));
    } catch (_) {
      showMessage(widget.tx('groups.create_error'), isError: true);
    }
  }

  Future<void> _cancelInvitation(String id) async {
    try {
      await _repository.cancelInvitation(widget.token, widget.group.id, id);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text('${widget.tx('groups.members')} · ${widget.group.name}'),
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
                    for (var i = 0; i < _members.length; i++) ...[
                      if (i > 0) const Divider(height: 20),
                      Builder(
                        builder: (context) {
                          final m = _members[i];
                          final username = (m['username'] ?? '').toString();
                          final role = (m['role'] ?? 'member').toString();
                          final canRemove =
                              widget.canManage &&
                              role != 'owner' &&
                              username != widget.currentUsername;
                          return Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                child: Text(
                                  username.isNotEmpty
                                      ? username[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: FncFonts.size12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  username,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  role,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              if (canRemove) ...[
                                const SizedBox(width: 4),
                                ActionIconButton(
                                  icon: Icons.person_remove_outlined,
                                  tooltip: widget.tx('common.delete'),
                                  danger: true,
                                  onPressed: () => _removeMember(username),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                    if (_invitations.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        widget.tx('groups.pending_invitations').toUpperCase(),
                        style: TextStyle(
                          fontSize: FncFonts.size12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
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
                                  tooltip: widget.tx('common.cancel'),
                                  onPressed: () => _cancelInvitation(
                                    (inv['id'] ?? '').toString(),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
      ),
      actions: [
        PrimaryButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.tx('common.cancel')),
        ),
      ],
    );
  }
}

/// Diálogo simple para pedir el email/usuario del invitado antes de enviar
/// la invitación (en vez del campo+botón "Crear" incrustado, que no
/// comunicaba qué acción iba a ocurrir).
