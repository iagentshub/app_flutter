import 'package:flutter/material.dart';

import '../../../app/router/router.dart';
import '../../../app/theme/fnc_fonts.dart';
import '../../../core/network/api_error.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
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
  late final TranslatedTexts _t;

  @override
  void initState() {
    super.initState();
    _t = TranslatedTexts(
      localeController: widget.localeController,
      namespace: 'auth',
    )..addListener(_onTextsChanged);
  }

  void _onTextsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _t.removeListener(_onTextsChanged);
    _t.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String _tx(String path, String fallback) => _t.text(path, fallback: fallback);

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      await widget.authRepository.forgotPassword(email: _emailController.text);
      if (!mounted) return;
      setState(() {
        _message = _tx(
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
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _tx(
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
                            labelText: _tx(
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
                            onPressed: _loading ? null : _submit,
                            child: Text(
                              _loading
                                  ? _tx(
                                      'forgot_password_page.send_btn_loading',
                                      'Enviando...',
                                    )
                                  : _tx(
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
                            _tx(
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
