import 'package:flutter/material.dart';

import '../../../models/connections/connection_models.dart';
import '../../../models/workflows/llm_orchestration_models.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/responsive_dialog.dart';

class LlmOrchestrationDialog extends StatefulWidget {
  const LlmOrchestrationDialog({
    required this.connections,
    required this.tx,
    this.initial,
    super.key,
  });

  final List<ConnectionItem> connections;
  final LlmOrchestrationItem? initial;
  final String Function(String path, String fallback) tx;

  @override
  State<LlmOrchestrationDialog> createState() => _LlmOrchestrationDialogState();
}

class _CandidateDraft {
  _CandidateDraft(this.connectionId, this.routingHint);
  String connectionId;
  String routingHint;
}

class _LlmOrchestrationDialogState extends State<LlmOrchestrationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late String _mode;
  String? _routerConnectionId;
  late List<_CandidateDraft> _candidates;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _name = TextEditingController(text: initial?.name ?? '');
    _description = TextEditingController(text: initial?.description ?? '');
    _mode = initial?.mode ?? 'stack';
    _routerConnectionId = initial?.routerConnectionId.isEmpty == false
        ? initial!.routerConnectionId
        : null;
    _candidates =
        initial?.candidates
            .map((item) => _CandidateDraft(item.connectionId, item.routingHint))
            .toList() ??
        <_CandidateDraft>[];
    while (_candidates.length < 2 &&
        _candidates.length < widget.connections.length) {
      final unused = widget.connections.firstWhere(
        (item) => !_candidates.any((draft) => draft.connectionId == item.id),
      );
      _candidates.add(_CandidateDraft(unused.id, ''));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _addCandidate() {
    ConnectionItem? unused;
    for (final item in widget.connections) {
      if (!_candidates.any((draft) => draft.connectionId == item.id)) {
        unused = item;
        break;
      }
    }
    if (unused == null) return;
    final unusedId = unused.id;
    setState(() => _candidates.add(_CandidateDraft(unusedId, '')));
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_candidates.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.tx(
              'llm_orchestrations.minimum_candidates',
              'Añade al menos dos conexiones candidatas.',
            ),
          ),
        ),
      );
      return;
    }
    if (_mode == 'balanced' && _routerConnectionId == null) return;
    Navigator.of(context).pop(<String, dynamic>{
      if (widget.initial != null) 'id': widget.initial!.id,
      'name': _name.text.trim(),
      'description': _description.text.trim(),
      'mode': _mode,
      'candidates': _candidates
          .map(
            (item) => {
              'connection_id': item.connectionId,
              'routing_hint': item.routingHint.trim(),
            },
          )
          .toList(),
      'router_connection_id': _mode == 'balanced' ? _routerConnectionId : null,
      'labels': widget.initial?.labels ?? const ['private'],
    });
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.tx;
    return AlertDialog(
      title: Text(
        widget.initial == null
            ? tx('llm_orchestrations.create', 'Nueva orquestación LLM')
            : tx('llm_orchestrations.edit', 'Editar orquestación LLM'),
      ),
      content: SizedBox(
        width: dialogContentWidth(context, 720),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: InputDecoration(
                    labelText: tx('llm_orchestrations.name', 'Nombre'),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? tx(
                          'llm_orchestrations.name_required',
                          'El nombre es obligatorio',
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: tx(
                      'llm_orchestrations.description',
                      'Descripción',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      avatar: const Icon(Icons.low_priority, size: 18),
                      label: Text(tx('llm_orchestrations.stack', 'Pila')),
                      selected: _mode == 'stack',
                      onSelected: (_) => setState(() => _mode = 'stack'),
                    ),
                    ChoiceChip(
                      avatar: const Icon(Icons.balance, size: 18),
                      label: Text(
                        tx('llm_orchestrations.balanced', 'Balanceo'),
                      ),
                      selected: _mode == 'balanced',
                      onSelected: (_) => setState(() => _mode = 'balanced'),
                    ),
                  ],
                ),
                if (_mode == 'balanced') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _routerConnectionId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: tx(
                        'llm_orchestrations.router',
                        'LLM balanceador',
                      ),
                    ),
                    items: widget.connections
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text('${item.name} (${item.model})'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _routerConnectionId = value),
                    validator: (value) => _mode == 'balanced' && value == null
                        ? tx(
                            'llm_orchestrations.router_required',
                            'Selecciona el LLM balanceador',
                          )
                        : null,
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tx(
                          'llm_orchestrations.candidates',
                          'Conexiones candidatas',
                        ),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    AppIconButton.outlined(
                      onPressed: _candidates.length < widget.connections.length
                          ? _addCandidate
                          : null,
                      icon: const Icon(Icons.add),
                      tooltip: tx(
                        'llm_orchestrations.add_candidate',
                        'Añadir conexión',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _candidates.length,
                  onReorderItem: (oldIndex, newIndex) {
                    setState(() {
                      final item = _candidates.removeAt(oldIndex);
                      _candidates.insert(newIndex, item);
                    });
                  },
                  itemBuilder: (context, index) {
                    final draft = _candidates[index];
                    return Card(
                      key: ValueKey('${draft.connectionId}-$index'),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: Icon(Icons.drag_handle),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                children: [
                                  DropdownButtonFormField<String>(
                                    initialValue: draft.connectionId,
                                    isExpanded: true,
                                    items: widget.connections
                                        .map(
                                          (item) => DropdownMenuItem(
                                            value: item.id,
                                            enabled: !_candidates.any(
                                              (other) =>
                                                  other != draft &&
                                                  other.connectionId == item.id,
                                            ),
                                            child: Text(
                                              '${item.name} (${item.model})',
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) => setState(
                                      () => draft.connectionId =
                                          value ?? draft.connectionId,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    initialValue: draft.routingHint,
                                    decoration: InputDecoration(
                                      labelText: tx(
                                        'llm_orchestrations.routing_hint',
                                        'Instrucción de enrutado',
                                      ),
                                      hintText: tx(
                                        'llm_orchestrations.routing_hint_example',
                                        'Ej.: mejor para código y tareas complejas',
                                      ),
                                    ),
                                    onChanged: (value) =>
                                        draft.routingHint = value,
                                  ),
                                ],
                              ),
                            ),
                            AppIconButton.outlined(
                              onPressed: _candidates.length > 2
                                  ? () => setState(
                                      () => _candidates.removeAt(index),
                                    )
                                  : null,
                              icon: const Icon(Icons.delete_outline),
                              tooltip: tx('common.delete', 'Eliminar'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TertiaryButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tx('common.cancel', 'Cancelar')),
        ),
        PrimaryButton(
          onPressed: _save,
          child: Text(tx('common.save', 'Guardar')),
        ),
      ],
    );
  }
}
