import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../models/explore/explore_models.dart';
import '../repositories/explore_repository.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/labels/label_catalog.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/widgets/action_icon_button.dart';
import '../../../shared/widgets/label_chips_row.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({
    required this.apiClient,
    required this.sessionController,
    required this.localeController,
    super.key,
  });

  final ApiClient apiClient;
  final SessionController sessionController;
  final LocaleController localeController;

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  late final ExploreRepository _repository;
  late final TranslatedTexts _t;
  final TextEditingController _queryController = TextEditingController();

  String _tx(String path, String fallback) => _t.text(path, fallback: fallback);

  List<ExploreItem> _items = const [];
  bool _loading = true;
  String? _error;
  String _type = 'all';
  String _category = '';
  String _label = '';
  final Set<String> _busyKeys = <String>{};
  final Set<String> _linkedKeys = <String>{};
  final Set<String> _starredKeys = <String>{};

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
    _t = TranslatedTexts(localeController: widget.localeController, namespace: 'resources')
      ..addListener(_onTextsChanged);
    _load();
  }

  void _onTextsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _queryController.dispose();
    _t.removeListener(_onTextsChanged);
    _t.dispose();
    super.dispose();
  }

  String? get _token => widget.sessionController.gaToken;

  String _itemKey(ExploreItem item) => '${item.resourceType}:${item.resourceId}';

  Future<void> _load() async {
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
        _error = _tx('explore.error_title', 'No se pudo cargar Explore');
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
    if (_linkedKeys.contains(key)) return;
    setState(() => _busyKeys.add(key));
    try {
      final result = await _repository.linkResource(
        token,
        resourceType: item.resourceType,
        resourceId: item.resourceId,
      );
      if (mounted) setState(() => _linkedKeys.add(key));
      _showMessage('Recurso enlazado: ${result['name'] ?? item.name}');
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo enlazar el recurso', isError: true);
    } finally {
      if (mounted) setState(() => _busyKeys.remove(key));
    }
  }

  Future<void> _toggleStar(ExploreItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    final key = _itemKey(item);
    final remove = _starredKeys.contains(key);
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
        if (remove) {
          _starredKeys.remove(key);
        } else {
          _starredKeys.add(key);
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

  List<(String, String)> get _typeOptions => [
    ('all', _tx('explore.type_all', 'Todos')),
    ('agent', _tx('explore.type_agents', 'Agentes')),
    ('skill', _tx('explore.type_skills', 'Skills')),
    ('knowledge', _tx('explore.type_knowledge', 'Knowledge')),
    ('workflow', _tx('explore.type_workflows', 'Workflows')),
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
                  Text(_tx('explore.error_title', 'Error cargando Explore'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_error!),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _load,
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

    final optionAll = _tx('explore.option_all', 'Todas');
    final categoryOptions = [('', optionAll), ..._categoryOptions.map((c) => (c, c))];
    final labelOptions = [('', optionAll), ...kLabelKeys.map((l) => (l, l))];

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
                        decoration: InputDecoration(
                          labelText: _tx('explore.search_hint', 'Buscar'),
                          prefixIcon: const Icon(Icons.search, size: 20),
                        ),
                        onSubmitted: (_) => _load(),
                      );
                      final typeDropdown = _dropdown(
                        label: _tx('explore.type_label', 'Tipo'),
                        value: _type,
                        options: _typeOptions,
                        onChanged: (v) {
                          setState(() => _type = v);
                          _load();
                        },
                      );
                      final categoryDropdown = _dropdown(
                        label: _tx('explore.category_label', 'Categoría'),
                        value: _category,
                        options: categoryOptions,
                        onChanged: (v) {
                          setState(() => _category = v);
                          _load();
                        },
                      );
                      final labelDropdown = _dropdown(
                        label: _tx('explore.label_label', 'Label'),
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
                          Text('${_tx('explore.results', 'Resultados')}: ${_items.length}', style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: 12),
                          if (_items.isEmpty)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(_tx('explore.empty', 'No hay resultados para ese filtro.')),
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

  static const _linkableTypes = {'agent', 'skill', 'knowledge', 'workflow'};

  Widget _buildItemCard(ExploreItem item) {
    final key = _itemKey(item);
    final busy = _busyKeys.contains(key);
    final myUsername = widget.sessionController.user?.username ?? '';
    final isOwn = myUsername.isNotEmpty && item.owner == myUsername;
    final isLinkable = !isOwn && _linkableTypes.contains(item.resourceType);
    final linked = _linkedKeys.contains(key);
    final starred = _starredKeys.contains(key);

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
            Row(
              children: [
                Icon(Icons.person_outline, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.owner,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(Icons.star, size: 14, color: Colors.amber.shade600),
                const SizedBox(width: 4),
                Text('${item.stars}', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(item.description, maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
            if (item.labels.isNotEmpty) ...[
              const SizedBox(height: 8),
              LabelChipsRow(labels: item.labels),
            ],
            if (item.tags.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: item.tags.take(6).map((tag) => _miniChip('#$tag')).toList(),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                ActionIconButton(
                  icon: Icons.visibility_outlined,
                  tooltip: _tx('explore.preview', 'Vista previa'),
                  onPressed: busy ? null : () => _preview(item),
                ),
                if (isLinkable)
                  ActionIconButton(
                    icon: linked ? Icons.link : Icons.link_outlined,
                    tooltip: linked ? _tx('explore.linked_tooltip', 'Ya enlazado') : _tx('explore.link', 'Enlazar'),
                    onPressed: (busy || linked) ? null : () => _link(item),
                  ),
                const Spacer(),
                ActionIconButton(
                  icon: starred ? Icons.star : Icons.star_outline,
                  tooltip: starred ? _tx('explore.unstar', 'Quitar de favoritos') : _tx('explore.star', 'Añadir a favoritos'),
                  onPressed: busy ? null : () => _toggleStar(item),
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
