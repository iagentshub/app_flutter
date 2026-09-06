import 'package:flutter/material.dart';

/// Scroll horizontal con la barra siempre a la vista, para una tabla más
/// ancha que su contenedor.
///
/// En un móvil se descubre deslizando; con ratón no hay gesto —el puntero está
/// fuera de `dragDevices` a propósito, ver CLAUDE.md— y la tabla parecía
/// terminar donde termina la ventana: las columnas de servicio, acción y
/// mensaje de los logs no se veían nunca en escritorio. La barra es lo único
/// que dice que hay más, y por eso no se apaga.
class WideTable extends StatefulWidget {
  const WideTable({required this.child, super.key});

  final Widget child;

  @override
  State<WideTable> createState() => _WideTableState();
}

class _WideTableState extends State<WideTable> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _scroll,
      thumbVisibility: true,
      // En escritorio el comportamiento por defecto ya envuelve cada scrollable
      // en su propia barra; sin esto se pintaban dos, una encima de otra.
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          // La barra se pinta sobre el borde inferior del viewport; el carril
          // tiene que ser hueco o cruza la última fila.
          padding: const EdgeInsets.only(bottom: 12),
          child: widget.child,
        ),
      ),
    );
  }
}
