import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router/external_router.dart';
import '../../../app/router/router.dart';
import '../../../app/theme/fnc_colors.dart';
import '../../../app/theme/fnc_fonts.dart';
import '../../../core/network/api_error.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/widgets/animated_iagents_mark.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/state_messaging_mixin.dart';
import '../../../utils/validators.dart';
import '../repositories/auth_repository.dart';

part '../widgets/register_chrome.dart';
part '../widgets/register_field.dart';
part '../widgets/register_form.dart';

// Medidas del sistema público (`react.css` y `components.css` de
// frontend_react). Lo que no es color ni tipografía vive aquí porque solo lo
// usa esta pantalla; el color está en FncColors y la fuente en FncFonts.
const double _radioControl = 8; // --public-radius-control
const double _radioPanel = 16; // --public-radius-panel
const double _altoControl = 44; // .public-field-control { min-height }
const double _medida = 1200; // --measure
const double _calle = 24; // --gutter
const double _altoCabecera = 60; // .landing-header { height }
const double _anchoTarjeta = 480;
const double _anchoCopy = 520;

/// Punto en el que la landing pliega el hero a una columna y esconde el menú:
/// `@media (max-width: 900px)` en `landing.css`.
const double _corteAncho = 900;

TextStyle _texto(
  double tamano,
  double peso, {
  Color? color,
  double? alto,
  double? espaciado,
}) => TextStyle(
  fontFamily: FncFonts.geist,
  fontSize: tamano,
  fontVariations: FncFonts.wght(peso),
  color: color,
  height: alto,
  letterSpacing: espaciado,
);

TextStyle _mono(
  double tamano,
  double peso, {
  Color? color,
  double? espaciado,
}) => TextStyle(
  fontFamily: FncFonts.geistMono,
  fontSize: tamano,
  fontVariations: FncFonts.wght(peso),
  color: color,
  letterSpacing: espaciado,
);

OutlineInputBorder _borde(Color color) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(_radioControl),
  borderSide: BorderSide(color: color),
);

class RegisterPage extends StatefulWidget {
  const RegisterPage({
    required this.authRepository,
    required this.localeController,
    super.key,
  });

