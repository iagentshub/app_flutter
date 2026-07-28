import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../shared/widgets/public_page.dart';

class CheckoutPage extends StatelessWidget {
  const CheckoutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PublicPage(
      title: 'Checkout',
      description:
          'Flujo de suscripción y confirmación de plan. Aquí conectaremos billing en la siguiente iteración.',
      actions: [
        FilledButton(
          onPressed: () => context.go(RouteNames.pricing),
          child: const Text('Volver a precios'),
        ),
        OutlinedButton(
          onPressed: () => context.go(RouteNames.login),
          child: const Text('Ir al login'),
        ),
      ],
    );
  }
}
