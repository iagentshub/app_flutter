import 'package:flutter/material.dart';

import '../../../models/connections/connection_models.dart';
import '../../../models/workflows/llm_orchestration_models.dart';
import '../../../shared/utils/breakpoints.dart';
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
  final String Function(String path) tx;

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
          content: Text(widget.tx('llm_orchestrations.minimum_candidates')),
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
    final anchoVentana = MediaQuery.sizeOf(context).width;
    final compactScreen = anchoVentana < 480;
    // Dos columnas solo cuando de verdad hay sitio: por debajo, la pila única
    // de siempre. En una ventana ancha esa pila dejaba ~510 px de vacío a cada
    // lado y hacía que la pantalla se leyera como una app de móvil estirada.
    final dosColumnas = anchoVentana >= Breakpoints.ancho;
    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          widget.configureBinding
              ? tx('llm_orchestrations.configure_connections')
              : widget.initial == null
              ? tx('llm_orchestrations.create')
              : tx('llm_orchestrations.edit'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: compactScreen
                ? AppIconButton.filled(
                    key: const ValueKey('llm-orchestration-save'),
                    onPressed: _save,
                    icon: const Icon(Icons.check, size: 18),
                    tooltip: tx('common.save'),
                  )
                : PrimaryButton.icon(
                    key: const ValueKey('llm-orchestration-save'),
                    onPressed: _save,
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(tx('common.save')),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: dosColumnas
                  ? Breakpoints.extraAncho
                  : Breakpoints.anchoLectura,
            ),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  anchoVentana < Breakpoints.compacto ? 16 : 24,
                  20,
                  anchoVentana < Breakpoints.compacto ? 16 : 24,
                  32,
                ),
                child: dosColumnas
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // La configuración es texto y desplegables: se lee
                          // mejor estrecha, así que no se estira con la ventana.
                          SizedBox(
                            width: 480,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _camposConfiguracion(),
                            ),
                          ),
                          const SizedBox(width: 32),
                          // Las candidatas son la lista de trabajo: se quedan
                          // con el ancho que sobre.
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _seccionCandidatas(),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ..._camposConfiguracion(),
                          const SizedBox(height: 16),
                          ..._seccionCandidatas(),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Qué es la orquestación y cómo enruta: nombre, descripción, modo y —solo
  /// en balanceo— la conexión orquestadora.
  List<Widget> _camposConfiguracion() {
    final tx = widget.tx;
    return [
      TextFormField(
        controller: _name,
        enabled: !widget.configureBinding,
        decoration: InputDecoration(labelText: tx('llm_orchestrations.name')),
        validator: (value) => value == null || value.trim().isEmpty
            ? tx('llm_orchestrations.name_required')
            : null,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _description,
        enabled: !widget.configureBinding,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: tx('llm_orchestrations.description'),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        tx('llm_orchestrations.mode'),
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(fontWeight: FontWeight.w700),
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
              label: Text(tx('llm_orchestrations.stack')),
            ),
            ButtonSegment(
              value: 'balanced',
              label: Text(tx('llm_orchestrations.balanced')),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: widget.configureBinding
              ? null
              : (selection) => setState(() => _mode = selection.first),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        _mode == 'balanced'
            ? tx('llm_orchestrations.balanced_help')
            : tx('llm_orchestrations.stack_help'),
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      if (_mode == 'balanced') ...[
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _routerConnectionId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: tx('llm_orchestrations.router'),
            helperText: tx('llm_orchestrations.router_help'),
          ),
          items: widget.connections
              .map(
                (item) => DropdownMenuItem(
                  value: item.id,
                  child: Text('${item.name} (${item.model})'),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _routerConnectionId = value),
          validator: (value) => _mode == 'balanced' && value == null
              ? tx('llm_orchestrations.router_required')
              : null,
        ),
      ],
    ];
  }

  /// Las conexiones candidatas, con su orden de ejecución.
  List<Widget> _seccionCandidatas() {
    final tx = widget.tx;
    return [
      Row(
        children: [
          Expanded(
            child: Text(
              tx('llm_orchestrations.candidates'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          AppIconButton.outlined(
            onPressed: _candidates.length < widget.connections.length
                ? _addCandidate
                : null,
            icon: const Icon(Icons.add),
            tooltip: tx('llm_orchestrations.add_candidate'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
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
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact =
                      constraints.maxWidth < Breakpoints.candidataCompacta;
                  // Los dos campos son cortos —un desplegable y una frase— y
                  // apilarlos daba dos filas por candidata en una lista que ya
                  // es larga. Con sitio van uno al lado del otro.
                  final camposEnFila =
                      constraints.maxWidth >= Breakpoints.candidataEnFila;
                  final conexion = DropdownButtonFormField<String>(
                    initialValue: draft.connectionId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: tx('llm_orchestrations.candidate_connection'),
                    ),
                    items: widget.connections
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            enabled: !_candidates.any(
                              (other) =>
                                  other != draft &&
                                  other.connectionId == item.id,
                            ),
                            child: Text('${item.name} (${item.model})'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(
                      () => draft.connectionId = value ?? draft.connectionId,
                    ),
                  );
                  final instruccion = TextFormField(
                    initialValue: draft.routingHint,
                    enabled: !widget.configureBinding,
                    decoration: InputDecoration(
                      labelText: tx('llm_orchestrations.routing_hint'),
                      hintText: tx('llm_orchestrations.routing_hint_example'),
                    ),
                    onChanged: (value) => draft.routingHint = value,
                  );
                  final fields = camposEnFila
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: conexion),
                            const SizedBox(width: 12),
                            Expanded(flex: 2, child: instruccion),
                          ],
                        )
                      : Column(
                          children: [
                            conexion,
                            const SizedBox(height: 10),
                            instruccion,
                          ],
                        );
                  final remove = ActionIconButton(
                    onPressed: _candidates.length > 2
                        ? () => setState(() => _candidates.removeAt(index))
                        : null,
                    icon: Icons.delete_outline,
                    danger: true,
                    tooltip: tx('common.delete'),
                  );
                  final dragHandle = ReorderableDragStartListener(
                    index: index,
                    child: const Icon(Icons.drag_handle),
                  );
                  if (compact) {
                    return Column(
                      children: [
                        Row(
                          children: [
                            dragHandle,
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                tx('llm_orchestrations.candidate_position')
                                    .replaceAll('{{position}}', '${index + 1}'),
                                style: Theme.of(context).textTheme.labelLarge,
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
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: dragHandle,
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
    ];
  }
}
