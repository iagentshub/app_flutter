import 'package:flutter/material.dart';

import '../../../models/connections/connection_models.dart';
import '../../../models/workflows/llm_orchestration_models.dart';
import '../../../shared/widgets/buttons/action_icon_button.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';

class LlmOrchestrationEditorPage extends StatefulWidget {
  const LlmOrchestrationEditorPage({
    required this.connections,
    required this.tx,
    this.initial,
    this.configureBinding = false,
    super.key,
  });

  final List<ConnectionItem> connections;
  final LlmOrchestrationItem? initial;
  final bool configureBinding;
  final String Function(String path, String fallback) tx;

  @override
  State<LlmOrchestrationEditorPage> createState() =>
      _LlmOrchestrationEditorPageState();
}

class _CandidateDraft {
  _CandidateDraft(this.connectionId, this.routingHint);
  String connectionId;
  String routingHint;
}

class _LlmOrchestrationEditorPageState
    extends State<LlmOrchestrationEditorPage> {
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
    _candidates = <_CandidateDraft>[];
    for (final candidate in initial?.candidates ?? const []) {
      final existingId =
          widget.connections.any(
            (connection) => connection.id == candidate.connectionId,
          )
          ? candidate.connectionId
          : null;
      final connectionId =
          existingId ??
          widget.connections
              .firstWhere(
                (connection) => !_candidates.any(
                  (draft) => draft.connectionId == connection.id,
                ),
              )
              .id;
      _candidates.add(_CandidateDraft(connectionId, candidate.routingHint));
    }
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
      if (!widget.configureBinding && widget.initial != null)
        'id': widget.initial!.id,
      if (!widget.configureBinding) 'name': _name.text.trim(),
      if (!widget.configureBinding) 'description': _description.text.trim(),
      if (!widget.configureBinding) 'mode': _mode,
      'candidates': _candidates
          .map(
            (item) => {
              'connection_id': item.connectionId,
              'routing_hint': item.routingHint.trim(),
            },
          )
          .toList(),
      'router_connection_id': _mode == 'balanced' ? _routerConnectionId : null,
      if (!widget.configureBinding)
        'labels': widget.initial?.labels ?? const ['private'],
    });
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.tx;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          widget.configureBinding
              ? tx(
                  'llm_orchestrations.configure_connections',
                  'Configurar mis conexiones',
                )
              : widget.initial == null
              ? tx('llm_orchestrations.create', 'Nueva orquestación LLM')
              : tx('llm_orchestrations.edit', 'Editar orquestación LLM'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: PrimaryButton.icon(
              key: const ValueKey('llm-orchestration-save'),
              onPressed: _save,
              icon: const Icon(Icons.check, size: 18),
              label: Text(tx('common.save', 'Guardar')),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
                  20,
                  MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
                  32,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _name,
                      enabled: !widget.configureBinding,
                      decoration: InputDecoration(
                        labelText: tx('llm_orchestrations.name', 'Nombre'),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? tx(
                              'llm_orchestrations.name_required',
                              'El nombre es obligatorio',
                            )
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _description,
                      enabled: !widget.configureBinding,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: tx(
                          'llm_orchestrations.description',
                          'Descripción',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tx('llm_orchestrations.mode', 'Modo'),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<String>(
                        showSelectedIcon: false,
                        expandedInsets: EdgeInsets.zero,
                        segments: [
                          ButtonSegment(
                            value: 'stack',
                            label: Text(tx('llm_orchestrations.stack', 'Pila')),
                          ),
                          ButtonSegment(
                            value: 'balanced',
                            label: Text(
                              tx('llm_orchestrations.balanced', 'Balanceo'),
                            ),
                          ),
                        ],
                        selected: {_mode},
                        onSelectionChanged: widget.configureBinding
                            ? null
                            : (selection) =>
                                  setState(() => _mode = selection.first),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _mode == 'balanced'
                          ? tx(
                              'llm_orchestrations.balanced_help',
                              'La conexión orquestadora estudia cada tarea y ordena las candidatas.',
                            )
                          : tx(
                              'llm_orchestrations.stack_help',
                              'Prueba las conexiones en orden hasta obtener una respuesta.',
                            ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (_mode == 'balanced') ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _routerConnectionId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: tx(
                            'llm_orchestrations.router',
                            'Conexión orquestadora',
                          ),
                          helperText: tx(
                            'llm_orchestrations.router_help',
                            'Analiza la tarea y ordena las candidatas. Si falla, la orquestación se detiene.',
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
                        validator: (value) =>
                            _mode == 'balanced' && value == null
                            ? tx(
                                'llm_orchestrations.router_required',
                                'Selecciona la conexión orquestadora',
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
                          onPressed:
                              _candidates.length < widget.connections.length
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
                        return Container(
                          key: ValueKey('${draft.connectionId}-$index'),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final compact = constraints.maxWidth < 520;
                                final fields = Column(
                                  children: [
                                    DropdownButtonFormField<String>(
                                      initialValue: draft.connectionId,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        labelText: tx(
                                          'llm_orchestrations.candidate_connection',
                                          'Conexión',
                                        ),
                                      ),
                                      items: widget.connections
                                          .map(
                                            (item) => DropdownMenuItem(
                                              value: item.id,
                                              enabled: !_candidates.any(
                                                (other) =>
                                                    other != draft &&
                                                    other.connectionId ==
                                                        item.id,
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
                                    const SizedBox(height: 10),
                                    TextFormField(
                                      initialValue: draft.routingHint,
                                      enabled: !widget.configureBinding,
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
                                );
                                final remove = ActionIconButton(
                                  onPressed: _candidates.length > 2
                                      ? () => setState(
                                          () => _candidates.removeAt(index),
                                        )
                                      : null,
                                  icon: Icons.delete_outline,
                                  danger: true,
                                  tooltip: tx('common.delete', 'Eliminar'),
                                );
                                if (compact) {
                                  return Column(
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.drag_handle),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              tx(
                                                'llm_orchestrations.candidate_position',
                                                'Candidata {{position}}',
                                              ).replaceAll(
                                                '{{position}}',
                                                '${index + 1}',
                                              ),
                                              style: Theme.of(
                                                context,
                                              ).textTheme.labelLarge,
                                            ),
                                          ),
                                          remove,
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      fields,
                                    ],
                                  );
                                }
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(top: 12),
                                      child: Icon(Icons.drag_handle),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(child: fields),
                                    remove,
                                  ],
                                );
                              },
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
        ),
      ),
    );
  }
}