  final AuthRepository authRepository;
  final LocaleController localeController;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> with StateMessaging {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final TapGestureRecognizer _tocarTerminos;
  late final TapGestureRecognizer _tocarPrivacidad;
  late final TapGestureRecognizer _tocarInicio;
  bool _loading = false;
  bool _configLoaded = false;
  bool _registrationEnabled = false;
  bool _legalAccepted = false;
  bool _showPassword = false;
  String? _message;
  bool _messageIsError = true;
  late final TranslatedTexts _t;

  String get _languageCode => widget.localeController.languageCode;

  /// El idioma al que lleva el botón: el siguiente del catálogo, en círculo.
  /// La web abre un menú con los dos; aquí se cicla, como ya hace el login.
  String get _siguienteIdioma {
    const idiomas = LocaleController.supportedLanguageCodes;
    final actual = idiomas.indexOf(_languageCode);
    return idiomas[(actual + 1) % idiomas.length];
  }

  /// Las páginas del sitio las sirve React en la raíz del mismo origen, fuera
  /// de /app/, así que son navegación del navegador y no rutas de GoRouter.
  /// Se abren en pestaña nueva a propósito: llevarse el formulario por delante
  /// a medio rellenar por leer los términos es la forma de que nadie los lea.
  Future<void> _abrirPaginaPublica(String basePath) async {
    // El sitio público sirve el idioma base en la raíz y los demás bajo su
    // código (`/en/privacy`). Derivarlo del código en vez de preguntar «¿es
    // inglés?» es lo que hace que un tercer idioma funcione sin volver aquí.
    final esBase = _languageCode == LocaleController.fallbackLanguageCode;
    final path = esBase
        ? basePath
        : (basePath == '/' ? '/$_languageCode' : '/$_languageCode$basePath');
    await launchUrl(
      resolvePublicSiteUri(path: path, useSameOrigin: kIsWeb),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  void initState() {
    super.initState();
    _t = TranslatedTexts(
      localeController: widget.localeController,
      namespace: 'auth',
    )..addListener(_onTextsChanged);
    _tocarTerminos = TapGestureRecognizer()
      ..onTap = () => _abrirPaginaPublica('/terms');
    _tocarPrivacidad = TapGestureRecognizer()
      ..onTap = () => _abrirPaginaPublica('/privacy');
    _tocarInicio = TapGestureRecognizer()
      ..onTap = () => _abrirPaginaPublica('/');
    _loadPlatformSettings();
  }

  void _onTextsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _t.removeListener(_onTextsChanged);
    _t.dispose();
    _tocarTerminos.dispose();
    _tocarPrivacidad.dispose();
    _tocarInicio.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _tx(String path) => _t.text(path);

  Future<void> _submit() async {
    if (!_registrationEnabled) {
      setState(() {
        _messageIsError = true;
        _message = _tx('register.disabled_message');
      });
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final resultado = await widget.authRepository.register(
        username: _usernameController.text,
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      if (resultado['ok'] != true) return;
      // Con EMAIL_VERIFY_ENABLED el backend no abre sesión: decir «ya puedes
      // iniciar sesión» mandaba al usuario a un login que iba a rechazarle.
      final pendiente = resultado['pending_verification'] == true;
      final email = (resultado['email'] ?? _emailController.text.trim())
          .toString();
      setState(() {
        _messageIsError = false;
        _message = pendiente
            ? _tx('register.pending_verification').replaceAll('{email}', email)
            : _tx('register.success_message');
      });
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _messageIsError = true;
        _message = error.message;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadPlatformSettings() async {
    try {
      final platform = await widget.authRepository.platformPublic();
      if (!mounted) return;
      final registration = (platform['registration'] ?? '').toString();
      final billingEnabled = platform['billing_enabled'] == true;
      setState(() {
        _configLoaded = true;
        _registrationEnabled = registration == 'open' && !billingEnabled;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _configLoaded = true;
        _registrationEnabled = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pantalla oscura siempre, no según el ThemeController: es la costura con
    // el sitio público, que no tiene tema claro. Ver FncColors sección 9.
    return Scaffold(
      backgroundColor: FncColors.publicCanvas,
      body: Stack(
        children: [
          const Positioned.fill(child: _Resplandor()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Estricto, como `max-width: 900px`: a 900 exactos el CSS ya
                // ha plegado el hero y escondido el menú.
                final amplio = constraints.maxWidth > _corteAncho;
                return Column(
                  children: [
                    _cabecera(ancho: constraints.maxWidth, amplio: amplio),
                    Expanded(
                      child: SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: math.max(
                              0,
                              constraints.maxHeight - _altoCabecera,
                            ),
                          ),
                          child: Center(
                            child: amplio ? _cuerpoAmplio() : _cuerpoCompacto(),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Dos columnas: la rejilla del hero de la landing, con el formulario donde
  /// la landing pone el panel de producto.
  Widget _cuerpoAmplio() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _calle, vertical: 48),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _medida - _calle * 2),
        child: Row(
          children: [
            Expanded(
              flex: 94,
              child: Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _anchoCopy),
                  child: _columnaCopy(compacto: false),
                ),
              ),
            ),
            const SizedBox(width: 88),
            Expanded(
              flex: 106,
              child: Align(
                alignment: Alignment.centerRight,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _anchoTarjeta),
                  child: _tarjeta(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Una columna. El párrafo de marketing desaparece: por debajo de 900 el
  /// formulario es lo que se ha venido a hacer, y empujarlo media pantalla
  /// hacia abajo era el motivo de que el móvil se viera mal.
  Widget _cuerpoCompacto() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_calle, 20, _calle, 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _anchoCopy),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _columnaCopy(compacto: true),
            const SizedBox(height: 20),
            _tarjeta(),
          ],
        ),
      ),
    );
  }
}
