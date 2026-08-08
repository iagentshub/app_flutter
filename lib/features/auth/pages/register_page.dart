import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router/external_router.dart';
import '../../../app/router/router.dart';
import '../../../app/theme/fnc_colors.dart';
import '../../../app/theme/fnc_fonts.dart';
import '../../../core/network/api_error.dart';
import '../../../shared/i18n/locale_loader.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../utils/validators.dart';
import '../repositories/auth_repository.dart';

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

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _configLoaded = false;
  bool _registrationEnabled = false;
  bool _legalAccepted = false;
  String? _message;
  late Future<Map<String, dynamic>> _textsFuture;

  String get _languageCode => widget.localeController.languageCode;
  bool get _isEnglish => _languageCode == 'en';

  /// Las páginas legales las sirve React en la raíz del mismo origen, fuera de
  /// /app/, así que son navegación del navegador y no una ruta de GoRouter.
  /// Se abren en pestaña nueva a propósito: llevarse el formulario por delante
  /// a medio rellenar por leer los términos es la forma de que nadie los lea.
  Future<void> _openLegalDocument(String basePath) async {
    final path = _isEnglish ? '/en$basePath' : basePath;
    await launchUrl(
      resolvePublicSiteUri(path: path, useSameOrigin: kIsWeb),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  void initState() {
    super.initState();
    _textsFuture = LocaleLoader.load(languageCode: _languageCode, namespace: 'auth');
    widget.localeController.addListener(_onLocaleChanged);
    _loadPlatformSettings();
  }

  void _onLocaleChanged() {
    if (!mounted) return;
    setState(() {
      _textsFuture = LocaleLoader.load(
        languageCode: _languageCode,
        namespace: 'auth',
      );
    });
  }

  @override
  void dispose() {
    widget.localeController.removeListener(_onLocaleChanged);
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _txt(Map<String, dynamic> bundle, String path, String fallback) {
    return LocaleLoader.text(bundle, path, fallback: fallback);
  }

  Future<void> _submit(Map<String, dynamic> t) async {
    if (!_registrationEnabled) {
      setState(
        () => _message = _txt(
          t,
          'register.disabled_message',
          'Registro deshabilitado en este backend. Contacta con el administrador.',
        ),
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final ok = await widget.authRepository.register(
        username: _usernameController.text,
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      if (ok) {
        setState(
          () => _message = _txt(
            t,
            'register.success_message',
            'Registro correcto. Ya puedes iniciar sesión.',
          ),
        );
      }
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() => _message = error.message);
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
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: FutureBuilder<Map<String, dynamic>>(
                    future: _textsFuture,
                    builder: (context, snapshot) {
                      final t = snapshot.data ?? const {};
                      return Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _txt(t, 'register.title', 'Crear cuenta'),
                              style: const TextStyle(
                                fontSize: FncFonts.size24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_configLoaded && !_registrationEnabled) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: FncColors.overlayRedAccent20,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: FncColors.overlayRedAccent40,
                                  ),
                                ),
                                child: Text(
                                  _txt(
                                    t,
                                    'register.disabled_message',
                                    'Registro deshabilitado en este backend. Contacta con el administrador.',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            TextFormField(
                              controller: _usernameController,
                              validator: Validators.username,
                              enabled: _registrationEnabled,
                              autocorrect: false,
                              textCapitalization: TextCapitalization.none,
                              decoration: InputDecoration(
                                labelText: _txt(
                                  t,
                                  'register.username_label',
                                  'Usuario público *',
                                ),
                                helperText: _txt(
                                  t,
                                  'register.username_hint',
                                  '5–32 caracteres. No se podrá cambiar.',
                                ),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _emailController,
                              validator: Validators.email,
                              enabled: _registrationEnabled,
                              decoration: InputDecoration(
                                labelText: _txt(
                                  t,
                                  'register.email_label',
                                  'Email',
                                ),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              enabled: _registrationEnabled,
                              validator: (value) {
                                final requiredError = Validators.requiredField(
                                  value,
                                  message: _txt(
                                    t,
                                    'register.error_password_required',
                                    'La contraseña es obligatoria',
                                  ),
                                );
                                if (requiredError != null) return requiredError;
                                if ((value ?? '').trim().length < 8) {
                                  return _txt(
                                    t,
                                    'register.error_short_password',
                                    'La contraseña debe tener al menos 8 caracteres',
                                  );
                                }
                                return null;
                              },
                              decoration: InputDecoration(
                                labelText: _txt(
                                  t,
                                  'register.password_label',
                                  'Contraseña',
                                ),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            CheckboxListTile(
                              value: _legalAccepted,
                              onChanged: _registrationEnabled
                                  ? (value) => setState(
                                      () => _legalAccepted = value ?? false,
                                    )
                                  : null,
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: Text(
                                _txt(
                                  t,
                                  'register.accept_legal',
                                  'He leído y acepto los términos y la política de privacidad',
                                ),
                              ),
                            ),
                            Wrap(
                              spacing: 12,
                              children: [
                                TertiaryButton(
                                  onPressed: () => _openLegalDocument('/terms'),
                                  child: Text(
                                    _txt(
                                      t,
                                      'register.terms_link',
                                      'Términos y condiciones',
                                    ),
                                  ),
                                ),
                                TertiaryButton(
                                  onPressed: () =>
                                      _openLegalDocument('/privacy'),
                                  child: Text(
                                    _txt(
                                      t,
                                      'register.privacy_link',
                                      'Política de privacidad',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: PrimaryButton(
                                onPressed:
                                    (_loading ||
                                        !_registrationEnabled ||
                                        !_legalAccepted)
                                    ? null
                                    : () => _submit(t),
                                child: Text(
                                  _loading
                                      ? _txt(
                                          t,
                                          'register.submit_btn_loading',
                                          'Registrando...',
                                        )
                                      : _txt(
                                          t,
                                          'register.submit_btn',
                                          'Registrarme',
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TertiaryButton(
                              onPressed: () => AppRouter.toLogin(context),
                              child: Text(
                                _txt(
                                  t,
                                  'register.back_to_login',
                                  'Volver al login',
                                ),
                              ),
                            ),
                            if (_message != null) ...[
                              const SizedBox(height: 8),
                              Text(_message!),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
