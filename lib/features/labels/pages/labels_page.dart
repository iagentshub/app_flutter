import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../models/explore/explore_models.dart';
import '../../explore/repositories/explore_repository.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/widgets/label_chips_row.dart';

class LabelsPage extends StatefulWidget {
  const LabelsPage({
    required this.apiClient,
    required this.sessionController,
    required this.localeController,
    super.key,
  });

  final ApiClient apiClient;
  final SessionController sessionController;
  final LocaleController localeController;

  @override
  State<LabelsPage> createState() => _LabelsPageState();
}

class _LabelsPageState extends State<LabelsPage> {
  late final ExploreRepository _repository;
  late final TranslatedTexts _t;
  List<ExploreItem> _all = const [];
  List<ExploreItem> _filtered = const [];
  bool _loading = true;
  String? _error;
  String _selectedType = 'all';
  String _selectedLabel = '';

  String _tx(String path, String fallback) => _t.text(path, fallback: fallback);

  @override
  void initState() {
    super.initState();
    _repository = ExploreRepository(apiClient: widget.apiClient);
    _t = TranslatedTexts(localeController: widget.localeController, namespace: 'resources')
      ..addListener(_onTextsChanged);
    _loadBase();
  }

  void _onTextsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _t.removeListener(_onTextsChanged);
    _t.dispose();
    super.dispose();
  }

  String? get _token => widget.sessionController.gaToken;

  Future<void> _loadBase() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = _tx('common.no_session', 'No hay sesión activa');
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final all = await _repository.listResources(token, type: 'all');
      if (!mounted) return;
      setState(() {
        _all = all;
        _filtered = all;
        _loading = false;
      });
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = _tx('labels.error_generic', 'No se pudieron cargar labels');
        _loading = false;
      });
    }
  }

  Future<void> _applyFilter(String label) async {
    final token = _token;
    if (token == null || token.isEmpty) return;

    setState(() {
      _selectedLabel = label;
      _loading = true;
      _error = null;
    });

    try {
      final filtered = await _repository.listResources(
        token,
        type: _selectedType,
        label: label,
      );
      if (!mounted) return;
      setState(() {
        _filtered = filtered;
        _loading = false;
      });
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = _tx('labels.filter_error', 'No se pudo aplicar filtro');
        _loading = false;
      });
    }
  }

  Future<void> _onTypeChange(String value) async {
    setState(() => _selectedType = value);
    if (_selectedLabel.isEmpty) {
      await _loadBase();
      return;
    }
    await _applyFilter(_selectedLabel);
  }

  Map<String, int> _labelCounts() {
    final counts = <String, int>{};
    for (final item in _all) {
      for (final label in item.labels) {
        counts[label] = (counts[label] ?? 0) + 1;
      }
    }
    return counts;
  }

  void _showMessage(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.red.shade700 : null,
      ),
    );
  }

  List<DropdownMenuItem<String>> get _typeOptions => [
    DropdownMenuItem(value: 'all', child: Text(_tx('explore.type_all', 'Todos'))),
    DropdownMenuItem(value: 'agent', child: Text(_tx('explore.type_agents', 'Agentes'))),
    DropdownMenuItem(value: 'skill', child: Text(_tx('explore.type_skills', 'Skills'))),
    DropdownMenuItem(value: 'knowledge', child: Text(_tx('explore.type_knowledge', 'Knowledge'))),
    DropdownMenuItem(value: 'workflow', child: Text(_tx('explore.type_workflows', 'Workflows'))),
  ];

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_tx('labels.error_title', 'Error cargando Labels'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_error!),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _loadBase,
                    icon: const Icon(Icons.refresh),
                    label: Text(_tx('common.retry', 'Reintentar')),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final labelCounts = _labelCounts();
    final labels = labelCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 200,
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedType,
                          decoration: InputDecoration(labelText: _tx('labels.type_label', 'Tipo de recurso')),
                          items: _typeOptions,
                          onChanged: (value) {
                            if (value == null) return;
                            _onTypeChange(value);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${_tx('labels.active_label', 'Label activo')}: ${_selectedLabel.isEmpty ? _tx('labels.none', '- ninguno -') : _selectedLabel}',
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          setState(() => _selectedLabel = '');
                          await _loadBase();
                        },
                        icon: const Icon(Icons.clear_all, size: 18),
                        label: Text(_tx('labels.clear', 'Limpiar')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadBase,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text(_tx('labels.detected', 'Etiquetas detectadas'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          if (labels.isEmpty)
                            Text(_tx('labels.empty_detected', 'No hay etiquetas disponibles'))
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: labels
                                  .map(
                                    (entry) => ActionChip(
                                      label: Text('${entry.key} (${entry.value})'),
                                      onPressed: () => _applyFilter(entry.key),
                                    ),
                                  )
                                  .toList(),
                            ),
                          const SizedBox(height: 16),
                          Text('${_tx('labels.resources', 'Recursos')}: ${_filtered.length}', style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: 10),
                          if (_filtered.isEmpty)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(_tx('labels.empty_resources', 'No hay recursos para este label/filtro.')),
                              ),
                            )
                          else
                            ..._filtered.map(
                              (item) => Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: InkWell(
                                  onTap: () => _showMessage(item.description.isEmpty ? 'Sin descripción' : item.description),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text('${item.resourceType} · ${item.owner}', style: Theme.of(context).textTheme.bodySmall),
                                            const SizedBox(width: 10),
                                            Icon(Icons.star, size: 13, color: Colors.amber.shade600),
                                            const SizedBox(width: 3),
                                            Text('${item.stars}', style: Theme.of(context).textTheme.bodySmall),
                                          ],
                                        ),
                                        if (item.labels.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          LabelChipsRow(labels: item.labels),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
