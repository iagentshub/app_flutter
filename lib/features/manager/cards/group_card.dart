part of '../pages/manager_page.dart';

extension _ManagerGroupCard on _ManagerPageState {
  Widget _buildGroupCard(GroupItem item) {
    final switching = _switchingGroupId == item.id;
    return Card(
      margin: EdgeInsets.zero,
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
                if (item.active) _chip(_tx('manager.active_chip', 'activo')),
              ],
            ),
            const SizedBox(height: 8),
            Text('ID: ${item.id}'),
            const SizedBox(height: 10),
            Row(
              children: [
                SecondaryButton.icon(
                  onPressed: item.active || switching
                      ? null
                      : () => _switchGroup(item),
                  icon: const Icon(Icons.swap_horiz_outlined),
                  label: Text(
                    switching
                        ? _tx('manager.switching_label', 'Cambiando...')
                        : _tx('manager.activate_btn', 'Activar'),
                  ),
                ),
                const Spacer(),
                ActionIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: _tx('manager.rename_tooltip', 'Renombrar'),
                  onPressed: item.isPersonal ? null : () => _renameGroup(item),
                ),
                ActionIconButton(
                  icon: Icons.delete_outline,
                  tooltip: _tx('common.delete', 'Eliminar'),
                  danger: true,
                  onPressed: item.isPersonal ? null : () => _deleteGroup(item),
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
}
