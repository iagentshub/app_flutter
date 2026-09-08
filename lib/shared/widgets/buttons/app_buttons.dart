import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../motion/app_motion.dart';

/// Acción principal de una vista o bloque.
///
/// Centraliza el uso de [FilledButton] para que las páginas expresen la
/// jerarquía de la acción y no dependan directamente del widget Material.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.onPressed,
    required Widget this._child,
    this.style,
    this.busy = false,
    this.busyLabel,
    super.key,
  }) : _icon = null,
       _label = null,
       _variant = _PrimaryButtonVariant.filled;

  const PrimaryButton.icon({
    required this.onPressed,
    required Widget this._icon,
    required Widget this._label,
    this.style,
    this.busy = false,
    this.busyLabel,
    super.key,
  }) : _child = null,
       _variant = _PrimaryButtonVariant.filled;

  const PrimaryButton.elevated({
    required this.onPressed,
    required Widget this._child,
    this.style,
    this.busy = false,
    this.busyLabel,
    super.key,
  }) : _icon = null,
       _label = null,
       _variant = _PrimaryButtonVariant.elevated;

  const PrimaryButton.tonalIcon({
    required this.onPressed,
    required Widget this._icon,
    required Widget this._label,
    this.style,
    this.busy = false,
    this.busyLabel,
    super.key,
  }) : _child = null,
       _variant = _PrimaryButtonVariant.tonalIcon;

  final VoidCallback? onPressed;
  final ButtonStyle? style;
  final bool busy;
  final String? busyLabel;
  final Widget? _child;
  final Widget? _icon;
  final Widget? _label;
  final _PrimaryButtonVariant _variant;

  @override
  Widget build(BuildContext context) {
    final callback = busy ? null : onPressed;
    final content = _icon == null
        ? _child!
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _icon,
              const SizedBox(width: 8),
              Flexible(child: _label!),
            ],
          );
    final child = Semantics(
      liveRegion: busy,
      label: busy ? busyLabel : null,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: busy ? 0 : 1,
            alwaysIncludeSemantics: busyLabel == null,
            child: content,
          ),
          if (busy)
            SizedBox.square(
              dimension: 18,
              child: AppMotion.reduced(context)
                  ? const Icon(Icons.hourglass_top, size: 18)
                  : const CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
    return switch (_variant) {
      _PrimaryButtonVariant.elevated => ElevatedButton(
        onPressed: callback,
        style: style,
        child: child,
      ),
      _PrimaryButtonVariant.tonalIcon => FilledButton.tonal(
        onPressed: callback,
        style: style,
        child: child,
      ),
      _PrimaryButtonVariant.filled => FilledButton(
        onPressed: callback,
        style: style,
        child: child,
      ),
    };
  }
}

enum _PrimaryButtonVariant { filled, elevated, tonalIcon }

/// Acción secundaria que acompaña a una acción principal.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    required this.onPressed,
    required Widget this._child,
    this.style,
    super.key,
  }) : _icon = null,
       _label = null;

  const SecondaryButton.icon({
    required this.onPressed,
    required Widget this._icon,
    required Widget this._label,
    this.style,
    super.key,
  }) : _child = null;

  final VoidCallback? onPressed;
  final ButtonStyle? style;
  final Widget? _child;
  final Widget? _icon;
  final Widget? _label;

  @override
  Widget build(BuildContext context) {
    final icon = _icon;
    if (icon != null) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        style: style,
        icon: icon,
        label: _label!,
      );
    }
    return OutlinedButton(onPressed: onPressed, style: style, child: _child!);
  }
}

/// Acción de baja prominencia, adecuada para cancelar o navegar.
class TertiaryButton extends StatelessWidget {
  const TertiaryButton({
    required this.onPressed,
    required Widget this._child,
    this.style,
    this.autofocus = false,
    super.key,
  }) : _icon = null,
       _label = null;

  const TertiaryButton.icon({
    required this.onPressed,
    required Widget this._icon,
    required Widget this._label,
    this.style,
    this.autofocus = false,
    super.key,
  }) : _child = null;

  final VoidCallback? onPressed;
  final ButtonStyle? style;

  /// Recibe el foco al abrirse la vista. Lo usan los diálogos destructivos
  /// para que Enter cancele en vez de confirmar.
  final bool autofocus;
  final Widget? _child;
  final Widget? _icon;
  final Widget? _label;

