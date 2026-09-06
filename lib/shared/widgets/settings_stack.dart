import 'package:flutter/material.dart';

/// Apila los grupos de ajustes de arriba abajo, con 24 px entre ellos.
///
/// En web llegó a repartirlos en dos columnas a partir de 1000 px, y se
/// retiró a petición: con los grupos uno al lado del otro «Mi cuenta» se leía
/// en varios sitios a la vez. Una sola pila, en todas las plataformas.
class SettingsStack extends StatelessWidget {
  const SettingsStack({required this.sections, super.key});

  final List<List<Widget>> sections;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: 24),
          ...sections[i],
        ],
      ],
    );
  }
}
