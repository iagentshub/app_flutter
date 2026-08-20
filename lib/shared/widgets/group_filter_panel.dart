import 'package:flutter/material.dart';

import '../../app/theme/fnc_colors.dart';
import '../../app/theme/fnc_fonts.dart';
import '../../core/network/api_client.dart';
import '../../features/manager/repositories/manager_repository.dart';
import '../../models/manager/group_models.dart';
import '../i18n/translated_texts.dart';
import '../state/locale_controller.dart';
import 'responsive_dialog.dart';

/// Abre el selector de grupos (groups) como diálogo en vez de panel
/// incrustado en la página — mismo listado de [GroupFilterPanel], pero sin
/// ocupar espacio permanente en la vista mientras no se usa.
Future<void> showGroupFilterDialog(
  BuildContext context, {
  required ApiClient apiClient,
  required String token,
  required String? activeGroupId,
  required ValueChanged<String?> onSelect,
  required LocaleController localeController,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _GroupFilterDialog(
      apiClient: apiClient,
      token: token,
      activeGroupId: activeGroupId,
      onSelect: onSelect,
      localeController: localeController,
    ),
  );
}

class _GroupFilterDialog extends StatefulWidget {
  const _GroupFilterDialog({
    required this.apiClient,
    required this.token,
    required this.activeGroupId,
    required this.onSelect,
    required this.localeController,
  });

  final ApiClient apiClient;
  final String token;
  final String? activeGroupId;
  final ValueChanged<String?> onSelect;
  final LocaleController localeController;

  @override
  State<_GroupFilterDialog> createState() => _GroupFilterDialogState();
}

class _GroupFilterDialogState extends State<_GroupFilterDialog> {
  late final ManagerRepository _repository;
  late final TranslatedTexts _t;
  List<GroupItem> _groups = const [];
  bool _loading = true;
  String? _activeGroupId;

  String _tx(String path) => _t.text(path);

  @override
  void initState() {
    super.initState();
    _activeGroupId = widget.activeGroupId;
    _repository = ManagerRepository(apiClient: widget.apiClient);
    _t = TranslatedTexts(
      localeController: widget.localeController,
      namespace: 'resources',
    )..addListener(_onTextsChanged);
    _load();
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

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final groups = await _repository.listGroups(widget.token);
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _createGroup() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_tx('groups.dialog_title')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: _tx('groups.dialog_name_label'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_tx('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(_tx('common.create')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;

    try {
      await _repository.createGroup(widget.token, name);
      widget.apiClient.invalidateCache('/api/groups');
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_tx('groups.create_error'))));
    }
  }

  void _select(String? id) {
    setState(() => _activeGroupId = id);
    widget.onSelect(id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(_tx('groups.toggle_tooltip'))),
          IconButton(
            icon: const Icon(Icons.add, size: 20),
            tooltip: _tx('groups.new_group'),
            onPressed: _createGroup,
          ),
        ],
      ),
      content: SizedBox(
        width: dialogContentWidth(context, 360),
        height: dialogContentHeight(context, 420),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                children: [
                  _item(context, null, _tx('groups.all')),
                  if (_groups.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        _tx('groups.empty'),
                        style: TextStyle(
                          fontSize: FncFonts.size12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ..._groups.map((g) => _item(context, g.id, g.name)),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_tx('common.close')),
        ),
      ],
    );
  }

  Widget _item(BuildContext context, String? id, String label) {
    final selected = _activeGroupId == id;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: 0.12)
            : FncColors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _select(id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            child: Row(
              children: [
                if (selected) ...[
                  Icon(Icons.check, size: 16, color: scheme.primary),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: FncFonts.size13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? scheme.primary : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
