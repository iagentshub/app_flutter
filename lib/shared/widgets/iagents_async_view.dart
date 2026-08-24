import 'package:flutter/material.dart';

import '../state/locale_controller.dart';
import 'async_state_panel.dart';
import 'iagents_loading_indicator.dart';

/// Contrato único para páginas que conservan su contenido mientras recargan.
/// Los estados de error y espera dejan de repetirse en cada feature.
class IAgentsAsyncView extends StatelessWidget {
  const IAgentsAsyncView({
    required this.loading,
    required this.localeController,
    required this.child,
    required this.errorTitle,
    required this.retryLabel,
    required this.onRetry,
    this.error,
    super.key,
  });

  final bool loading;
  final LocaleController localeController;
  final Widget child;
  final String? error;
  final String errorTitle;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error;
    final content = message == null
        ? child
        : ListView(
            children: [
              AsyncStatePanel.error(
                title: errorTitle,
                message: message,
                retryLabel: retryLabel,
                onRetry: onRetry,
              ),
            ],
          );
    return IAgentsLoadingOverlay(
      loading: loading,
      localeController: localeController,
      child: content,
    );
  }
}
