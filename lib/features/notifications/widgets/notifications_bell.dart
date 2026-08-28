import 'package:flutter/material.dart';

import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../utils/i18n.dart';
import '../controllers/notifications_controller.dart';
import 'notifications_sheet.dart';

/// Campana con el contador de avisos sin leer.
///
/// Va en las dos barras superiores del shell: la ancha (`_ShellTopBar`) y el
/// `AppBar` del layout estrecho, que no comparten widget.
///
/// El contador es el `Badge` de Material, no un montaje propio: ya coloca,
/// recorta y anuncia el número.
class NotificationsBell extends StatelessWidget {
  const NotificationsBell({required this.controller, super.key});

  final NotificationsController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.enabled) return const SizedBox.shrink();
        final unread = controller.unread;
        final boton = AppIconButton(
          tooltip: tr('notifications'),
          icon: Icon(
            unread > 0
                ? Icons.notifications_rounded
                : Icons.notifications_none_rounded,
          ),
          onPressed: () => showNotificationsSheet(context, controller),
        );
        if (unread == 0) return boton;
        return Badge.count(count: unread, child: boton);
      },
    );
  }
}
