import 'package:flutter/material.dart';

Widget buildPaymentElement(String clientSecret) => const Padding(
  padding: EdgeInsets.symmetric(vertical: 16),
  child: Text('Completa la suscripción desde la versión web de iAgentsHub.'),
);

Future<void> confirmPaymentElement(String returnUrl) {
  throw UnsupportedError('El pago integrado solo está disponible en la web.');
}
