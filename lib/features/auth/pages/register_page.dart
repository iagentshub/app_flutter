import 'package:flutter/material.dart';

import '../../../shared/widgets/buttons/app_buttons.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/network/api_error.dart';
import '../../../shared/i18n/locale_loader.dart';
import '../../../shared/state/locale_controller.dart';
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
  String? _message;
  late Future<Map<String, dynamic>> _textsFuture;

  bool get _isEnglish => widget.localeController.isEnglish;

  @override
  void initState() {
    super.initState();
    _textsFuture = LocaleLoader.load(isEnglish: _isEnglish, namespace: 'auth');
    widget.localeController.addListener(_onLocaleChanged);
    _loadPlatformSettings();
  }

  void _onLocaleChanged() {
    if (!mounted) return;
    setState(
      () => _textsFuture = LocaleLoader.load(
        isEnglish: _isEnglish,
        namespace: 'auth',
      ),
    );
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
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_configLoaded && !_registrationEnabled) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0x33D90429),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0x66D90429),
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
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: PrimaryButton(
                                onPressed: (_loading || !_registrationEnabled)
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
                              onPressed: () => context.go(RouteNames.login),
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
