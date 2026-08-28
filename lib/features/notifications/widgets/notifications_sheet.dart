import 'package:flutter/material.dart';

import '../../../app/router/router.dart';
import '../../../shared/widgets/buttons/action_icon_button.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../utils/i18n.dart';
import '../controllers/notifications_controller.dart';
import '../push/web_push.dart';
import 'notification_settings_sheet.dart';

/// Abre el desplegable de la campana.
Future<void> showNotificationsSheet(
  BuildContext context,
  NotificationsController controller,
) {
  controller.load();
  controller.cargarEstadoPush();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _NotificationsSheet(controller: controller),
  );
}

class _NotificationsSheet extends StatelessWidget {
  const _NotificationsSheet({required this.controller});

  final NotificationsController controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final items = controller.items;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          tr('notifications'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (controller.unread > 0)
                        TertiaryButton(
                          onPressed: controller.markAllRead,
                          child: Text(tr('notifications_mark_all')),
                        ),
                      ActionIconButton(
                        icon: Icons.tune,
                        tooltip: tr('notif_ajustes'),
                        onPressed: () =>
                            showNotificationSettingsSheet(context, controller),
                      ),
                    ],
                  ),
                ),
                _FilaPush(controller: controller),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
                    child: Text(
                      tr('notifications_empty'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 12),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) => _NotificationTile(
                        controller: controller,
                        item: items[index],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.controller, required this.item});

  final NotificationsController controller;
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final id = '${item['id']}';
    final kind = '${item['kind']}';
    final data = (item['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    final leido = item['read'] == true;

    return ListTile(
      leading: Icon(
        _icono(kind),
        color: leido ? scheme.onSurfaceVariant : scheme.primary,
      ),
      title: Text(
        _texto(kind, data),
        style: TextStyle(
          fontWeight: leido ? FontWeight.normal : FontWeight.w600,
        ),
      ),
      trailing: _acciones(context, id, kind, data),
      onTap: () => _abrir(context, id, kind),
    );
  }

  /// Los dos botones solo salen en la invitación a grupo.
  ///
  /// ponytail: un único caso especial, escrito como tal. Es el único evento
  /// accionable que hay hoy en el producto; si aparece un segundo, entonces sí
  /// toca un mapa `kind -> widget` en vez de este `if`.
  Widget? _acciones(
    BuildContext context,
    String id,
    String kind,
    Map<String, dynamic> data,
  ) {
    if (kind != 'group_invite') return null;
    final invitacion = '${data['invitation_id'] ?? ''}';
    if (invitacion.isEmpty) return null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ActionIconButton(
          icon: Icons.check,
          tooltip: tr('groups.accept'),
          onPressed: () {
            Navigator.of(context).pop();
            controller.accept(id, invitacion);
          },
        ),
        ActionIconButton(
          icon: Icons.close,
          tooltip: tr('groups.reject'),
          danger: true,
          onPressed: () {
            Navigator.of(context).pop();
            controller.reject(id, invitacion);
          },
        ),
      ],
    );
  }

  /// La invitación se resuelve aquí mismo con los botones, así que tocarla solo
  /// la marca leída. El resto lleva a la pantalla donde está la información.
  ///
  /// Un `kind` que este cliente no conozca todavía —backend desplegado antes,
  /// que es el orden obligado— se marca leído y no navega: mejor eso que caer.
  void _abrir(BuildContext context, String id, String kind) {
    controller.markRead(id);
    if (kind == 'group_invite') return;
    Navigator.of(context).pop();
    switch (kind) {
      case 'group_member_added':
      case 'group_member_removed':
      case 'group_role_changed':
      case 'group_ownership_received':
        AppRouter.toManager(context);
      case 'license_assigned':
        AppRouter.toProfile(context);
    }
  }

  IconData _icono(String kind) => switch (kind) {
        'group_invite' => Icons.group_add_outlined,
        'group_member_removed' => Icons.person_remove_outlined,
        'group_ownership_received' => Icons.workspace_premium_outlined,
        'license_assigned' => Icons.card_membership_outlined,
        _ => Icons.groups_outlined,
      };

  /// `tr()` no interpola, así que los huecos se sustituyen a mano.
  String _texto(String kind, Map<String, dynamic> data) {
    var texto = tr('notif_$kind');
    data.forEach((clave, valor) {
      texto = texto.replaceAll('{$clave}', '$valor');
    });
    return texto;
  }
}


/// La franja que ofrece —o explica— los avisos del sistema en este dispositivo.
///
/// Vive dentro del desplegable a propósito: el permiso del navegador solo se
/// puede pedir desde un gesto del usuario, y abrir la campana es justo el
/// momento en que a alguien le interesa el tema. Pedirlo al arrancar la
/// aplicación es lo que hace que los navegadores penalicen al sitio y que el
/// usuario diga que no sin leer.
class _FilaPush extends StatelessWidget {
  const _FilaPush({required this.controller});

  final NotificationsController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (controller.requiereInstalarEnIOS) {
      return _aviso(context, Icons.ios_share, tr('notif_push_instalar_ios'));
    }
    if (!controller.puedeOfrecerPush) return const SizedBox.shrink();

    switch (controller.estadoPush) {
      case PushEstado.denegado:
        return _aviso(context, Icons.notifications_off_outlined,
            tr('notif_push_bloqueado'));
      case PushEstado.activo:
        return SwitchListTile(
          value: true,
          onChanged: (_) => controller.desactivarPush(),
          secondary: Icon(Icons.notifications_active_outlined,
              color: scheme.primary),
          title: Text(tr('notif_push_activo')),
          dense: true,
        );
      case PushEstado.disponible:
        return SwitchListTile(
          value: false,
          onChanged: (_) => controller.activarPush(),
          secondary: const Icon(Icons.notifications_none_rounded),
          title: Text(tr('notif_push_activar')),
          subtitle: Text(tr('notif_push_activar_pie')),
          dense: true,
        );
      case PushEstado.noSoportado:
        return const SizedBox.shrink();
    }
  }

  Widget _aviso(BuildContext context, IconData icono, String texto) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
