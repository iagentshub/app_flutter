import 'package:flutter/material.dart';

import '../../../models/connections/connection_models.dart';

typedef AgentBuilderText = String Function(String path, String fallback);

/// Selector de la conexión LLM que usan los constructores por IA de agentes y
/// de skills. Una sola línea, sin tarjeta: es un ajuste, no una sección.
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: loadingConnections
              ? const Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 120,
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                )
              : Row(
                  children: [
                    Text(
                      tx('agents.field_connection', 'Conexión LLM'),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: connectionId,
                            isExpanded: true,
                            isDense: true,
                            borderRadius: BorderRadius.circular(8),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colors.onSurface),
                            icon: Icon(
                              Icons.expand_more,
                              size: 18,
                              color: colors.onSurfaceVariant,
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
                    ),
                  ],
                ),
        ),
        if (!loadingConnections && connections.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              tx(
                emptyMessagePath,
                'Necesitas una conexión LLM para usar el asistente.',
              ),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.error),
            ),
          ),
        Divider(height: 1, thickness: 1, color: colors.outlineVariant),
      ],
    );
  }
}
