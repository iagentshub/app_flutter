import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/network/api_error.dart';
import '../../../utils/validators.dart';
import '../repositories/auth_repository.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({required this.authRepository, super.key});

  final AuthRepository authRepository;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _configLoaded = false;
  bool _registrationEnabled = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadPlatformSettings();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_registrationEnabled) {
      setState(
        () => _message = 'El registro no está habilitado en este backend.',
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
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      if (ok) {
        setState(
          () => _message = 'Registro correcto. Ya puedes iniciar sesión.',
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
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Crear cuenta',
                          style: TextStyle(
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
                            child: const Text(
                              'Registro deshabilitado en este backend. Contacta con el administrador.',
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          controller: _emailController,
                          validator: Validators.email,
                          enabled: _registrationEnabled,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
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
                              message: 'La contraseña es obligatoria',
                            );
                            if (requiredError != null) return requiredError;
                            if ((value ?? '').trim().length < 8)
                              return 'La contraseña debe tener al menos 8 caracteres';
                            return null;
                          },
                          decoration: const InputDecoration(
                            labelText: 'Contraseña',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: (_loading || !_registrationEnabled)
                                ? null
                                : _submit,
                            child: Text(
                              _loading ? 'Registrando...' : 'Registrarme',
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => context.go(RouteNames.login),
                          child: const Text('Volver al login'),
                        ),
                        if (_message != null) ...[
                          const SizedBox(height: 8),
                          Text(_message!),
                        ],
                      ],
                    ),
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
