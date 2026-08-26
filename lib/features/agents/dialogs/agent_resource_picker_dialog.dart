import 'package:flutter/material.dart';

import '../../../models/agents/agent_import_models.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/responsive_dialog.dart';

/// Selector acotado para catálogos grandes de recursos de agente.
///
/// La búsqueda y el filtro se aplican sólo a la vista: cambiar de filtro no
/// pierde selecciones realizadas en otra categoría.
class AgentResourcePickerDialog extends StatefulWidget {
  const AgentResourcePickerDialog({
    required this.options,
    required this.initial,
    required this.tx,
    this.allowedTypes,
    this.singleSelection = false,
    super.key,
  });

  final List<AgentResourceOption> options;
  final AgentResourceSelection initial;
  final String Function(String path) tx;
  final Set<AgentResourceType>? allowedTypes;
  final bool singleSelection;

  @override
  State<AgentResourcePickerDialog> createState() =>
      _AgentResourcePickerDialogState();
}

class _AgentResourcePickerDialogState extends State<AgentResourcePickerDialog> {
  late final TextEditingController _searchController;
  late final AgentResourceSelection _selection;
  AgentResourceType? _filter;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _selection = AgentResourceSelection(
      skillIds: widget.initial.skillIds,
      knowledgeIds: widget.initial.knowledgeIds,
      knowledgePackIds: widget.initial.knowledgePackIds,
      promptIds: widget.initial.promptIds,
      toolIds: widget.initial.toolIds,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AgentResourceOption> get _visibleOptions {
    final query = _query.trim().toLowerCase();
    return widget.options.where((option) {
      if (widget.allowedTypes case final allowed?) {
        if (!allowed.contains(option.type)) return false;
      }
      if (_filter != null && option.type != _filter) return false;
      if (query.isEmpty) return true;
      return option.title.toLowerCase().contains(query) ||
          option.subtitle.toLowerCase().contains(query);
    }).toList();
  }

  String _typeLabel(AgentResourceType type) => switch (type) {
    AgentResourceType.skill => widget.tx('agents.field_skills'),
    AgentResourceType.knowledgePack => widget.tx(
      'agents.field_knowledge_packs',
    ),
    AgentResourceType.knowledge => widget.tx('agents.field_knowledge'),
    AgentResourceType.prompt => widget.tx('agents.field_prompts'),
    AgentResourceType.tool => widget.tx('agents.field_tools'),
  };

  IconData _typeIcon(AgentResourceType type) => switch (type) {
    AgentResourceType.skill => Icons.auto_awesome_outlined,
    AgentResourceType.knowledgePack => Icons.inventory_2_outlined,
    AgentResourceType.knowledge => Icons.description_outlined,
    AgentResourceType.prompt => Icons.short_text_outlined,
    AgentResourceType.tool => Icons.build_outlined,
  };

  void _toggle(AgentResourceOption option, bool selected) {
    setState(() {
      if (widget.singleSelection) {
        for (final type in AgentResourceType.values) {
          _selection.idsFor(type).clear();
        }
      }
      final ids = _selection.idsFor(option.type);
      if (selected) {
        ids.add(option.id);
      } else {
        ids.remove(option.id);
      }
    });
    if (widget.singleSelection && selected) _apply();
  }

  void _apply() => Navigator.of(context).pop(_selection);

  Widget _selectionCount(ThemeData theme) {
    return Text(
      widget
          .tx('agents.resources_selected_count')
          .replaceAll('{{count}}', '${_selection.length}'),
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildContent(ThemeData theme, {required bool mobile}) {
    final visible = _visibleOptions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const ValueKey('agent-resources-search'),
          controller: _searchController,
          autofocus: !mobile,
          decoration: InputDecoration(
            hintText: widget.tx('agents.resources_search_hint'),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _query.isEmpty
                ? null
                : AppIconButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                    icon: const Icon(Icons.close),
                    tooltip: widget.tx('agents.resources_clear_search'),
                  ),
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                label: Text(widget.tx('agents.resources_all')),
                selected: _filter == null,
                onSelected: (_) => setState(() => _filter = null),
              ),
              const SizedBox(width: 8),
              for (final type in AgentResourceType.values.where(
                (type) => widget.allowedTypes?.contains(type) ?? true,
              )) ...[
                FilterChip(
                  avatar: Icon(_typeIcon(type), size: 16),
                  label: Text(_typeLabel(type)),
                  selected: _filter == type,
                  onSelected: (_) => setState(() => _filter = type),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        if (mobile) ...[const SizedBox(height: 10), _selectionCount(theme)],
        const SizedBox(height: 8),
        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Text(
                    widget.tx('agents.resources_no_match'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.separated(
                  key: const ValueKey('agent-resources-list'),
                  itemCount: visible.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  itemBuilder: (context, index) {
                    final option = visible[index];
                    final selected = _selection
                        .idsFor(option.type)
                        .contains(option.id);
                    return CheckboxListTile(
                      key: ValueKey(
                        'agent-resource-${option.type.name}-${option.id}',
                      ),
                      contentPadding: EdgeInsets.zero,
                      dense: !mobile,
                      value: selected,
                      secondary: Icon(_typeIcon(option.type), size: 20),
                      title: Text(
                        option.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        [
                          _typeLabel(option.type),
                          if (option.subtitle.isNotEmpty) option.subtitle,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onChanged: (value) => _toggle(option, value ?? false),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mobile = MediaQuery.sizeOf(context).width < 600;
    if (mobile) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            leading: AppIconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
              tooltip: widget.tx('common.cancel'),
            ),
            title: Text(widget.tx('agents.resources_picker_mobile_title')),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: AppIconButton.filled(
                  key: const ValueKey('agent-resources-apply'),
                  onPressed: _apply,
                  icon: const Icon(Icons.check),
                  tooltip: widget.tx('agents.resources_apply'),
                ),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _buildContent(theme, mobile: true),
            ),
          ),
        ),
      );
    }

    return AlertDialog(
      title: Text(widget.tx('agents.resources_picker_title')),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      content: SizedBox(
        width: dialogContentWidth(context, 680),
        height: dialogContentHeight(context, 560),
        child: _buildContent(theme, mobile: false),
      ),
      actions: [
        _selectionCount(theme),
        TertiaryButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.tx('common.cancel')),
        ),
        PrimaryButton(
          key: const ValueKey('agent-resources-apply'),
          onPressed: _apply,
          child: Text(widget.tx('agents.resources_apply')),
        ),
      ],
    );
  }
}
