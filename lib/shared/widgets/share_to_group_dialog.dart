import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../features/manager/repositories/manager_repository.dart';
import '../../models/manager/workspace_models.dart';
import '../i18n/locale_loader.dart';
import '../repositories/sharing_repository.dart';
import '../state/locale_controller.dart';

/// Diálogo para asignar un recurso a un grupo (equivalente táctil al
/// drag&drop sobre GroupPanel en frontend_vanilla, que no aplica en touch).
/// Devuelve silenciosamente si el usuario cancela.
Future<void> showShareToGroupDialog({
  required BuildContext context,
  required ApiClient apiClient,
  required String token,
  required String resourceType,
  required String resourceId,
  required LocaleController localeController,
  VoidCallback? onShared,
}) async {
  final texts = await LocaleLoader.load(isEnglish: localeController.isEnglish, namespace: 'resources');
  String tx(String path, String fallback) => LocaleLoader.text(texts, path, fallback: fallback);

  final managerRepository = ManagerRepository(apiClient: apiClient);
  List<WorkspaceItem> groups;
  try {
    groups = await managerRepository.listWorkspaces(token);
  } catch (_) {
    groups = const [];
  }
  if (!context.mounted) return;

  const removeSentinel = '';
  final result = await showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(tx('groups.share_dialog_title', 'Compartir con grupo')),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.of(context).pop(removeSentinel),
          child: Text(tx('groups.share_remove', 'Quitar de cualquier grupo')),
        ),
        if (groups.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(tx('groups.share_empty', 'No perteneces a ningún grupo todavía.')),
          ),
        for (final g in groups)
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(g.id),
            child: Text(g.name),
          ),
      ],
    ),
  );
  if (result == null) return;

  final sharingRepository = SharingRepository(apiClient: apiClient);
  try {
    await sharingRepository.share(
      token,
      resourceType: resourceType,
      resourceId: resourceId,
      groupId: result == removeSentinel ? null : result,
    );
    onShared?.call();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tx('groups.share_success', 'Recurso compartido'))),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tx('groups.share_error', 'No se pudo compartir el recurso'))),
    );
  }
}
