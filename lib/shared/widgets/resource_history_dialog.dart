import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../models/common/resource_version.dart';
import '../i18n/locale_loader.dart';
import '../repositories/resource_version_repository.dart';
import '../state/locale_controller.dart';
import 'responsive_dialog.dart';

String _fmtVersionDate(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final local = parsed.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
}

/// Diálogo de historial de versiones — solo agentes y skills, que es lo
/// único que soporta el backend. Cada guardado crea una versión sola; aquí
/// solo se listan y se pueden restaurar.
Future<void> showResourceHistoryDialog({
  required BuildContext context,
  required ApiClient apiClient,
  required String token,
  required String resourceType,
  required String resourceId,
  required LocaleController localeController,
  VoidCallback? onRestored,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _ResourceHistoryDialog(
      apiClient: apiClient,
      token: token,
      resourceType: resourceType,
      resourceId: resourceId,
      localeController: localeController,
      onRestored: onRestored,
    ),
  );
}

class _ResourceHistoryDialog extends StatefulWidget {
  const _ResourceHistoryDialog({
    required this.apiClient,
    required this.token,
    required this.resourceType,
    required this.resourceId,
    required this.localeController,
    this.onRestored,
  });

  final ApiClient apiClient;
  final String token;
  final String resourceType;
  final String resourceId;
  final LocaleController localeController;
  final VoidCallback? onRestored;

  @override
  State<_ResourceHistoryDialog> createState() => _ResourceHistoryDialogState();
}

class _ResourceHistoryDialogState extends State<_ResourceHistoryDialog> {
  late final ResourceVersionRepository _repository;
  Map<String, dynamic> _texts = const {};
  List<ResourceVersionItem> _versions = const [];
  bool _loading = true;
  String? _error;
  int? _restoring;

  String _tx(String path, String fallback) =>
      LocaleLoader.text(_texts, path, fallback: fallback);

  @override
  void initState() {
    super.initState();
    _repository = ResourceVersionRepository(apiClient: widget.apiClient);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        LocaleLoader.load(
          languageCode: widget.localeController.languageCode,
          namespace: 'resources',
        ),
        _repository.listVersions(
          widget.token,
          resourceType: widget.resourceType,
          resourceId: widget.resourceId,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _texts = results[0] as Map<String, dynamic>;
        _versions = results[1] as List<ResourceVersionItem>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = _tx(
          'history.load_error',
          'No se pudo cargar el historial de versiones',
        );
        _loading = false;
      });
    }
  }

  Future<void> _restore(ResourceVersionItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_tx('history.restore_title', 'Restaurar versión')),
        content: Text(
          _tx(
            'history.restore_confirm',
            '¿Restaurar la versión {version}? Sobrescribirá el contenido actual.',
          ).replaceAll('{version}', '${item.version}'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_tx('common.cancel', 'Cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_tx('history.restore_action', 'Restaurar')),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _restoring = item.version);
    try {
      await _repository.restoreVersion(
        widget.token,
        resourceType: widget.resourceType,
        resourceId: widget.resourceId,
        version: item.version,
      );
      widget.onRestored?.call();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _restoring = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tx('history.restore_error', 'No se pudo restaurar la versión'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_tx('history.dialog_title', 'Historial de versiones')),
      content: SizedBox(
        width: dialogContentWidth(context, 420),
        height: dialogContentHeight(context, 420),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Text(_error!)
            : _versions.isEmpty
            ? Text(_tx('history.empty', 'Todavía no hay versiones guardadas.'))
            : ListView.separated(
                itemCount: _versions.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = _versions[index];
                  final restoringThis = _restoring == item.version;
                  return ListTile(
                    dense: true,
                    title: Text(
                      _tx(
                        'history.version_label',
                        'Versión {version}',
                      ).replaceAll('{version}', '${item.version}'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${_fmtVersionDate(item.createdAt)}'
                      '${item.createdBy.isNotEmpty ? ' · ${item.createdBy}' : ''}'
                      '${item.isRestore ? ' · ${_tx('history.reason_restore', 'restaurada')}' : ''}',
                    ),
                    trailing: index == 0
                        ? Text(
                            _tx('history.current', 'Actual'),
                            style: Theme.of(context).textTheme.bodySmall,
                          )
                        : TextButton(
                            onPressed: _restoring != null
                                ? null
                                : () => _restore(item),
                            child: restoringThis
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _tx('history.restore_action', 'Restaurar'),
                                  ),
                          ),
                  );
                },
              ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_tx('common.close', 'Cerrar')),
        ),
      ],
    );
  }
}
