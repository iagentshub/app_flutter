part of '../pages/manager_page.dart';

extension _ManagerInvitationsCard on _ManagerPageState {
  Widget _buildInvitationsCard() {
    final active = _activeGroup;
    final canManage = active != null && !active.isPersonal;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _tx('manager.invitations_title', 'Invitaciones'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (!canManage)
              Text(
                _tx(
                  'manager.invitations_need_team',
                  'Activa un grupo compartido para gestionar invitaciones.',
                ),
              )
            else if (_invitations.isEmpty)
              Text(
                _tx(
                  'manager.empty_invitations',
                  'No hay invitaciones pendientes.',
                ),
              )
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
                    tooltip: _tx('common.cancel', 'Cancelar'),
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
