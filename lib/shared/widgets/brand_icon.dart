import 'package:flutter/material.dart';

import '../state/brand_icon_controller.dart';

class BrandIconScope extends InheritedNotifier<BrandIconController> {
  const BrandIconScope({
    required BrandIconController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static BrandIconController watch(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<BrandIconScope>();
    assert(scope != null, 'No se encontró BrandIconScope en el árbol.');
    return scope!.notifier!;
  }
}

class BrandIcon extends StatelessWidget {
  const BrandIcon({this.size = 32, this.borderRadius = 7, super.key});

  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final controller = BrandIconScope.watch(context);
    return Semantics(
      label: 'iAgents',
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(
          controller.assetPath,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
