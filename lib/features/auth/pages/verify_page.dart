import 'package:flutter/material.dart';

import '../../../app/router/router.dart';
import '../../../core/network/api_error.dart';
import '../../../shared/i18n/locale_loader.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/state/theme_controller.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../repositories/auth_repository.dart';

class VerifyPage extends StatefulWidget {
  const VerifyPage({
    required this.authRepository,
    required this.sessionController,
    required this.localeController,
    required this.token,
    super.key,
  });

  final AuthRepository authRepository;
  final SessionController sessionController;
  final LocaleController localeController;
  final String? token;

  @override
  State<VerifyPage> createState() => _VerifyPageState();
}

class _VerifyPageState extends State<VerifyPage> {
  bool _loading = true;
  String? _message;
  late Future<Map<String, dynamic>> _textsFuture;

  String get _languageCode => widget.localeController.languageCode;

  @override
  void initState() {
    super.initState();
    _textsFuture = LocaleLoader.load(
      languageCode: _languageCode,
      namespace: 'auth',
    );
    _verify();
  }

  String _txt(Map<String, dynamic> bundle, String path, String fallback) {
    return LocaleLoader.text(bundle, path, fallback: fallback);
  }

  Future<void> _verify() async {
    final themeController = ThemeControllerScope.of(context, listen: false);
    final t = await _textsFuture;
    final token = widget.token?.trim() ?? '';
    if (token.isEmpty) {
      setState(() {
        _loading = false;
        _message = _txt(
          t,
          'verify.error_sub',
          'El enlace de verificación es inválido o ha expirado.',
        );
      });
      return;
    }

    try {
      final (ok, gaToken) = await widget.authRepository.verifyEmail(token);
      if (!ok) {
        setState(() {
          _loading = false;
          _message = _txt(
            t,
            'verify.error_sub',
            'El enlace de verificación es inválido o ha expirado.',
          );
        });
        return;
      }

      if (gaToken == null || gaToken.isEmpty) {
        setState(() {
          _loading = false;
          _message = _txt(
            t,
            'verify.manual_login_required',
            'Cuenta verificada. Inicia sesión manualmente para continuar.',
          );
        });
        return;
      }

      final me = await widget.authRepository.me(gaToken);
      await widget.sessionController.login(token: gaToken, user: me);
      try {
        final settings = await widget.authRepository.getSettings(gaToken);
        await themeController.syncFromBackend(settings['theme'] as String?);
      } catch (_) {
        // La verificación no debe fallar por una preferencia visual.
      }

      if (!mounted) return;
      AppRouter.toDashboard(context);
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = _txt(
          t,
          'verify.error_generic',
          'Error verificando la cuenta',
        );
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
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: FutureBuilder<Map<String, dynamic>>(
                  future: _textsFuture,
                  builder: (context, snapshot) {
                    final t = snapshot.data ?? const {};
                    final message =
                        _message ??
                        _txt(t, 'verify.loading_title', 'Verificando cuenta…');
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_loading) const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        Text(message),
                        const SizedBox(height: 10),
                        if (!_loading)
                          TertiaryButton(
                            onPressed: () => AppRouter.toLogin(context),
                            child: Text(
                              _txt(t, 'verify.go_login', 'Volver al login'),
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
    );
  }
}
