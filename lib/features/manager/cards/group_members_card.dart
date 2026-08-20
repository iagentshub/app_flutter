part of '../pages/manager_page.dart';

extension _ManagerMembersCard on _ManagerPageState {
  Widget _buildMembersCard() {
    final active = _controller.activeGroup;
    final canManage = _controller.canManageMembers;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _tx('manager.members_title'),
              style: const TextStyle(
                fontSize: FncFonts.size18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              active == null
                  ? _tx('manager.no_active_group')
                  : (active.isPersonal
                        ? _tx('manager.active_personal')
                        : '${_tx('manager.active_group_prefix')}: ${active.name}'),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                AppIconButton.filled(
                  onPressed: canManage ? _inviteMember : null,
                  icon: const Icon(Icons.add),
                  tooltip: _tx('manager.invite_tooltip'),
                ),
                AppIconButton.outlined(
                  onPressed: canManage ? _addMemberDirect : null,
                  icon: const Icon(Icons.add),
                  tooltip: _tx('manager.add_direct_tooltip'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_controller.members.isEmpty)
              Text(_tx('manager.empty_members'))
            else
              ..._controller.members.map((member) {
                final username = (member['username'] ?? '').toString();
                final role = (member['role'] ?? 'member').toString();
                return ListTile(
                  dense: true,
                  title: Text(username),
                  subtitle: Text('${_tx('manager.role_label')}: $role'),
                  trailing: ActionIconButton(
                    icon: Icons.person_remove_outlined,
                    tooltip: _tx('manager.remove_tooltip'),
                    danger: true,
                    onPressed: canManage
                        ? () => _runAction(_controller.removeMember(username))
                        : null,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
