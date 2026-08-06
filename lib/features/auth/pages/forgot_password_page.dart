import 'package:flutter/material.dart';

import '../../../shared/widgets/buttons/app_buttons.dart';

import '../../../app/router/router.dart';
import '../../../app/theme/fnc_fonts.dart';
import '../../../core/network/api_error.dart';
import '../../../shared/i18n/locale_loader.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../utils/validators.dart';
import '../repositories/auth_repository.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({
    required this.authRepository,
    required this.localeController,
    super.key,
  });

  final AuthRepository authRepository;
  final LocaleController localeController;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
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
    _emailController.dispose();
    super.dispose();
  }

  String _txt(Map<String, dynamic> bundle, String path, String fallback) {
    return LocaleLoader.text(bundle, path, fallback: fallback);
  }

  Future<void> _submit(Map<String, dynamic> t) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      await widget.authRepository.forgotPassword(email: _emailController.text);
      if (!mounted) return;
      setState(() {
        _message = _txt(
          t,
          'forgot_password_page.sent_body',
          'Si el correo existe, se enviaron instrucciones de recuperación.',
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
                              _txt(
                                t,
                                'forgot_password_page.title',
                                'Recuperar contraseña',
                              ),
                              style: const TextStyle(
                                fontSize: FncFonts.size24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _emailController,
                              validator: Validators.email,
                              decoration: InputDecoration(
                                labelText: _txt(
                                  t,
                                  'forgot_password_page.email_label',
                                  'Email',
                                ),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: PrimaryButton(
                                onPressed: _loading ? null : () => _submit(t),
                                child: Text(
                                  _loading
                                      ? _txt(
                                          t,
                                          'forgot_password_page.send_btn_loading',
                                          'Enviando...',
                                        )
                                      : _txt(
                                          t,
                                          'forgot_password_page.send_btn',
                                          'Enviar enlace',
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
                                  'forgot_password_page.back_to_login_arrow',
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
