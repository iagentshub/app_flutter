import 'package:flutter/material.dart';

import '../../../models/connections/connection_models.dart';

typedef AgentBuilderText = String Function(String path, String fallback);

/// Selector de la conexión LLM que usan los constructores por IA de agentes y
/// de skills. Es lo único que hay que configurar antes de conversar.
class BuilderConnectionBar extends StatelessWidget {
  const BuilderConnectionBar({
    required this.loadingConnections,
    required this.streaming,
    required this.connections,
    required this.connectionId,
    required this.onConnectionChanged,
    required this.tx,
    this.emptyMessagePath = 'agents.builder_connection_required',
    super.key,
  });

  final bool loadingConnections;
  final bool streaming;
  final List<ConnectionItem> connections;
  final String? connectionId;
  final ValueChanged<String?> onConnectionChanged;
  final AgentBuilderText tx;
  final String emptyMessagePath;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (loadingConnections)
              const LinearProgressIndicator(minHeight: 2)
            else
              Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: DropdownButtonFormField<String>(
                    initialValue: connectionId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: tx('agents.field_connection', 'Conexión LLM'),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: connections
                        .map(
                          (connection) => DropdownMenuItem<String>(
                            value: connection.id,
                            child: Text(
                              connection.model.isEmpty
                                  ? '${connection.name} (${connection.type})'
                                  : '${connection.name} · ${connection.model}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: streaming ? null : onConnectionChanged,
                  ),
                ),
              ),
            if (!loadingConnections && connections.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                tx(
                  emptyMessagePath,
                  'Necesitas una conexión LLM para usar el asistente.',
                ),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
