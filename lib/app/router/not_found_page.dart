import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/buttons/app_buttons.dart';
import 'route_names.dart';

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Página no encontrada'),
              const SizedBox(height: 8),
              PrimaryButton(
                onPressed: () => context.go(RouteNames.login),
                child: const Text('Ir al inicio'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
