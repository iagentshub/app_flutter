import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/network/api_error.dart';
import '../../../utils/validators.dart';
import '../repositories/auth_repository.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({
    required this.authRepository,
    required this.token,
    super.key,
  });

  final AuthRepository authRepository;
  final String? token;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _message;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final token = widget.token?.trim() ?? '';
    if (token.isEmpty) {
      setState(() => _message = 'Token de recuperación inválido');
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final ok = await widget.authRepository.resetPassword(
        token: token,
        password: _passwordController.text,
      );
      if (!mounted) return;
      setState(() {
        _message = ok ? 'Contraseña actualizada. Ya puedes iniciar sesión.' : 'No se pudo actualizar la contraseña';
      });
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() => _message = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasToken = (widget.token?.trim().isNotEmpty ?? false);

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
                  child: hasToken
                      ? Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Restablecer contraseña', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: true,
                                validator: (value) {
                                  final requiredError = Validators.requiredField(value, message: 'La contraseña es obligatoria');
                                  if (requiredError != null) return requiredError;
                                  if ((value ?? '').trim().length < 8) return 'La contraseña debe tener al menos 8 caracteres';
                                  return null;
                                },
                                decoration: const InputDecoration(labelText: 'Nueva contraseña', border: OutlineInputBorder()),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _loading ? null : _submit,
                                  child: Text(_loading ? 'Actualizando...' : 'Actualizar contraseña'),
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
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Enlace inválido', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 10),
                            const Text('No se detectó token de recuperación.'),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => context.go(RouteNames.forgotPassword),
                              child: const Text('Solicitar nuevo enlace'),
                            ),
                          ],
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
