import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/fnc_colors.dart';
import '../../../app/theme/fnc_fonts.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/confirm_action_dialog.dart';

import '../../../shared/i18n/locale_loader.dart';
import '../../../shared/state/backend_controller.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/widgets/responsive_dialog.dart';
import '../../../shared/widgets/status_dot.dart';

part '../dialogs/backend_form_dialog.dart';

class BackendConfigPage extends StatefulWidget {
  const BackendConfigPage({
    required this.backendController,
    required this.localeController,
    super.key,
  });

  final BackendController backendController;
  final LocaleController localeController;

  @override
  State<BackendConfigPage> createState() => _BackendConfigPageState();
}

class _BackendConfigPageState extends State<BackendConfigPage> {
  late Future<Map<String, dynamic>> _textsFuture;

  // null = comprobando/desconocido, true = responde, false = no responde.
  final Map<String, bool?> _health = {};
  Timer? _healthTimer;

  @override
  void initState() {
    super.initState();
    _textsFuture = LocaleLoader.load(
      isEnglish: widget.localeController.isEnglish,
      namespace: 'auth',
    );
    widget.backendController.addListener(_onChanged);
    _refreshHealth();
    _healthTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => _refreshHealth(),
    );
  }

  @override
  void dispose() {
    widget.backendController.removeListener(_onChanged);
    _healthTimer?.cancel();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refreshHealth() async {
    final options = widget.backendController.options;
    await Future.wait(
      options.map((option) async {
        final result = await widget.backendController.pingBackend(
          option.baseUrl,
        );
        if (!mounted) return;
        setState(() => _health[option.id] = result.ok);
      }),
    );
  }

  String _txt(Map<String, dynamic> bundle, String path, String fallback) {
    return LocaleLoader.text(bundle, path, fallback: fallback);
  }

  Future<void> _openAddDialog(Map<String, dynamic> t) async {
    final saved = await showDialog<SavedBackend>(
      context: context,
      builder: (context) => _BackendFormDialog(
        backendController: widget.backendController,
        t: t,
        txt: _txt,
      ),
    );
    if (saved != null && mounted) {
      setState(() => _health[saved.id] = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _txt(
              t,
              'backend_config.added_toast',
              'Backend "{name}" añadido',
            ).replaceAll('{name}', saved.name),
          ),
        ),
      );
    }
  }

  Future<void> _openEditDialog(
    Map<String, dynamic> t,
    SavedBackend backend,
  ) async {
    final saved = await showDialog<SavedBackend>(
      context: context,
      builder: (context) => _BackendFormDialog(
        backendController: widget.backendController,
        t: t,
        txt: _txt,
        existing: backend,
      ),
    );
    if (saved != null && mounted) {
      setState(() => _health[saved.id] = true);
    }
  }

  Future<void> _confirmDelete(
    Map<String, dynamic> t,
    SavedBackend backend,
  ) async {
    final confirm = await showConfirmActionDialog(
      context,
      title: _txt(t, 'backend_config.delete_dialog_title', 'Eliminar backend'),
      message: _txt(
        t,
        'backend_config.delete_dialog_body',
        '¿Seguro que quieres eliminar "{name}"?',
      ).replaceAll('{name}', backend.name),
      cancelLabel: _txt(t, 'backend_config.cancel', 'Cancelar'),
      confirmLabel: _txt(t, 'backend_config.delete_confirm', 'Eliminar'),
      destructive: true,
    );
    if (confirm) {
      await widget.backendController.removeBackend(backend.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _textsFuture,
      builder: (context, snapshot) {
        final t = snapshot.data ?? const <String, dynamic>{};
        final selectedId = widget.backendController.selectedBackendId;
        final options = widget.backendController.options;
        final connectionError = widget.backendController.lastConnectionError;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              _txt(t, 'backend_config.page_title', 'Configurar backend'),
            ),
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      _txt(
                        t,
                        'backend_config.list_title',
                        'Backends disponibles',
                      ),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _txt(
                        t,
                        'backend_config.list_subtitle',
                        'Elige a cuál conectarte, o añade uno nuevo.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 14),
                    ...options.map((option) {
                      final selected = option.id == selectedId;
                      final official = widget.backendController.isOfficial(
                        option.id,
                      );
                      final savedEntry = widget.backendController.savedBackends
                          .where((b) => b.id == option.id)
                          .firstOrNull;
                      return _BackendRow(
                        label: option.label,
                        url: option.baseUrl,
                        selected: selected,
                        official: official,
                        health: _health[option.id],
                        errorMessage: (selected && connectionError != null)
                            ? connectionError
                            : null,
                        officialLabel: _txt(
                          t,
                          'backend_config.official_badge',
                          'Oficial',
                        ),
                        editTooltip: _txt(
                          t,
                          'backend_config.edit_tooltip',
                          'Editar',
                        ),
                        deleteTooltip: _txt(
                          t,
                          'backend_config.delete_tooltip',
                          'Eliminar',
                        ),
                        onTap: () => widget.backendController
                            .setSelectedBackend(option.id),
                        onEdit: (official || savedEntry == null)
                            ? null
                            : () => _openEditDialog(t, savedEntry),
                        onDelete: (official || savedEntry == null)
                            ? null
                            : () => _confirmDelete(t, savedEntry),
                      );
                    }),
                    const SizedBox(height: 8),
                    SecondaryButton.icon(
                      onPressed: () => _openAddDialog(t),
                      icon: const Icon(Icons.add),
                      label: Text(
                        _txt(t, 'backend_config.add_button', 'Añadir backend'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _BackendRow extends StatelessWidget {
  const _BackendRow({
    required this.label,
    required this.url,
    required this.selected,
    required this.official,
    required this.health,
    required this.errorMessage,
    required this.officialLabel,
    required this.editTooltip,
    required this.deleteTooltip,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final String label;
  final String url;
  final bool selected;
  final bool official;
  final bool? health;
  final String? errorMessage;
  final String officialLabel;
  final String editTooltip;
  final String deleteTooltip;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: selected ? scheme.primaryContainer.withValues(alpha: 0.35) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: selected
            ? BorderSide(color: scheme.primary, width: 1.4)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected ? scheme.primary : scheme.outline,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        StatusDot(
                          state: switch (health) {
                            true => StatusDotState.ok,
                            false => StatusDotState.error,
                            null => StatusDotState.unknown,
                          },
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            label,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (official) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: FncColors.materialBlue.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              officialLabel,
                              style: const TextStyle(
                                fontSize: FncFonts.size10,
                                fontWeight: FontWeight.w700,
                                color: FncColors.materialBlue,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      url,
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        errorMessage!,
                        style: const TextStyle(
                          color: FncColors.materialRed800,
                          fontSize: FncFonts.size11,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (onEdit != null)
                AppIconButton(
                  tooltip: editTooltip,
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: onEdit,
                ),
              if (onDelete != null)
                AppIconButton(
                  tooltip: deleteTooltip,
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: onDelete,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
