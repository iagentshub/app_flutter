import 'package:flutter/material.dart';

import '../../../app/router/router.dart';
import '../../../app/theme/fnc_fonts.dart';
import '../../../core/network/api_error.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
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
    _passwordController.dispose();
    super.dispose();
  }

  String _tx(String path) => _t.text(path);

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final token = widget.token?.trim() ?? '';
    if (token.isEmpty) {
      setState(() => _message = _tx('reset_password.invalid_title'));
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
            ? '${_tx('reset_password.ok_title')}. '
                  '${_tx('reset_password.ok_sub')}'
            : _tx('reset_password.update_failed');
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
                              Text(
                                _tx('reset_password.title'),
                                style: const TextStyle(
                                  fontSize: FncFonts.size24,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: true,
                                validator: (value) {
                                  final requiredError = Validators.requiredField(
                                    value,
                                    message: _tx(
                                      'reset_password.error_password_required',
                                    ),
                                  );
                                  if (requiredError != null) {
                                    return requiredError;
                                  }
                                  if ((value ?? '').trim().length < 8) {
                                    return _tx(
                                      'reset_password.error_short_password',
                                    );
                                  }
                                  return null;
                                },
                                decoration: InputDecoration(
                                  labelText: _tx(
                                    'reset_password.new_password_label',
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
                                        ? _tx('reset_password.save_btn_loading')
                                        : _tx('reset_password.save_btn'),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TertiaryButton(
                                onPressed: () => AppRouter.toLogin(context),
                                child: Text(
                                  _tx('reset_password.back_to_login'),
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
                              _tx('reset_password.invalid_title'),
                              style: const TextStyle(
                                fontSize: FncFonts.size24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(_tx('reset_password.invalid_sub')),
                            const SizedBox(height: 8),
                            TertiaryButton(
                              onPressed: () =>
                                  AppRouter.toForgotPassword(context),
                              child: Text(
                                _tx('reset_password.request_new_link'),
                              ),
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
