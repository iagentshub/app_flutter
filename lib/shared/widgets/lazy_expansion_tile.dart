import 'package:flutter/material.dart';

/// `ExpansionTile` que no construye su contenido hasta que se abre.
///
/// El de Material construye los hijos siempre y se limita a ocultarlos, así
/// que una pantalla con muchos grupos colapsados paga por adelantado todo lo
/// que no está enseñando. Donde cada grupo trae decenas de filas con
/// desplegables o checkboxes —revisión de una importación oficial, árbol de
/// tests de Centinel— la diferencia es el primer pintado entero.
class LazyExpansionTile extends StatefulWidget {
  const LazyExpansionTile({
    required this.title,
    required this.childrenBuilder,
    this.trailing,
    this.initiallyExpanded = false,
    this.tilePadding,
    this.childrenPadding,
    super.key,
  });

  final Widget title;
  final Widget? trailing;

  /// Solo se invoca cuando el grupo está abierto.
  final List<Widget> Function() childrenBuilder;

  final bool initiallyExpanded;
  final EdgeInsetsGeometry? tilePadding;
  final EdgeInsetsGeometry? childrenPadding;

  @override
  State<LazyExpansionTile> createState() => _LazyExpansionTileState();
}

class _LazyExpansionTileState extends State<LazyExpansionTile> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: widget.title,
      trailing: widget.trailing,
      initiallyExpanded: widget.initiallyExpanded,
      tilePadding: widget.tilePadding,
      childrenPadding: widget.childrenPadding,
      onExpansionChanged: (value) => setState(() => _expanded = value),
      children: _expanded ? widget.childrenBuilder() : const [],
    );
  }
}
