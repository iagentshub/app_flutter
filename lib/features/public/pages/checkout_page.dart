import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/config/runtime_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../billing/widgets/payment_element.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({
    required this.apiClient,
    required this.queryParameters,
    super.key,
  });

  final ApiClient apiClient;
  final Map<String, String> queryParameters;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  int? _amountCents;
  String? _clientSecret;
  String? _subscriptionId;
  String? _error;
  bool _loading = true;
  bool _confirming = false;
  bool _success = false;

  String get _tier => widget.queryParameters['tier'] ?? '';
  int get _seats => int.tryParse(widget.queryParameters['seats'] ?? '') ?? 0;
  String get _interval =>
      widget.queryParameters['interval'] == 'year' ? 'year' : 'month';
  bool get _selfHosted =>
      const {'1', 'true'}.contains(widget.queryParameters['selfHosted']);
  bool get _valid =>
      (_tier == 'developer' && _seats == 1) ||
      (_tier == 'business' && _seats >= 2 && _seats <= 100);

  @override
  void initState() {
    super.initState();
    final redirectedSubscription = widget.queryParameters['subscription_id'];
    if (widget.queryParameters['complete'] == '1' &&
        redirectedSubscription != null &&
        redirectedSubscription.isNotEmpty) {
      _completeRedirect(redirectedSubscription);
    } else if (!kIsWeb) {
      _loading = false;
      _error =
          'Abre www.iagentshub.com/app/checkout en el navegador para completar el pago.';
    } else if (stripePublishableKey.isEmpty) {
      _loading = false;
      _error = 'Stripe no está configurado en este servidor.';
    } else if (_valid) {
      _startCheckout();
    } else {
      _loading = false;
      _error = 'El plan seleccionado no es válido.';
    }
  }

  Future<void> _completeRedirect(String subscriptionId) async {
    try {
      await widget.apiClient.post(
        '/api/billing/confirm',
        body: {'subscription_id': subscriptionId},
      );
      if (!mounted) return;
      setState(() {
        _success = true;
        _loading = false;
      });
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (mounted) context.go('${RouteNames.profile}?section=billing');
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Map<String, dynamic> get _requestBody => {
    'tier': _tier,
    'seats': _seats,
    'interval': _interval,
    'self_hosted': _selfHosted,
  };

  Future<void> _startCheckout() async {
    try {
      final quote = await widget.apiClient.post(
        '/api/billing/quote',
        body: _requestBody,
      );
      final subscription = await widget.apiClient.post(
        '/api/billing/subscribe',
        body: _requestBody,
      );
      if (!mounted) return;
      setState(() {
        _amountCents = quote.json['amount_cents'] as int?;
        _clientSecret = subscription.json['client_secret'] as String?;
        _subscriptionId = subscription.json['subscription_id'] as String?;
        _loading = false;
      });
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _confirm() async {
    final subscriptionId = _subscriptionId;
    if (subscriptionId == null) return;
    setState(() {
      _confirming = true;
      _error = null;
    });
    try {
      final returnUrl = Uri.base
          .replace(
            queryParameters: {
              ...widget.queryParameters,
              'complete': '1',
              'subscription_id': subscriptionId,
            },
          )
          .toString();
      await confirmPaymentElement(returnUrl);
      await widget.apiClient.post(
        '/api/billing/confirm',
        body: {'subscription_id': subscriptionId},
      );
      if (!mounted) return;
      setState(() {
        _success = true;
        _confirming = false;
      });
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (mounted) context.go('${RouteNames.profile}?section=billing');
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _confirming = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _confirming = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = _amountCents == null
        ? '—'
        : '${(_amountCents! / 100).toStringAsFixed(2)} €';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suscripción'),
        leading: BackButton(onPressed: () => context.go(RouteNames.profile)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Completa tu suscripción',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _tier == 'business'
                          ? 'Business · $_seats licencias'
                          : 'Individual · 1 licencia',
                    ),
                    Text('$amount / ${_interval == 'year' ? 'año' : 'mes'}'),
                    const Divider(height: 32),
                    if (_loading)
                      const Center(child: CircularProgressIndicator())
                    else if (_success)
                      const Text('Pago confirmado. Abriendo tu facturación…')
                    else ...[
                      if (_clientSecret != null)
                        SizedBox(
                          height: 360,
                          child: buildPaymentElement(_clientSecret!),
                        ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      PrimaryButton(
                        onPressed: _clientSecret == null || _confirming
                            ? null
                            : _confirm,
                        child: Text(
                          _confirming ? 'Procesando…' : 'Pagar $amount',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
