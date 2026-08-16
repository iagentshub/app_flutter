import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../features/manager/repositories/manager_repository.dart';
import '../../models/manager/group_models.dart';
import '../i18n/locale_loader.dart';
import '../repositories/sharing_repository.dart';
import '../state/locale_controller.dart';
import 'responsive_dialog.dart';
import 'status_dot.dart';

/// Diálogo para compartir un recurso con uno o varios grupos a la vez. Cada
/// grupo muestra un punto de estado: verde si el recurso ya está compartido
/// con él, rojo si no, naranja parpadeante mientras se aplica el cambio —
/// tocar una fila alterna (comparte/descomparte) ese grupo en concreto, sin
/// afectar a los demás.
Future<void> showShareToGroupDialog({
  required BuildContext context,
  required ApiClient apiClient,
  required String token,
  required String resourceType,
  required String resourceId,
  required LocaleController localeController,
  VoidCallback? onShared,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _ShareToGroupDialog(
      apiClient: apiClient,
      token: token,
      resourceType: resourceType,
      resourceId: resourceId,
      localeController: localeController,
      onShared: onShared,
    ),
  );
}

class _ShareToGroupDialog extends StatefulWidget {
  const _ShareToGroupDialog({
    required this.apiClient,
    required this.token,
    required this.resourceType,
    required this.resourceId,
    required this.localeController,
    this.onShared,
  });

  final ApiClient apiClient;
  final String token;
  final String resourceType;
  final String resourceId;
  final LocaleController localeController;
  final VoidCallback? onShared;

  @override
  State<_ShareToGroupDialog> createState() => _ShareToGroupDialogState();
}

class _ShareToGroupDialogState extends State<_ShareToGroupDialog> {
  late final ManagerRepository _managerRepository;
  late final SharingRepository _sharingRepository;
  Map<String, dynamic> _texts = const {};
  List<GroupItem> _groups = const [];
  Set<String> _sharedGroupIds = {};
  final Set<String> _pending = {};
  bool _loading = true;
  String? _error;

  String _tx(String path, String fallback) =>
      LocaleLoader.text(_texts, path, fallback: fallback);

  @override
  void initState() {
    super.initState();
    _managerRepository = ManagerRepository(apiClient: widget.apiClient);
    _sharingRepository = SharingRepository(apiClient: widget.apiClient);
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
        _managerRepository.listGroups(widget.token),
        _sharingRepository.listGroups(
          widget.token,
          resourceType: widget.resourceType,
          resourceId: widget.resourceId,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _texts = results[0] as Map<String, dynamic>;
        _groups = results[1] as List<GroupItem>;
        _sharedGroupIds = (results[2] as List<String>).toSet();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar la lista de grupos';
        _loading = false;
      });
    }
  }

  Future<void> _toggle(GroupItem group) async {
    if (_pending.contains(group.id)) return;
    final wasShared = _sharedGroupIds.contains(group.id);
    setState(() => _pending.add(group.id));
    try {
      if (wasShared) {
        final result = await _sharingRepository.unshare(
          widget.token,
          resourceType: widget.resourceType,
          resourceId: widget.resourceId,
          groupId: group.id,
        );
        // Lo retirado no hace falta contarlo: es lo que el usuario esperaba.
        // Lo que se queda sí, porque contradice lo que acaba de pedir.
        if (mounted && result.kept.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _tx(
                  'groups.unshare_kept',
                  '{count} recursos siguen compartidos porque otro recurso del '
                      'grupo los usa.',
                ).replaceAll('{count}', '${result.kept.length}'),
              ),
            ),
          );
        }
      } else {
        await _sharingRepository.share(
          widget.token,
          resourceType: widget.resourceType,
          resourceId: widget.resourceId,
          groupId: group.id,
        );
      }
      if (!mounted) return;
      setState(() {
        _pending.remove(group.id);
        if (wasShared) {
          _sharedGroupIds.remove(group.id);
        } else {
          _sharedGroupIds.add(group.id);
        }
      });
      widget.onShared?.call();
    } catch (_) {
      if (!mounted) return;
      setState(() => _pending.remove(group.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tx('groups.share_error', 'No se pudo compartir el recurso'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_tx('groups.share_dialog_title', 'Compartir con grupo')),
      content: SizedBox(
        width: dialogContentWidth(context, 380),
        child: _loading
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              )
            : _error != null
            ? Text(_error!)
            : _groups.isEmpty
            ? Text(
                _tx(
                  'groups.share_empty',
                  'No perteneces a ningún grupo todavía.',
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _groups.map((group) {
                    final pending = _pending.contains(group.id);
                    final shared = _sharedGroupIds.contains(group.id);
                    return ListTile(
                      dense: true,
                      leading: StatusDot(
                        state: pending
                            ? StatusDotState.pending
                            : shared
                            ? StatusDotState.ok
                            : StatusDotState.error,
                        semanticLabel: pending
                            ? _tx('groups.share_pending', 'Actualizando')
                            : shared
                            ? _tx('groups.shared', 'Compartido')
                            : _tx('groups.not_shared', 'No compartido'),
                      ),
                      title: Text(group.name),
                      onTap: pending ? null : () => _toggle(group),
                    );
                  }).toList(),
                ),
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
