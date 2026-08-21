import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/router/router.dart';
import '../../../core/config/runtime_config.dart';
import '../../../core/network/api_error.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/app_services_scope.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../billing/widgets/payment_element.dart';

/// Checkout en dos pasos: primero dónde se factura, después el pago.
///
/// El país no es un dato administrativo que se pueda pedir al final: Stripe
/// calcula el IVA al crear la suscripción —`default_incomplete` ya emite el
/// borrador de factura— y sin ubicación responde `customer_tax_location_invalid`.
/// Por eso /subscribe no se llama hasta que el usuario declara su país, y el
/// desglose que devuelve es el que se enseña antes de cobrar.
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
  final TextEditingController _taxIdController = TextEditingController();

  int? _amountCents;
  int? _subtotalCents;
  int? _taxCents;
  int? _totalCents;
  String? _country;
  String? _clientSecret;
  String? _subscriptionId;
  String? _error;
  String? _localErrorKey;
  bool _loading = true;
  bool _starting = false;
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

  /// Con `client_secret` ya hay suscripción creada y factura con su impuesto:
  /// el paso de datos de facturación queda atrás.
  bool get _readyToPay => _clientSecret != null;

  String _tx(String path) => _t.text(path);

  String _money(int? cents) =>
      cents == null ? '—' : '${(cents / 100).toStringAsFixed(2)} €';

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
      _loadQuote();
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
    _taxIdController.dispose();
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

  Map<String, dynamic> get _planBody => {
    'tier': _tier,
    'seats': _seats,
    'interval': _interval,
    'self_hosted': _selfHosted,
  };

  /// Precio sin impuestos, para poder enseñar algo mientras se elige el país.
  /// El importe definitivo lo fija la factura, en `_startCheckout`.
  Future<void> _loadQuote() async {
    try {
      final quote = await _services.apiClient.post(
        '/api/billing/quote',
        body: _planBody,
      );
      if (!mounted) return;
      setState(() {
        _amountCents = quote.json['amount_cents'] as int?;
        _loading = false;
      });
    } on ApiError catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError(error.toString());
    }
  }

  Future<void> _startCheckout() async {
    final country = _country;
    if (country == null) return;
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final subscription = await _services.apiClient.post(
        '/api/billing/subscribe',
        body: {
          ..._planBody,
          'country': country,
          'tax_id': _taxIdController.text.trim(),
        },
      );
      if (!mounted) return;
      final json = subscription.json;
      setState(() {
        _clientSecret = json['client_secret'] as String?;
        _subscriptionId = json['subscription_id'] as String?;
        _subtotalCents = json['subtotal_cents'] as int?;
        _taxCents = json['tax_cents'] as int?;
        _totalCents = json['total_cents'] as int?;
        _starting = false;
      });
    } on ApiError catch (error) {
      _showError(error.message, starting: false);
    } catch (error) {
      _showError(error.toString(), starting: false);
    }
  }

  void _showError(String message, {bool? starting}) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _localErrorKey = null;
      _loading = false;
      if (starting != null) _starting = starting;
    });
  }

  /// Vuelve al paso de facturación. La suscripción creada se queda en Stripe
  /// como `incomplete` y caduca sola; crear otra con distinto país es lo que
  /// hace el backend al reintentar, y ahí sí choca con el 409 de suscripción
  /// activa solo si la primera llegó a pagarse.
  void _editBilling() {
    setState(() {
      _clientSecret = null;
      _subscriptionId = null;
      _subtotalCents = null;
      _taxCents = null;
      _totalCents = null;
      _error = null;
    });
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
        unsupportedMessage: _tx('checkout.integrated_web_only'),
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
    final localError = switch (_localErrorKey) {
      'checkout.web_only' => _tx('checkout.web_only'),
      'checkout.stripe_unavailable' => _tx('checkout.stripe_unavailable'),
      'checkout.invalid_plan' => _tx('checkout.invalid_plan'),
      _ => null,
    };
    final visibleError = _error ?? localError;
    return Scaffold(
      appBar: AppBar(
        title: Text(_tx('checkout.subscription_title')),
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
                      _tx('checkout.title'),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _tier == 'business'
                          ? '${_tx('checkout.plan_business')} · ${_tx('checkout.seats_many').replaceAll('{{count}}', '$_seats')}'
                          : '${_tx('checkout.plan_individual')} · ${_tx('checkout.seats_one')}',
                    ),
                    const SizedBox(height: 8),
                    ..._buildAmount(context),
                    const Divider(height: 32),
                    if (_loading)
                      const Center(child: CircularProgressIndicator())
                    else if (_success)
                      Text(_tx('checkout.success'))
                    else if (!_readyToPay)
                      ..._buildBillingStep(context)
                    else
                      ..._buildPaymentStep(context),
                    if (visibleError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        visibleError,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
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

  /// Antes de conocer el país solo se puede enseñar el precio sin impuestos, y
  /// hay que decir que lo es. Después, el desglose real de la factura.
  List<Widget> _buildAmount(BuildContext context) {
    final periodo = _tx(
      _interval == 'year'
          ? 'checkout.interval_year'
          : 'checkout.interval_month',
    );
    if (!_readyToPay) {
      return [
        Text('${_money(_amountCents)} $periodo'),
        Text(
          _tx('checkout.tax_pending'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ];
    }
    final estilo = Theme.of(context).textTheme.bodyMedium;
    final destacado = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold);
    return [
      _amountRow(_tx('checkout.subtotal_label'), _subtotalCents, estilo),
      _amountRow(_tx('checkout.tax_label'), _taxCents, estilo),
      const SizedBox(height: 4),
      _amountRow(
        '${_tx('checkout.total_label')} $periodo',
        _totalCents,
        destacado,
      ),
      // Un IVA de cero con NIF declarado es inversión del sujeto pasivo, no un
      // fallo de cálculo: sin decirlo parece que la factura salió mal.
      if (_taxCents == 0 && _taxIdController.text.trim().isNotEmpty)
        Text(
          _tx('checkout.tax_reverse_charge'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
    ];
  }

  Widget _amountRow(String label, int? cents, TextStyle? style) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(_money(cents), style: style),
      ],
    ),
  );

  List<Widget> _buildBillingStep(BuildContext context) {
    final paises = _t.map('checkout.countries');
    final codigos = paises.keys.toList()
      ..sort((a, b) => paises[a]!.compareTo(paises[b]!));
    return [
      Text(
        _tx('checkout.billing_step_title'),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 4),
      Text(
        _tx('checkout.billing_step_hint'),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        initialValue: _country,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: _tx('checkout.country_label'),
          border: const OutlineInputBorder(),
        ),
        hint: Text(_tx('checkout.country_placeholder')),
        items: [
          for (final codigo in codigos)
            DropdownMenuItem(value: codigo, child: Text(paises[codigo]!)),
        ],
        onChanged: _starting
            ? null
            : (valor) => setState(() {
                _country = valor;
                _error = null;
              }),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _taxIdController,
        enabled: !_starting,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(
          labelText: _tx('checkout.tax_id_label'),
          helperText: _tx('checkout.tax_id_hint'),
          helperMaxLines: 3,
          border: const OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 20),
      PrimaryButton(
        onPressed: _country == null || _starting ? null : _startCheckout,
        child: Text(
          _starting ? _tx('checkout.processing') : _tx('checkout.continue_btn'),
        ),
      ),
      if (_country == null) ...[
        const SizedBox(height: 8),
        Text(
          _tx('checkout.country_required'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ];
  }

  List<Widget> _buildPaymentStep(BuildContext context) => [
    SizedBox(
      height: 360,
      child: buildPaymentElement(
        _clientSecret!,
        unavailableMessage: _tx('checkout.web_version_only'),
      ),
    ),
    const SizedBox(height: 16),
    PrimaryButton(
      onPressed: _confirming ? null : _confirm,
      child: Text(
        _confirming
            ? _tx('checkout.processing')
            : _tx(
                'checkout.pay_btn',
              ).replaceAll('{{amount}}', _money(_totalCents)),
      ),
    ),
    const SizedBox(height: 8),
    TertiaryButton(
      onPressed: _confirming ? null : _editBilling,
      child: Text(_tx('checkout.edit_billing')),
    ),
  ];
}
