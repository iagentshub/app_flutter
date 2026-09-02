import 'package:flutter/material.dart';

import '../../../models/connections/connection_models.dart';
import '../../../utils/i18n.dart';

typedef AgentBuilderText = String Function(String path);

/// Modos del constructor de agentes, en el orden en que se ofrecen. Son los
/// valores que acepta `mode` en `POST /api/agent-builder/chat`.
const builderModes = ['auto', 'guided', 'expert'];

/// Selector de la conexión LLM que usan los constructores por IA de agentes y
/// de skills, y del modo de conversación cuando quien la usa es el de agentes.
/// Una línea por control, sin tarjeta: son ajustes, no una sección.
class BuilderConnectionBar extends StatelessWidget {
  const BuilderConnectionBar({
    required this.loadingConnections,
    required this.streaming,
    required this.connections,
    required this.connectionId,
    required this.onConnectionChanged,
    required this.tx,
    this.mode,
    this.onModeChanged,
    this.emptyMessagePath = 'agents.builder_connection_required',
    super.key,
  });

  final bool loadingConnections;
  final bool streaming;
  final List<ConnectionItem> connections;
  final String? connectionId;
  final ValueChanged<String?> onConnectionChanged;
  final AgentBuilderText tx;

  /// El constructor de skills trabaja siempre en modo guiado y no pasa
  /// ninguno: sin `onModeChanged` la fila del modo no se pinta.
  final String? mode;
  final ValueChanged<String>? onModeChanged;

  final String emptyMessagePath;

  String _connectionLabel(ConnectionItem connection) => connection.model.isEmpty
      ? '${connection.name} (${connection.type})'
      : '${connection.name} · ${connection.model}';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 600;
    final selectedMode = mode;
    final onMode = onModeChanged;
    final connectionEntries = {
      for (final connection in connections)
        connection.id: _connectionLabel(connection),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (compact)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: loadingConnections
                ? const LinearProgressIndicator(minHeight: 2)
                : _BarDropdown(
                    fieldKey: const ValueKey('builder-connection-mobile'),
                    compact: true,
                    label: tx('agents.field_connection'),
                    value: connectionId,
                    entries: connectionEntries,
                    onChanged: streaming ? null : onConnectionChanged,
                  ),
          )
        else
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
                : _BarDropdown(
                    compact: false,
                    label: tx('agents.field_connection'),
                    value: connectionId,
                    maxWidth: 360,
                    entries: connectionEntries,
                    onChanged: streaming ? null : onConnectionChanged,
                  ),
          ),
        if (selectedMode != null && onMode != null)
          Padding(
            padding: compact
                ? const EdgeInsets.fromLTRB(12, 0, 12, 8)
                : const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BarDropdown(
                  fieldKey: const ValueKey('builder-mode'),
                  compact: compact,
                  label: tx('agents.builder_mode'),
                  value: selectedMode,
                  maxWidth: 260,
                  entries: {
                    for (final value in builderModes)
                      value: tx('agents.builder_mode_$value'),
                  },
                  onChanged: streaming
                      ? null
                      : (value) {
                          if (value != null) onMode(value);
                        },
                ),
                const SizedBox(height: 4),
                // El nombre del modo no dice qué cambia; la pista sí, y es lo
                // que evita que se elija "Experto" por sonar mejor.
                Text(
                  tx('agents.builder_mode_${selectedMode}_hint'),
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        if (!loadingConnections && connections.isEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(compact ? 12 : 0, 0, 0, 8),
            child: Text(
              trOr(emptyMessagePath, tr('agents.builder_needs_connection')),
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.error),
            ),
          ),
        Divider(height: 1, thickness: 1, color: colors.outlineVariant),
      ],
    );
  }
}

/// Un desplegable de la barra. Existe porque conexión y modo se pintan igual y
/// cada uno tiene dos formas —campo con etiqueta en móvil, etiqueta al lado en
/// escritorio—: escritas cuatro veces, la siguiente se olvida una.
class _BarDropdown extends StatelessWidget {
  const _BarDropdown({
    required this.compact,
    required this.label,
    required this.value,
    required this.entries,
    required this.onChanged,
    this.fieldKey,
    this.maxWidth,
  });

  final bool compact;
  final String label;
  final String? value;
  final Map<String, String> entries;
  final ValueChanged<String?>? onChanged;
  final Key? fieldKey;
  final double? maxWidth;

  List<DropdownMenuItem<String>> get _items => entries.entries
      .map(
        (entry) => DropdownMenuItem<String>(
          value: entry.key,
          child: Text(entry.value, overflow: TextOverflow.ellipsis),
        ),
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (compact) {
      return DropdownButtonFormField<String>(
        key: fieldKey,
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
        items: _items,
        onChanged: onChanged,
      );
    }
    return Row(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                key: fieldKey,
                value: value,
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
                items: _items,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
