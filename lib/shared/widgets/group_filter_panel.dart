import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../features/manager/repositories/manager_repository.dart';
import '../../models/manager/workspace_models.dart';

/// Panel de filtro por "grupo" (workspace), equivalente a GroupPanel en
/// frontend_vanilla (`assets/components/group-panel`). Los workspaces del
/// usuario se muestran como grupos para filtrar/compartir recursos.
///
/// `vertical: true` → rail lateral de 168px (pantallas anchas).
/// `vertical: false` → fila de chips horizontal con scroll (móvil).
class GroupFilterPanel extends StatefulWidget {
  const GroupFilterPanel({
    required this.apiClient,
    required this.token,
    required this.activeGroupId,
    required this.onSelect,
    this.vertical = true,
    super.key,
  });

  final ApiClient apiClient;
  final String token;
  final String? activeGroupId;
  final ValueChanged<String?> onSelect;
  final bool vertical;

  @override
  State<GroupFilterPanel> createState() => _GroupFilterPanelState();
}

class _GroupFilterPanelState extends State<GroupFilterPanel> {
  late final ManagerRepository _repository;
  List<WorkspaceItem> _groups = const [];
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
      final groups = await _repository.listWorkspaces(widget.token);
      if (!mounted) return;
      setState(() {
        _groups = groups;
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
        title: const Text('Nuevo grupo'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre del grupo'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Crear'),
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo crear el grupo')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.vertical ? _buildVertical(context) : _buildHorizontal(context);
  }

  Widget _buildVertical(BuildContext context) {
    return Container(
      width: 168,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 6, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'GRUPOS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 16),
                  tooltip: 'Nuevo grupo',
                  onPressed: _createGroup,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              children: [
                _item(context, null, 'Todos'),
                if (!_loading && _groups.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      'No perteneces a ningún grupo.',
                      style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                ..._groups.map((g) => _item(context, g.id, g.name)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(BuildContext context, String? id, String label) {
    final selected = widget.activeGroupId == id;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? scheme.primary.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => widget.onSelect(id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? scheme.primary : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontal(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: const Text('Todos'),
              selected: widget.activeGroupId == null,
              onSelected: (_) => widget.onSelect(null),
            ),
          ),
          ..._groups.map(
            (g) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(g.name),
                selected: widget.activeGroupId == g.id,
                onSelected: (_) => widget.onSelect(g.id),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: const Text('Grupo'),
              onPressed: _createGroup,
            ),
          ),
        ],
      ),
    );
  }
}
