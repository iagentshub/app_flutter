import 'package:flutter/material.dart';

import 'buttons/app_buttons.dart';
import 'motion/app_modal.dart';

/// Confirmación de una acción que el usuario debe ratificar.
///
/// [destructive] marca las que no se pueden deshacer (eliminar un recurso,
/// descartar cambios): el botón pasa al color de error y el foco inicial se
/// queda en «Cancelar», para que pulsar Enter sobre un diálogo recién abierto
/// no borre nada. Es el mismo criterio de los diálogos de borrado de GitHub y
/// de macOS.
Future<bool> showConfirmActionDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String cancelLabel,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final confirmed = await showAppDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: destructive ? const Icon(Icons.warning_amber_rounded) : null,
      title: Text(title),
      content: Text(message),
      actions: [
        TertiaryButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          autofocus: destructive,
          child: Text(cancelLabel),
        ),
        if (destructive)
          // Sin icono en el botón: el diálogo confirma tanto borrados como
          // abandonar un grupo o descartar cambios, y una papelera fija
          // mentiría en la mitad de los casos. El aviso de la cabecera y el
          // color de error bastan para marcar que no hay vuelta atrás.
          DangerButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          )
        else
          PrimaryButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
      ],
    ),
  );
  return confirmed ?? false;
}
