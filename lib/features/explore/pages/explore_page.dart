import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../models/explore/explore_models.dart';
import '../repositories/explore_repository.dart';
import '../../../shared/labels/label_catalog.dart';
import '../../../shared/state/session_controller.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({
    required this.apiClient,
    required this.sessionController,
    super.key,
  });

  final ApiClient apiClient;
  final SessionController sessionController;

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  late final ExploreRepository _repository;
  final TextEditingController _queryController = TextEditingController();

  List<ExploreItem> _items = const [];
  bool _loading = true;
  String? _error;
  String _type = 'all';
  String _category = '';
  String _label = '';
  final Set<String> _busyKeys = <String>{};

  List<String> get _categoryOptions {
    final set = <String>{};
    for (final item in _items) {
      if (item.category.isNotEmpty) set.add(item.category);
    }
    final list = set.toList()..sort();
    return list;
  }

  @override
  void initState() {
    super.initState();
    _repository = ExploreRepository(apiClient: widget.apiClient);
    _load();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  String? get _token => widget.sessionController.gaToken;

  String _itemKey(ExploreItem item) => '${item.resourceType}:${item.resourceId}';

  Future<void> _load() async {
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
      final items = await _repository.listResources(
        token,
        type: _type,
        query: _queryController.text,
        category: _category,
        label: _label,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        if (_category.isNotEmpty && !_categoryOptions.contains(_category)) {
          _category = '';
        }
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
        _error = 'No se pudo cargar Explore';
        _loading = false;
      });
    }
  }

  Future<void> _preview(ExploreItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    final key = _itemKey(item);
    setState(() => _busyKeys.add(key));
    try {
      final preview = await _repository.getPreview(
        token,
        resourceType: item.resourceType,
        resourceId: item.resourceId,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => _PreviewDialog(
          title: item.name,
          jsonPayload: preview,
        ),
      );
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo cargar preview', isError: true);
    } finally {
      if (mounted) setState(() => _busyKeys.remove(key));
    }
  }

  Future<void> _link(ExploreItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    final key = _itemKey(item);
    setState(() => _busyKeys.add(key));
    try {
      final result = await _repository.linkResource(
        token,
        resourceType: item.resourceType,
        resourceId: item.resourceId,
      );
      _showMessage('Recurso enlazado: ${result['name'] ?? item.name}');
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo enlazar el recurso', isError: true);
    } finally {
      if (mounted) setState(() => _busyKeys.remove(key));
    }
  }

  Future<void> _star(ExploreItem item, {required bool remove}) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    final key = _itemKey(item);
    setState(() => _busyKeys.add(key));
    try {
      final stars = remove
          ? await _repository.unstar(token, resourceType: item.resourceType, resourceId: item.resourceId)
          : await _repository.star(token, resourceType: item.resourceType, resourceId: item.resourceId);

      if (!mounted) return;
      setState(() {
        final idx = _items.indexWhere(
          (element) =>
              element.resourceType == item.resourceType && element.resourceId == item.resourceId,
        );
        if (idx >= 0) {
          _items[idx].raw['stars_count'] = stars;
        }
      });
      _showMessage(remove ? 'Star removido' : 'Star añadido');
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo actualizar star', isError: true);
    } finally {
      if (mounted) setState(() => _busyKeys.remove(key));
    }
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

  static const _typeOptions = [
    ('all', 'Todos'),
    ('agent', 'Agentes'),
    ('skill', 'Skills'),
    ('knowledge', 'Knowledge'),
    ('workflow', 'Workflows'),
  ];

  Widget _dropdown({
    required String label,
    required String value,
    required List<(String, String)> options,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      isExpanded: true,
      items: options
          .map((opt) => DropdownMenuItem(value: opt.$1, child: Text(opt.$2, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: (next) {
        if (next == null) return;
        onChanged(next);
      },
    );
  }

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
                  const Text('Error cargando Explore', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_error!),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _load,
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

    final categoryOptions = [('', 'Todas'), ..._categoryOptions.map((c) => (c, c))];
    final labelOptions = [('', 'Todas'), ...kLabelKeys.map((l) => (l, l))];

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
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final searchField = TextField(
                        controller: _queryController,
                        decoration: const InputDecoration(
                          labelText: 'Buscar',
                          prefixIcon: Icon(Icons.search, size: 20),
                        ),
                        onSubmitted: (_) => _load(),
                      );
                      final typeDropdown = _dropdown(
                        label: 'Tipo',
                        value: _type,
                        options: _typeOptions,
                        onChanged: (v) {
                          setState(() => _type = v);
                          _load();
                        },
                      );
                      final categoryDropdown = _dropdown(
                        label: 'Categoría',
                        value: _category,
                        options: categoryOptions,
                        onChanged: (v) {
                          setState(() => _category = v);
                          _load();
                        },
                      );
                      final labelDropdown = _dropdown(
                        label: 'Label',
                        value: _label,
                        options: labelOptions,
                        onChanged: (v) {
                          setState(() => _label = v);
                          _load();
                        },
                      );

                      if (constraints.maxWidth < 620) {
                        return Column(
                          children: [
                            searchField,
                            const SizedBox(height: 10),
                            typeDropdown,
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(child: categoryDropdown),
                                const SizedBox(width: 10),
                                Expanded(child: labelDropdown),
                              ],
                            ),
                          ],
                        );
                      }

                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(width: 220, child: searchField),
                          SizedBox(width: 160, child: typeDropdown),
                          SizedBox(width: 160, child: categoryDropdown),
                          SizedBox(width: 160, child: labelDropdown),
                        ],
                      );
                    },
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
                  onRefresh: _load,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text('Resultados: ${_items.length}', style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: 12),
                          if (_items.isEmpty)
                            const Card(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('No hay resultados para ese filtro.'),
                              ),
                            )
                          else
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: _items.map((item) {
                                return SizedBox(width: 360, child: _buildItemCard(item));
                              }).toList(),
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

  Widget _buildItemCard(ExploreItem item) {
    final key = _itemKey(item);
    final busy = _busyKeys.contains(key);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                _chip(item.resourceType),
                _chip(item.category),
              ],
            ),
            const SizedBox(height: 6),
            Text('por ${item.owner} · ⭐ ${item.stars}'),
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(item.description, maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
            if (item.tags.isNotEmpty || item.labels.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ...item.tags.take(4).map((tag) => _miniChip('#$tag')),
                  ...item.labels.take(4).map((label) => _miniChip(label)),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : () => _preview(item),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Preview'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => _link(item),
                  icon: const Icon(Icons.link_outlined),
                  label: const Text('Link'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => _star(item, remove: false),
                  icon: const Icon(Icons.star_outline),
                  label: const Text('Star'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => _star(item, remove: true),
                  icon: const Icon(Icons.star_border_purple500_outlined),
                  label: const Text('Unstar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _miniChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(fontSize: 11)),
    );
  }
}

class _PreviewDialog extends StatelessWidget {
  const _PreviewDialog({required this.title, required this.jsonPayload});

  final String title;
  final Map<String, dynamic> jsonPayload;

  @override
  Widget build(BuildContext context) {
    final pretty = const JsonEncoder.withIndent('  ').convert(jsonPayload);
    return AlertDialog(
      title: Text('Preview: $title'),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: SelectableText(pretty, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        ),
      ),
      actions: [
        FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')),
      ],
    );
  }
}
