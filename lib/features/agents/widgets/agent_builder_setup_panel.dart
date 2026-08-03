import 'package:flutter/material.dart';

import '../../../models/connections/connection_models.dart';

typedef AgentBuilderText = String Function(String path, String fallback);

/// Configuration and progress surface shown above the agent-builder chat.
class AgentBuilderSetupPanel extends StatelessWidget {
  const AgentBuilderSetupPanel({
    required this.wide,
    required this.loadingConnections,
    required this.streaming,
    required this.agentSaved,
    required this.hasMessages,
    required this.connections,
    required this.connectionId,
    required this.onConnectionChanged,
    required this.tx,
    super.key,
  });

  final bool wide;
  final bool loadingConnections;
  final bool streaming;
  final bool agentSaved;
  final bool hasMessages;
  final List<ConnectionItem> connections;
  final String? connectionId;
  final ValueChanged<String?> onConnectionChanged;
  final AgentBuilderText tx;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(wide ? 18 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildSetupCopy(context)),
                  const SizedBox(width: 24),
                  SizedBox(width: 390, child: _buildConnectionField(context)),
                ],
              )
            else ...[
              _buildSetupCopy(context),
              const SizedBox(height: 14),
              _buildConnectionField(context),
            ],
            const SizedBox(height: 16),
            _buildProgressSteps(),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupCopy(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colors.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.architecture_rounded,
            color: colors.onSecondaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tx('agents.builder_setup_title', 'Configura tu agente'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                tx(
                  'agents.builder_setup_subtitle',
                  'Elige el modelo que te ayudará a diseñarlo.',
                ),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionField(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (loadingConnections)
          const LinearProgressIndicator(minHeight: 2)
        else
          DropdownButtonFormField<String>(
            initialValue: connectionId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: tx('agents.field_connection', 'Conexión LLM'),
              prefixIcon: const Icon(Icons.hub_outlined, size: 20),
              isDense: true,
              filled: true,
              fillColor: colors.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
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
        if (!loadingConnections && connections.isEmpty) ...[
          const SizedBox(height: 8),
          Text(
            tx(
              'agents.builder_connection_required',
              'Necesitas una conexión LLM para usar el asistente.',
            ),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.error),
          ),
        ],
      ],
    );
  }

  Widget _buildProgressSteps() {
    final currentStep = agentSaved ? 2 : (hasMessages ? 1 : 0);
    final labels = [
      tx('agents.builder_step_describe', 'Describe lo que necesitas'),
      tx('agents.builder_step_refine', 'Responde y afina detalles'),
      tx('agents.builder_step_review', 'Revisa el borrador'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return _ProgressStep(
            index: currentStep,
            label: labels[currentStep],
            active: true,
            completed: false,
          );
        }
        return Row(
          children: [
            for (var index = 0; index < labels.length; index++) ...[
              Expanded(
                child: _ProgressStep(
                  index: index,
                  label: labels[index],
                  active: index == currentStep,
                  completed: index < currentStep,
                ),
              ),
              if (index < labels.length - 1)
                Container(
                  width: 24,
                  height: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
            ],
          ],
        );
      },
    );
  }
}

class _ProgressStep extends StatelessWidget {
  const _ProgressStep({
    required this.index,
    required this.label,
    required this.active,
    required this.completed,
  });

  final int index;
  final String label;
  final bool active;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final emphasized = active || completed;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: emphasized ? colors.primary : colors.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: completed
              ? Icon(Icons.check_rounded, size: 16, color: colors.onPrimary)
              : Text(
                  '${index + 1}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: emphasized
                        ? colors.onPrimary
                        : colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: active ? colors.onSurface : colors.onSurfaceVariant,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
