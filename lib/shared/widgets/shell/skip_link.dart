import 'package:flutter/material.dart';

import '../buttons/app_buttons.dart';

/// Enlace de salto —«Saltar al contenido», «Ir al menú»— invisible hasta que
/// el foco cae en él.
///
/// Con teclado, Tab recorría el menú lateral entero —más de una docena de
/// paradas— antes de llegar a la página. Y al revés era peor: en la build
/// release web, Tab no sale nunca de la página, da vueltas entre sus
/// controles y el menú no se alcanza. En debug y en la VM sí sale; la
/// diferencia está en cómo ordena Flutter el ámbito de la ruta entre sus
/// propios hijos, y no se ha encontrado la causa. Por eso hay un enlace en
/// cada lado: el del shell lleva a la página, el de la página lleva al menú.
///
/// Va en la esquina superior izquierda de su zona porque el orden de lectura
/// es geométrico: lo que está más arriba y más a la izquierda es la primera
/// parada. El resto del tiempo no se pinta ni recibe el ratón, pero sigue en
/// la semántica: un lector de pantalla lo anuncia igual.
class SkipLink extends StatefulWidget {
  const SkipLink({required this.label, required this.target, super.key});

  final String label;

  /// Zona a la que lleva: al activarse, el foco va al primer control que hay
  /// dentro en orden de lectura, o al propio nodo si no hay ninguno.
  final FocusNode target;

  @override
  State<SkipLink> createState() => _SkipLinkState();
}

class _SkipLinkState extends State<SkipLink> {
  var _focused = false;

  void _jump() {
    final target = widget.target;
    // Un ámbito sabe a qué control volver, o se queda con el foco y el
    // siguiente Tab entra en él. El menú no es un ámbito a propósito —uno
    // propio atrapaba el foco entre menú y enlace en la build release—, así
    // que ahí se busca el primer control en orden de lectura. `sortDescendants`
    // está pensado para políticas propias, pero las alternativas públicas
    // trabajan sobre ámbitos, que es justo lo que no puede haber.
    if (target is FocusScopeNode) {
      target.requestFocus();
      return;
    }
    final policy = FocusTraversalGroup.of(context);
    // ignore: invalid_use_of_protected_member
    final controls = policy.sortDescendants(
      target.traversalDescendants,
      target,
    );
    (controls.firstOrNull ?? target).requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    // `skipTraversal`: el envoltorio no es una parada más; solo escucha si el
    // botón de dentro tiene el foco.
    return Focus(
      skipTraversal: true,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: IgnorePointer(
        ignoring: !_focused,
        child: Opacity(
          opacity: _focused ? 1 : 0,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: PrimaryButton(onPressed: _jump, child: Text(widget.label)),
          ),
        ),
      ),
    );
  }
}
