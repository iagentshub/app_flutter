import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/network/api_error.dart';
import '../../../shared/state/session_controller.dart';
import '../repositories/auth_repository.dart';

class VerifyPage extends StatefulWidget {
  const VerifyPage({
    required this.authRepository,
    required this.sessionController,
    required this.token,
    super.key,
  });

  final AuthRepository authRepository;
  final SessionController sessionController;
  final String? token;

  @override
  State<VerifyPage> createState() => _VerifyPageState();
}

class _VerifyPageState extends State<VerifyPage> {
  bool _loading = true;
  String _message = 'Verificando cuenta...';

  @override
  void initState() {
    super.initState();
    _verify();
  }

  Future<void> _verify() async {
    final token = widget.token?.trim() ?? '';
    if (token.isEmpty) {
      setState(() {
        _loading = false;
        _message = 'Token de verificación inválido';
      });
      return;
    }

    try {
      final (ok, gaToken) = await widget.authRepository.verifyEmail(token);
      if (!ok) {
        setState(() {
          _loading = false;
          _message = 'No se pudo verificar la cuenta';
        });
        return;
      }

      if (gaToken == null || gaToken.isEmpty) {
        setState(() {
          _loading = false;
          _message = 'Cuenta verificada. Inicia sesión manualmente para continuar.';
        });
        return;
      }

      final me = await widget.authRepository.me(gaToken);
      await widget.sessionController.login(token: gaToken, user: me);

      if (!mounted) return;
      context.go(RouteNames.dashboard);
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
        _message = 'Error verificando la cuenta';
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
                    if (_loading) const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(_message),
                    const SizedBox(height: 10),
                    if (!_loading)
                      TextButton(
                        onPressed: () => context.go(RouteNames.login),
                        child: const Text('Volver al login'),
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
