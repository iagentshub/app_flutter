import 'package:flutter/material.dart';

import '../../../app/theme/fnc_fonts.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';

import '../../../models/connections/connection_models.dart';
import '../../../shared/widgets/buttons/action_icon_button.dart';
import '../../../shared/widgets/buttons/overflow_menu_button.dart';
import '../../../shared/widgets/inactive_badge.dart';
import '../../../shared/widgets/label_chips_row.dart';
import '../../../shared/widgets/origin_badge.dart';
import '../../../shared/widgets/status_dot.dart';
import '../../../shared/widgets/token_usage_badge.dart';

typedef ConnectionCardText = String Function(String path, String fallback);

class ConnectionCard extends StatelessWidget {
  const ConnectionCard({
    required this.item,
    required this.tx,
    required this.providerLabel,
    required this.onTest,
    required this.onShare,
    required this.onEdit,
    required this.onDelete,
    this.testState,
    this.testMessage,
    this.onToggleActive,
    this.onSyncHub,
    super.key,
  });

  final ConnectionItem item;
  final ConnectionCardText tx;

  /// Nombre legible del proveedor (label de `/api/connections/providers`,
  /// ej. "OpenAI") — la card ya no está agrupada por tipo internamente, la
  /// agrupación la hace la página, pero cada card sigue mostrando su
  /// proveedor como subtítulo.
  final String providerLabel;
  final VoidCallback onTest;
  final VoidCallback onShare;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Resultado del último test lanzado desde esta card (o mientras está en
  /// curso). Null = aún no se ha probado en esta sesión — no se pinta punto.
  final StatusDotState? testState;

  /// Mensaje del último test (tooltip del punto) — vacío si aún no se probó.
  final String? testMessage;

  /// Activar/desactivar (borrado suave). Null = acción no disponible.
  final VoidCallback? onToggleActive;

  /// Sincronizar con el hub remoto (solo conexiones tipo `iagentshub`).
  /// Null = acción no disponible (no es una conexión de este tipo).
  final VoidCallback? onSyncHub;

  /// Igual que en `AgentCard`: la fila de acciones no cabía a ancho de móvil
  /// —el botón de sincronizar la hacía desbordar 240 px— y lo que quedaba
  /// fuera no se podía pulsar. Probar y editar siguen a la vista; el resto
  /// entra en el menú.
  List<OverflowMenuAction> _overflowActions() {
    return [
      if (onSyncHub != null)
        OverflowMenuAction(
          icon: Icons.sync,
          label: tx('connections.sync_hub', 'Sincronizar'),
          onSelected: onSyncHub!,
        ),
      OverflowMenuAction(
        icon: Icons.group_add_outlined,
        label: tx('common.share_group', 'Compartir con grupo'),
        onSelected: onShare,
        // Una conexión virtual (la comparte otro) no es de nadie aquí: no se
        // puede volver a compartir.
        enabled: !item.isVirtual,
      ),
      if (onToggleActive != null)
        OverflowMenuAction(
          icon: item.isActive
              ? Icons.toggle_on_outlined
              : Icons.toggle_off_outlined,
          label: item.isActive
              ? tx('common.deactivate', 'Desactivar')
              : tx('common.activate', 'Activar'),
          onSelected: onToggleActive!,
        ),
      OverflowMenuAction(
        icon: Icons.delete_outline,
        label: tx('common.delete', 'Eliminar'),
        onSelected: onDelete,
        danger: true,
        separatedBefore: true,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final title = item.model.isNotEmpty ? item.model : item.name;
    final hostOrUrl = item.host.isNotEmpty
        ? item.host
        : (item.url.isNotEmpty ? item.url : '');

    final card = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (testState != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Tooltip(
                      message: testMessage?.isNotEmpty == true
                          ? testMessage!
                          : tx('connections.test', 'Test'),
                      child: StatusDot(state: testState!, size: 9),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: FncFonts.size16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (!item.isActive) ...[
                  const SizedBox(width: 8),
                  InactiveBadge(label: tx('common.inactive', 'Inactivo')),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              providerLabel,
              style: TextStyle(
                fontSize: FncFonts.size13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (hostOrUrl.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                hostOrUrl,
                style: TextStyle(
                  fontSize: FncFonts.size11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),
            LabelChipsRow(
              labels: [
                ...item.labels,
                if (item.personalKey) 'Personal',
                if (item.isVirtual) 'Virtual',
              ],
              leading: [
                OriginBadge(
                  shared: item.shared,
                  ownerLabel: tx('common.owner', 'Propietario'),
                  linkedLabel: tx('common.linked', 'Enlazado'),
                ),
                TokenUsageBadge(
                  tokensIn: item.tokensIn,
                  tokensOut: item.tokensOut,
                  tooltip: tx(
                    'connections.tokens_tooltip',
                    'Tokens consumidos',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                SecondaryButton.icon(
                  onPressed: item.isVirtual ? null : onTest,
                  icon: const Icon(Icons.health_and_safety_outlined),
                  label: Text(tx('connections.test', 'Test')),
                ),
                const Spacer(),
                ActionIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: tx('common.edit', 'Editar'),
                  onPressed: onEdit,
                ),
                OverflowMenuButton(
                  tooltip: tx('common.more_actions', 'Más acciones'),
                  actions: _overflowActions(),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (item.isActive) return card;
    return Opacity(opacity: 0.6, child: card);
  }
}
