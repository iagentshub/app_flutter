import 'package:flutter/material.dart';

import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/responsive_dialog.dart';

class AgentPublishDependencyOption {
  const AgentPublishDependencyOption({
    required this.key,
    required this.name,
    required this.typeLabel,
    this.alreadyPublic = false,
  });

  final String key;
  final String name;
  final String typeLabel;
  final bool alreadyPublic;
}

Future<Set<String>?> showAgentPublishDependenciesDialog({
  required BuildContext context,
  required List<AgentPublishDependencyOption> options,
  required Set<String> initialSelection,
  required String Function(String path, String fallback) tx,
}) => showDialog<Set<String>>(
  context: context,
  builder: (_) => _AgentPublishDependenciesDialog(
    options: options,
    initialSelection: initialSelection,
    tx: tx,
  ),
);

class _AgentPublishDependenciesDialog extends StatefulWidget {
  const _AgentPublishDependenciesDialog({
    required this.options,
    required this.initialSelection,
    required this.tx,
  });

  final List<AgentPublishDependencyOption> options;
  final Set<String> initialSelection;
  final String Function(String path, String fallback) tx;

  @override
  State<_AgentPublishDependenciesDialog> createState() =>
      _AgentPublishDependenciesDialogState();
}

class _AgentPublishDependenciesDialogState
    extends State<_AgentPublishDependenciesDialog> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    final available = widget.options.map((option) => option.key).toSet();
    _selected = widget.initialSelection.intersection(available);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(
        widget.tx('agents.publish_dependencies_title', 'Publicar agente'),
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      content: SizedBox(
        width: dialogContentWidth(context, 560),
        height: dialogContentHeight(context, 520),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.tx(
                'agents.publish_dependencies_help',
                'Selecciona qué dependencias quieres publicar y enlazar al agente.',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.tx(
                      'agents.connections_never_public',
                      'Las conexiones nunca se publican.',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                TertiaryButton(
                  key: const ValueKey('publish-dependencies-select-all'),
                  onPressed: () => setState(
                    () => _selected = widget.options
                        .map((option) => option.key)
                        .toSet(),
                  ),
                  child: Text(
                    widget.tx('common.select_all', 'Seleccionar todo'),
                  ),
                ),
                TertiaryButton(
                  key: const ValueKey('publish-dependencies-clear'),
                  onPressed: () => setState(_selected.clear),
                  child: Text(widget.tx('common.clear', 'Limpiar')),
                ),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: widget.options.length,
                itemBuilder: (context, index) {
                  final option = widget.options[index];
                  return CheckboxListTile(
                    key: ValueKey('publish-dependency-${option.key}'),
                    value: _selected.contains(option.key),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: Text(option.name),
                    subtitle: Text(
                      option.alreadyPublic
                          ? '${option.typeLabel} · ${widget.tx('agents.already_public', 'Ya público')}'
                          : option.typeLabel,
                    ),
                    onChanged: (value) => setState(() {
                      if (value ?? false) {
                        _selected.add(option.key);
                      } else {
                        _selected.remove(option.key);
                      }
                    }),
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
          child: Text(widget.tx('common.cancel', 'Cancelar')),
        ),
        PrimaryButton(
          key: const ValueKey('publish-dependencies-confirm'),
          onPressed: () => Navigator.of(context).pop(_selected),
          child: Text(widget.tx('agents.publish', 'Publicar')),
        ),
      ],
    );
  }
}
