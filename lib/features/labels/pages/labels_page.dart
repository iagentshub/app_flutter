import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../models/explore/explore_models.dart';
import '../../explore/repositories/explore_repository.dart';
import '../../../shared/state/session_controller.dart';

class LabelsPage extends StatefulWidget {
  const LabelsPage({
    required this.apiClient,
    required this.sessionController,
    super.key,
  });

  final ApiClient apiClient;
  final SessionController sessionController;

  @override
  State<LabelsPage> createState() => _LabelsPageState();
}

class _LabelsPageState extends State<LabelsPage> {
  late final ExploreRepository _repository;
  List<ExploreItem> _all = const [];
  List<ExploreItem> _filtered = const [];
  bool _loading = true;
  String? _error;
  String _selectedType = 'all';
  String _selectedLabel = '';

  @override
  void initState() {
    super.initState();
    _repository = ExploreRepository(apiClient: widget.apiClient);
    _loadBase();
  }

  String? get _token => widget.sessionController.gaToken;

  Future<void> _loadBase() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'No hay sesión activa';
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
        _error = 'No se pudieron cargar labels';
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
        _error = 'No se pudo aplicar filtro';
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
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
                  const Text('Error cargando Labels', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_error!),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _loadBase,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
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

    return RefreshIndicator(
      onRefresh: _loadBase,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedType,
                      decoration: const InputDecoration(labelText: 'Tipo de recurso'),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('all')),
                        DropdownMenuItem(value: 'agent', child: Text('agent')),
                        DropdownMenuItem(value: 'skill', child: Text('skill')),
                        DropdownMenuItem(value: 'knowledge', child: Text('knowledge')),
                        DropdownMenuItem(value: 'workflow', child: Text('workflow')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        _onTypeChange(value);
                      },
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      setState(() => _selectedLabel = '');
                      await _loadBase();
                    },
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Limpiar filtro'),
                  ),
                  Text('Label activo: ${_selectedLabel.isEmpty ? '- ninguno -' : _selectedLabel}'),
                ],
              ),
              const SizedBox(height: 14),
              const Text('Etiquetas detectadas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (labels.isEmpty)
                const Text('No hay etiquetas disponibles')
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
              Text('Recursos: ${_filtered.length}', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 10),
              if (_filtered.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No hay recursos para este label/filtro.'),
                  ),
                )
              else
                ..._filtered.map(
                  (item) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(item.name),
                      subtitle: Text('${item.resourceType} · ${item.owner} · ⭐ ${item.stars}'),
                      trailing: item.labels.isEmpty ? null : Text(item.labels.join(', '), maxLines: 1),
                      onTap: () => _showMessage(item.description.isEmpty ? 'Sin descripción' : item.description),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
