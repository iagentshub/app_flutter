import 'package:flutter/material.dart';

import '../../../utils/i18n.dart';
import '../controllers/notifications_controller.dart';
import '../push/web_push.dart';

/// Preferencias de aviso: qué categorías llegan por qué canal.
///
/// Va en su propia hoja y no dentro del desplegable de la campana porque son
/// dos tareas distintas: una es leer lo que ha pasado y la otra decidir qué
/// quieres que te llegue. Mezclarlas convierte el desplegable en un panel de
/// control que estorba a quien solo quería ver la invitación.
///
/// **Las categorías las publica el servidor.** Esta pantalla pinta lo que
/// reciba en `notification_categories`, sin lista propia: así añadir un tipo
/// de evento en el backend no deja aquí un interruptor que falta.
Future<void> showNotificationSettingsSheet(
  BuildContext context,
  NotificationsController controller,
) {
  controller.cargarPreferencias();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _HojaAjustes(controller: controller),
  );
}

class _HojaAjustes extends StatelessWidget {
  const _HojaAjustes({required this.controller});

  final NotificationsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final categorias = controller.categorias;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      tr('notif_ajustes'),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Text(
                    tr('notif_ajustes_pie'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (categorias.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(),
                  )
                else
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 16),
                      children: [
                        for (final entrada in categorias.entries)
                          _FilaCategoria(
                            controller: controller,
                            categoria: entrada.key,
                            estado: entrada.value,
                          ),
                      ],
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

class _FilaCategoria extends StatelessWidget {
  const _FilaCategoria({
    required this.controller,
    required this.categoria,
    required this.estado,
  });

  final NotificationsController controller;
  final String categoria;
  final Map<String, bool> estado;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // El push solo se ofrece donde puede llegar. Un interruptor que el
    // navegador nunca va a honrar es una promesa que la aplicación no cumple.
    final ofrecerPush =
        controller.puedeOfrecerPush && controller.estadoPush == PushEstado.activo;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            trOr('notif_cat_$categoria', categoria),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _Interruptor(
                  etiqueta: tr('notif_canal_email'),
                  valor: estado['email'] ?? true,
                  // Con el correo general apagado, la categoría no manda nada:
                  // enseñarlo encendido sería mentir sobre lo que va a pasar.
                  activo: controller.correoGeneral,
                  onChanged: (v) =>
                      controller.cambiarCategoria(categoria, 'email', v),
                ),
              ),
              Expanded(
                child: _Interruptor(
                  etiqueta: tr('notif_canal_push'),
                  valor: estado['push'] ?? true,
                  activo: ofrecerPush,
                  onChanged: (v) =>
                      controller.cambiarCategoria(categoria, 'push', v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Interruptor extends StatelessWidget {
  const _Interruptor({
    required this.etiqueta,
    required this.valor,
    required this.activo,
    required this.onChanged,
  });

  final String etiqueta;
  final bool valor;
  final bool activo;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Switch(value: activo && valor, onChanged: activo ? onChanged : null),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            etiqueta,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: activo
                      ? null
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}
