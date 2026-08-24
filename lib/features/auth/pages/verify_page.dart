import 'package:flutter/material.dart';

import '../../../app/router/router.dart';
import '../../../core/network/api_error.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/state/theme_controller.dart';
import '../../../shared/widgets/animated_iagents_mark.dart';
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
  late final TranslatedTexts _t;

  @override
  void initState() {
    super.initState();
    _t = TranslatedTexts(
      localeController: widget.localeController,
      namespace: 'auth',
    )..addListener(_onTextsChanged);
    _verify();
  }

  void _onTextsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _t.removeListener(_onTextsChanged);
    _t.dispose();
    super.dispose();
  }

  String _tx(String path) => _t.text(path);

  Future<void> _verify() async {
    final themeController = ThemeControllerScope.of(context, listen: false);
    await _t.ready;
    if (!mounted) return;
    final token = widget.token?.trim() ?? '';
    if (token.isEmpty) {
      setState(() {
        _loading = false;
        _message = _tx('verify.error_sub');
      });
      return;
    }

    try {
      final (ok, gaToken) = await widget.authRepository.verifyEmail(token);
      if (!ok) {
        setState(() {
          _loading = false;
          _message = _tx('verify.error_sub');
        });
        return;
      }

      if (gaToken == null || gaToken.isEmpty) {
        setState(() {
          _loading = false;
          _message = _tx('verify.manual_login_required');
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

      // El cambio de SessionController ya activa el redirect protegido del
      // GoRouter. Una segunda navegación aquí reiniciaba la vista de destino.
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
        _message = _tx('verify.error_generic');
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_loading) const IAgentsLoadingMark(),
                    const SizedBox(height: 12),
                    Text(_message ?? _tx('verify.loading_title')),
                    const SizedBox(height: 10),
                    if (!_loading)
                      TertiaryButton(
                        onPressed: () => AppRouter.toLogin(context),
                        child: Text(_tx('verify.go_login')),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
