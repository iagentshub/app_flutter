import 'package:flutter/material.dart';
import 'package:flutter_stripe_web/flutter_stripe_web.dart';

Widget buildPaymentElement(String clientSecret) => PaymentElement(
  autofocus: true,
  enablePostalCode: true,
  onCardChanged: (_) {},
  clientSecret: clientSecret,
);

Future<void> confirmPaymentElement(String returnUrl) {
  return WebStripe.instance.confirmPaymentElement(
    ConfirmPaymentElementOptions(
      confirmParams: ConfirmPaymentParams(return_url: returnUrl),
      redirect: PaymentConfirmationRedirect.ifRequired,
    ),
  );
}
