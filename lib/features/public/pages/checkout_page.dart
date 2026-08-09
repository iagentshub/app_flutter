import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/router/router.dart';
import '../../../core/config/runtime_config.dart';
import '../../../core/network/api_error.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/app_services_scope.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../billing/widgets/payment_element.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({required this.queryParameters, super.key});

  final Map<String, String> queryParameters;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  /// Servicios globales (cliente HTTP, sesión, idioma): los aporta el
  /// AppServicesScope montado en App, no el router.
  late final _services = AppServicesScope.of(context);
  late final TranslatedTexts _t;

  int? _amountCents;
  String? _clientSecret;
  String? _subscriptionId;
  String? _error;
  String? _localErrorKey;
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

  String _tx(String path, String fallback) => _t.text(path, fallback: fallback);

  @override
  void initState() {
    super.initState();
    _t = TranslatedTexts(
      localeController: _services.localeController,
      namespace: 'pricing',
    )..addListener(_onTextsChanged);
    final redirectedSubscription = widget.queryParameters['subscription_id'];
    if (widget.queryParameters['complete'] == '1' &&
        redirectedSubscription != null &&
        redirectedSubscription.isNotEmpty) {
      _completeRedirect(redirectedSubscription);
    } else if (!kIsWeb) {
      _loading = false;
      _localErrorKey = 'checkout.web_only';
    } else if (stripePublishableKey.isEmpty) {
      _loading = false;
      _localErrorKey = 'checkout.stripe_unavailable';
    } else if (_valid) {
      _startCheckout();
    } else {
      _loading = false;
      _localErrorKey = 'checkout.invalid_plan';
    }
  }

  void _onTextsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _t.removeListener(_onTextsChanged);
    _t.dispose();
    super.dispose();
  }

  Future<void> _completeRedirect(String subscriptionId) async {
    try {
      await _services.apiClient.post(
        '/api/billing/confirm',
        body: {'subscription_id': subscriptionId},
      );
      if (!mounted) return;
      setState(() {
        _success = true;
        _loading = false;
      });
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (mounted) AppRouter.toProfileBilling(context);
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _localErrorKey = null;
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
      final quote = await _services.apiClient.post(
        '/api/billing/quote',
        body: _requestBody,
      );
      final subscription = await _services.apiClient.post(
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
        _localErrorKey = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _localErrorKey = null;
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
      await confirmPaymentElement(
        returnUrl,
        unsupportedMessage: _tx(
          'checkout.integrated_web_only',
          'El pago integrado solo está disponible en la web.',
        ),
      );
      await _services.apiClient.post(
        '/api/billing/confirm',
        body: {'subscription_id': subscriptionId},
      );
      if (!mounted) return;
      setState(() {
        _success = true;
        _confirming = false;
      });
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (mounted) AppRouter.toProfileBilling(context);
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _localErrorKey = null;
        _confirming = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _localErrorKey = null;
        _confirming = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = _amountCents == null
        ? '—'
        : '${(_amountCents! / 100).toStringAsFixed(2)} €';
    final localError = switch (_localErrorKey) {
      'checkout.web_only' => _tx(
        'checkout.web_only',
        'Abre www.iagentshub.com/app/checkout en el navegador para completar el pago.',
      ),
      'checkout.stripe_unavailable' => _tx(
        'checkout.stripe_unavailable',
        'Stripe no está configurado en este servidor.',
      ),
      'checkout.invalid_plan' => _tx(
        'checkout.invalid_plan',
        'El plan seleccionado no es válido.',
      ),
      _ => null,
    };
    final visibleError = _error ?? localError;
    return Scaffold(
      appBar: AppBar(
        title: Text(_tx('checkout.subscription_title', 'Suscripción')),
        leading: BackButton(onPressed: () => AppRouter.toProfile(context)),
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
                      _tx('checkout.title', 'Completa tu suscripción'),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _tier == 'business'
                          ? '${_tx('checkout.plan_business', 'Business')} · ${_tx('checkout.seats_many', '{{count}} licencias').replaceAll('{{count}}', '$_seats')}'
                          : '${_tx('checkout.plan_individual', 'Individual')} · ${_tx('checkout.seats_one', '1 licencia')}',
                    ),
                    Text(
                      '$amount ${_tx(_interval == 'year' ? 'checkout.interval_year' : 'checkout.interval_month', _interval == 'year' ? '/ año' : '/ mes')}',
                    ),
                    const Divider(height: 32),
                    if (_loading)
                      const Center(child: CircularProgressIndicator())
                    else if (_success)
                      Text(
                        _tx(
                          'checkout.success',
                          'Pago confirmado. Abriendo tu facturación…',
                        ),
                      )
                    else ...[
                      if (_clientSecret != null)
                        SizedBox(
                          height: 360,
                          child: buildPaymentElement(
                            _clientSecret!,
                            unavailableMessage: _tx(
                              'checkout.web_version_only',
                              'Completa la suscripción desde la versión web de iAgents Hub.',
                            ),
                          ),
                        ),
                      if (visibleError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          visibleError,
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
                          _confirming
                              ? _tx('checkout.processing', 'Procesando…')
                              : _tx(
                                  'checkout.subscribe_btn',
                                  'Pagar {{amount}}',
                                ).replaceAll('{{amount}}', amount),
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
