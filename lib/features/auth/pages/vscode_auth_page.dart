import 'package:flutter/material.dart';

class VsCodeAuthPage extends StatelessWidget {
  const VsCodeAuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Text('VS Code Auth', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        SizedBox(height: 12),
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Esta página actuará como puente de autorización para la extensión de VS Code. '
              'En la siguiente iteración conectaremos el intercambio de estado/callback.',
            ),
          ),
        ),
      ],
    );
  }
}
