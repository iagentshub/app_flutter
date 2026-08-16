import 'package:flutter/material.dart';

import 'responsive_masonry_grid.dart';

/// Rejilla de tarjetas dentro de un scroll de slivers, con su margen habitual.
///
/// Vive aparte de [ResourceCollectionView] porque hay vistas —conexiones
/// agrupadas por proveedor, Explorar con packs y recursos— que pintan varias
/// colecciones en un mismo scroll y solo necesitan esta pieza.
class ResourceGridSliver extends StatelessWidget {
  const ResourceGridSliver({
    required this.itemCount,
    required this.itemBuilder,
    this.density = ResponsiveCardDensity.detailed,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 16),
    super.key,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ResponsiveCardDensity density;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: padding,
      sliver: ResponsiveSliverMasonryGrid(
        itemCount: itemCount,
        itemBuilder: itemBuilder,
        density: density,
      ),
    );
  }
}

/// Listado de recursos: barra, rejilla perezosa, estado vacío y carga por
/// páginas al acercarse al final.
///
/// Era el mismo esqueleto copiado en diez pantallas —`RefreshIndicator` sobre
/// un `CustomScrollView` con la barra en un sliver, la rejilla en otro y una
/// tarjeta para el caso vacío— con pequeñas divergencias entre copias: unas
/// dejaban de poderse refrescar al quedarse vacías, y solo Knowledge sabía
/// pedir la página siguiente. Al compartirlo, cualquier pantalla que reciba
/// [onLoadMore] hereda la paginación.
class ResourceCollectionView extends StatelessWidget {
  const ResourceCollectionView({
    required this.itemCount,
    required this.itemBuilder,
    this.header,
    this.onRefresh,
    this.empty,
    this.emptyFillsViewport = false,
    this.leadingSlivers = const [],
    this.trailingSlivers = const [],
    this.onLoadMore,
    this.hasMore = false,
    this.loadingMore = false,
    this.density = ResponsiveCardDensity.detailed,
    this.headerPadding = const EdgeInsets.fromLTRB(16, 16, 16, 12),
    this.gridPadding = const EdgeInsets.fromLTRB(16, 0, 16, 16),
    this.scrollController,
    super.key,
  });

  /// Barra de acciones o cabecera de la vista. Sin ella la rejilla empieza
  /// arriba del todo.
  final Widget? header;

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  /// Qué enseñar cuando no hay ningún elemento. Sin esto no se pinta nada.
  final Widget? empty;

  /// Centra [empty] en lo que queda de viewport en vez de dejarlo pegado bajo
  /// la cabecera. Las dos formas ya convivían entre pantallas.
  final bool emptyFillsViewport;

  /// Slivers propios de la pantalla, antes y después de la rejilla.
  final List<Widget> leadingSlivers;
  final List<Widget> trailingSlivers;

  final Future<void> Function()? onRefresh;

  /// Se invoca al acercarse al final mientras [hasMore] siga siendo cierto.
  /// Debe protegerse de llamadas repetidas: el scroll notifica muchas veces.
  final Future<void> Function()? onLoadMore;
  final bool hasMore;
  final bool loadingMore;

  final ResponsiveCardDensity density;
  final EdgeInsetsGeometry headerPadding;
  final EdgeInsetsGeometry gridPadding;
  final ScrollController? scrollController;

  /// Distancia al final a partir de la cual se pide la página siguiente.
  static const _loadMoreThreshold = 500.0;

  @override
  Widget build(BuildContext context) {
    final scroll = CustomScrollView(
      controller: scrollController,
      // Sin esto, una colección vacía o corta no se puede tirar hacia abajo y
      // el usuario se queda sin manera de reintentar.
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (header != null)
          SliverPadding(
            padding: headerPadding,
            sliver: SliverToBoxAdapter(child: header),
          ),
        ...leadingSlivers,
        if (itemCount == 0)
          if (empty == null)
            const SliverToBoxAdapter(child: SizedBox.shrink())
          else if (emptyFillsViewport)
            SliverFillRemaining(hasScrollBody: false, child: empty)
          else
            SliverPadding(
              padding: gridPadding,
              sliver: SliverToBoxAdapter(child: empty),
            )
        else
          ResourceGridSliver(
            itemCount: itemCount,
            itemBuilder: itemBuilder,
            density: density,
            padding: gridPadding,
          ),
        ...trailingSlivers,
        if (loadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );

    final listener = onLoadMore == null
        ? scroll
        : NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (hasMore &&
                  notification.metrics.extentAfter < _loadMoreThreshold) {
                onLoadMore!();
              }
              return false;
            },
            child: scroll,
          );

    if (onRefresh == null) return listener;
    return RefreshIndicator(onRefresh: onRefresh!, child: listener);
  }
}
