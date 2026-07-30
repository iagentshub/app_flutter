import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/network/api_error.dart';
import '../../../shared/i18n/locale_loader.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../utils/validators.dart';
import '../repositories/auth_repository.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({
    required this.authRepository,
    required this.localeController,
    required this.token,
    super.key,
  });

  final AuthRepository authRepository;
  final LocaleController localeController;
  final String? token;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _message;
  late Future<Map<String, dynamic>> _textsFuture;

  bool get _isEnglish => widget.localeController.isEnglish;

  @override
  void initState() {
    super.initState();
    _textsFuture = LocaleLoader.load(isEnglish: _isEnglish, namespace: 'auth');
    widget.localeController.addListener(_onLocaleChanged);
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
    _passwordController.dispose();
    super.dispose();
  }

  String _txt(Map<String, dynamic> bundle, String path, String fallback) {
    return LocaleLoader.text(bundle, path, fallback: fallback);
  }

  Future<void> _submit(Map<String, dynamic> t) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final token = widget.token?.trim() ?? '';
    if (token.isEmpty) {
      setState(
        () => _message = _txt(
          t,
          'reset_password.invalid_title',
          'Token de recuperación inválido',
        ),
      );
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
        _message = ok
            ? '${_txt(t, 'reset_password.ok_title', 'Contraseña actualizada')}. '
                  '${_txt(t, 'reset_password.ok_sub', 'Ya puedes iniciar sesión con tu nueva contraseña.')}'
            : _txt(
                t,
                'reset_password.update_failed',
                'No se pudo actualizar la contraseña',
              );
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
                  child: FutureBuilder<Map<String, dynamic>>(
                    future: _textsFuture,
                    builder: (context, snapshot) {
                      final t = snapshot.data ?? const {};
                      return hasToken
                          ? Form(
                              key: _formKey,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _txt(
                                      t,
                                      'reset_password.title',
                                      'Nueva contraseña',
                                    ),
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: true,
                                    validator: (value) {
                                      final requiredError =
                                          Validators.requiredField(
                                            value,
                                            message: _txt(
                                              t,
                                              'reset_password.error_password_required',
                                              'La contraseña es obligatoria',
                                            ),
                                          );
                                      if (requiredError != null) {
                                        return requiredError;
                                      }
                                      if ((value ?? '').trim().length < 8) {
                                        return _txt(
                                          t,
                                          'reset_password.error_short_password',
                                          'La contraseña debe tener al menos 8 caracteres',
                                        );
                                      }
                                      return null;
                                    },
                                    decoration: InputDecoration(
                                      labelText: _txt(
                                        t,
                                        'reset_password.new_password_label',
                                        'Nueva contraseña',
                                      ),
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton(
                                      onPressed: _loading
                                          ? null
                                          : () => _submit(t),
                                      child: Text(
                                        _loading
                                            ? _txt(
                                                t,
                                                'reset_password.save_btn_loading',
                                                'Actualizando...',
                                              )
                                            : _txt(
                                                t,
                                                'reset_password.save_btn',
                                                'Actualizar contraseña',
                                              ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () =>
                                        context.go(RouteNames.login),
                                    child: Text(
                                      _txt(
                                        t,
                                        'reset_password.back_to_login',
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
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _txt(
                                    t,
                                    'reset_password.invalid_title',
                                    'Enlace inválido',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _txt(
                                    t,
                                    'reset_password.invalid_sub',
                                    'No se detectó token de recuperación.',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () =>
                                      context.go(RouteNames.forgotPassword),
                                  child: Text(
                                    _txt(
                                      t,
                                      'reset_password.request_new_link',
                                      'Solicitar nuevo enlace',
                                    ),
                                  ),
                                ),
                              ],
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
