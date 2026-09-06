import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_buttons.dart';

/// En web la acción principal tiene nombre; móvil conserva el botón actual.
class ResourceCreateButton extends StatelessWidget {
  const ResourceCreateButton({
    required this.onPressed,
    required this.label,
    this.icon = Icons.add,
    super.key,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => kIsWeb
      ? PrimaryButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
        )
      : AppIconButton.filled(
          onPressed: onPressed,
          icon: Icon(icon),
          tooltip: label,
        );
}
