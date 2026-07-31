part of '../pages/agents_page.dart';

class _PublicAgentPickerDialog extends StatefulWidget {
  const _PublicAgentPickerDialog({required this.agents, required this.tx});

  final List<ExploreItem> agents;
  final String Function(String path, String fallback) tx;

  @override
  State<_PublicAgentPickerDialog> createState() =>
      _PublicAgentPickerDialogState();
}

class _PublicAgentPickerDialogState extends State<_PublicAgentPickerDialog> {
  final _queryController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.tx;
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? widget.agents
        : widget.agents
              .where((a) => a.name.toLowerCase().contains(query))
              .toList();

    return AlertDialog(
      title: Text(
        tx('agents.create_public_picker_title', 'Elige un agente público'),
      ),
      content: SizedBox(
        width: dialogContentWidth(context, 480),
        height: dialogContentHeight(context, 420),
        child: Column(
          children: [
            TextField(
              controller: _queryController,
              decoration: InputDecoration(
                labelText: tx('agents.search_hint', 'Buscar agente'),
                prefixIcon: const Icon(Icons.search, size: 20),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        tx(
                          'agents.create_public_no_match',
                          'Sin coincidencias',
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (context, _) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final agent = filtered[index];
                        return ListTile(
                          title: Text(agent.name),
                          subtitle: agent.description.isEmpty
                              ? null
                              : Text(
                                  agent.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          onTap: () => Navigator.of(context).pop(agent),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TertiaryButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tx('common.cancel', 'Cancelar')),
        ),
      ],
    );
  }
}
