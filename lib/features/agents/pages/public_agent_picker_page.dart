import 'package:flutter/material.dart';

import '../../../models/explore/explore_models.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';

class PublicAgentPickerPage extends StatefulWidget {
  const PublicAgentPickerPage({
    required this.agents,
    required this.tx,
    super.key,
  });

  final List<ExploreItem> agents;
  final String Function(String path, String fallback) tx;

  @override
  State<PublicAgentPickerPage> createState() => _PublicAgentPickerPageState();
}

class _PublicAgentPickerPageState extends State<PublicAgentPickerPage> {
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

    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          tx('agents.create_public_picker_title', 'Elige un agente público'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: TextField(
                    key: const ValueKey('public-agent-search'),
                    controller: _queryController,
                    autofocus: false,
                    decoration: InputDecoration(
                      labelText: tx('agents.search_hint', 'Buscar agente'),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _query.isEmpty
                          ? null
                          : AppIconButton(
                              onPressed: () {
                                _queryController.clear();
                                setState(() => _query = '');
                              },
                              icon: const Icon(Icons.close),
                              tooltip: tx(
                                'agents.resources_clear_search',
                                'Limpiar búsqueda',
                              ),
                            ),
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      tx(
                        'agents.create_public_picker_hint',
                        'Selecciona una base para revisarla antes de crear tu copia.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
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
                          key: const ValueKey('public-agent-list'),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          itemCount: filtered.length,
                          separatorBuilder: (context, _) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final agent = filtered[index];
                            return Card(
                              margin: EdgeInsets.zero,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: const CircleAvatar(
                                  child: Icon(Icons.smart_toy_outlined),
                                ),
                                title: Text(agent.name),
                                subtitle: agent.description.isEmpty
                                    ? null
                                    : Text(
                                        agent.description,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.of(context).pop(agent),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
