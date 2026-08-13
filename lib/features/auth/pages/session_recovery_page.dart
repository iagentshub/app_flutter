import 'package:flutter/material.dart';

import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/backend_controller.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';

class SessionRecoveryPage extends StatefulWidget {
  const SessionRecoveryPage({
    required this.sessionController,
    required this.backendController,
    required this.localeController,
    required this.onRetry,
    required this.onConfigureBackend,
    required this.onUseAnotherAccount,
    super.key,
  });

  final SessionController sessionController;
  final BackendController backendController;
  final LocaleController localeController;
  final VoidCallback onRetry;
  final VoidCallback onConfigureBackend;
  final VoidCallback onUseAnotherAccount;

  @override
  State<SessionRecoveryPage> createState() => _SessionRecoveryPageState();
}

class _SessionRecoveryPageState extends State<SessionRecoveryPage> {
  late final TranslatedTexts _texts;

  @override
  void initState() {
    super.initState();
    _texts = TranslatedTexts(
      localeController: widget.localeController,
      namespace: 'auth',
    )..addListener(_onChanged);
    widget.sessionController.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.sessionController.removeListener(_onChanged);
    _texts.removeListener(_onChanged);
    _texts.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  String _tx(String key, String fallback) =>
      _texts.text(key, fallback: fallback);

  @override
  Widget build(BuildContext context) {
    final restoring =
        widget.sessionController.status == SessionStatus.restoring;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        label: restoring
                            ? _tx(
                                'session_restoring_semantics',
                                'Validando la sesión guardada',
                              )
                            : _tx(
                                'session_unavailable_semantics',
                                'Servidor no disponible',
                              ),
                        child: restoring
                            ? const SizedBox.square(
                                dimension: 44,
                                child: CircularProgressIndicator(),
                              )
                            : Icon(
                                Icons.cloud_off_outlined,
                                size: 48,
                                color: scheme.error,
                              ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        restoring
                            ? _tx(
                                'session_restoring_title',
                                'Comprobando tu sesión',
                              )
                            : _tx(
                                'session_unavailable_title',
                                'No se puede conectar con el servidor',
                              ),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        restoring
                            ? _tx(
                                'session_restoring_body',
                                'Espera mientras verificamos tus credenciales.',
                              )
                            : _tx(
                                'session_unavailable_body',
                                'Tu sesión se conserva, pero no abriremos el dashboard hasta poder validarla.',
                              ),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      if (!restoring) ...[
                        const SizedBox(height: 8),
                        Text(
                          widget.backendController.effectiveBaseUrl,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: PrimaryButton.icon(
                            key: const ValueKey('session-retry-button'),
                            onPressed: widget.onRetry,
                            icon: const Icon(Icons.refresh),
                            label: Text(_tx('common_retry', 'Reintentar')),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: SecondaryButton.icon(
                            key: const ValueKey(
                              'session-configure-backend-button',
                            ),
                            onPressed: widget.onConfigureBackend,
                            icon: const Icon(Icons.dns_outlined),
                            label: Text(
                              _tx(
                                'session_configure_backend',
                                'Configurar servidor',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TertiaryButton(
                          key: const ValueKey(
                            'session-use-another-account-button',
                          ),
                          onPressed: widget.onUseAnotherAccount,
                          child: Text(
                            _tx(
                              'session_use_another_account',
                              'Usar otra cuenta',
                            ),
                          ),
                        ),
                      ],
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
