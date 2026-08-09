import 'package:flutter/material.dart';

Widget buildPaymentElement(
  String clientSecret, {
  required String unavailableMessage,
}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 16),
  child: Text(unavailableMessage),
);

Future<void> confirmPaymentElement(
  String returnUrl, {
  required String unsupportedMessage,
}) {
  throw UnsupportedError(unsupportedMessage);
}