  @override
  Widget build(BuildContext context) {
    final icon = _icon;
    if (icon != null) {
      return TextButton.icon(
        onPressed: onPressed,
        style: style,
        autofocus: autofocus,
        icon: icon,
        label: _label!,
      );
    }
    return TextButton(
      onPressed: onPressed,
      style: style,
      autofocus: autofocus,
      child: _child!,
    );
  }
}

/// Acción irreversible: eliminar un recurso, descartar cambios sin guardar.
///
/// La app ya tenía el concepto —`ActionIconButton` expone `danger: true` y
/// pinta el icono en rojo—, pero el diálogo que remataba la acción usaba el
/// mismo [PrimaryButton] con el color de marca que «Guardar» o «Continuar»:
/// nada distinguía visualmente confirmar de destruir.
class DangerButton extends StatelessWidget {
  const DangerButton({
    required this.onPressed,
    required Widget this._child,
    this.style,
    super.key,
  }) : _icon = null,
       _label = null;

  const DangerButton.icon({
    required this.onPressed,
    required Widget this._icon,
    required Widget this._label,
    this.style,
    super.key,
  }) : _child = null;

  final VoidCallback? onPressed;
  final ButtonStyle? style;
  final Widget? _child;
  final Widget? _icon;
  final Widget? _label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dangerStyle = FilledButton.styleFrom(
      backgroundColor: scheme.error,
      foregroundColor: scheme.onError,
    ).merge(style);

    final icon = _icon;
    if (icon != null) {
      return FilledButton.icon(
        onPressed: onPressed,
        style: dangerStyle,
        icon: icon,
        label: _label!,
      );
    }
    return FilledButton(
      onPressed: onPressed,
      style: dangerStyle,
      child: _child!,
    );
  }
}

/// Acción compacta basada únicamente en un icono.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.style,
    this.visualDensity,
    this.isSelected,
    this.selectedIcon,
    super.key,
  }) : _variant = _IconButtonVariant.standard;

  const AppIconButton.filled({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.style,
    this.visualDensity,
    this.isSelected,
    this.selectedIcon,
    super.key,
  }) : _variant = _IconButtonVariant.filled;

  const AppIconButton.filledTonal({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.style,
    this.visualDensity,
    this.isSelected,
    this.selectedIcon,
    super.key,
  }) : _variant = _IconButtonVariant.filledTonal;

  const AppIconButton.outlined({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.style,
    this.visualDensity,
    this.isSelected,
    this.selectedIcon,
    super.key,
  }) : _variant = _IconButtonVariant.outlined;

  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final ButtonStyle? style;
  final VisualDensity? visualDensity;
  final bool? isSelected;
  final Widget? selectedIcon;
  final _IconButtonVariant _variant;

  @override
  Widget build(BuildContext context) {
    return switch (_variant) {
      _IconButtonVariant.standard => IconButton(
        icon: icon,
        onPressed: onPressed,
        tooltip: tooltip,
        style: style,
        visualDensity: visualDensity,
        isSelected: isSelected,
        selectedIcon: selectedIcon,
      ),
      _IconButtonVariant.filled => IconButton.filled(
        icon: icon,
        onPressed: onPressed,
        tooltip: tooltip,
        style: style,
        visualDensity: visualDensity,
        isSelected: isSelected,
        selectedIcon: selectedIcon,
      ),
      _IconButtonVariant.filledTonal => IconButton.filledTonal(
        icon: icon,
        onPressed: onPressed,
        tooltip: tooltip,
        style: style,
        visualDensity: visualDensity,
        isSelected: isSelected,
        selectedIcon: selectedIcon,
      ),
      _IconButtonVariant.outlined => IconButton.outlined(
        icon: icon,
        onPressed: onPressed,
        tooltip: tooltip,
        style: kIsWeb
            ? ButtonStyle(
                side: WidgetStateProperty.resolveWith(
                  (states) => BorderSide(
                    color: states.contains(WidgetState.focused)
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                    width: 2,
                  ),
                ),
              ).merge(style)
            : style,
        visualDensity: visualDensity,
        isSelected: isSelected,
        selectedIcon: selectedIcon,
      ),
    };
  }
}

enum _IconButtonVariant { standard, filled, filledTonal, outlined }
