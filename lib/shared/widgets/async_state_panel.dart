import 'package:flutter/material.dart';

import 'buttons/app_buttons.dart';

/// Presentación compartida para estados de carga, error y colecciones vacías.
///
/// El widget no decide el estado ni realiza operaciones: recibe textos y
/// callbacks para que la feature conserve el control.
class AsyncStatePanel extends StatelessWidget {
  const AsyncStatePanel.loading({
    this.padding = const EdgeInsets.all(16),
    super.key,
  }) : title = null,
       message = null,
       retryLabel = null,
       onRetry = null,
       icon = null,
       _loading = true;

  const AsyncStatePanel.message({
    required this.message,
    this.title,
    this.icon,
    this.padding = const EdgeInsets.all(16),
    super.key,
  }) : retryLabel = null,
       onRetry = null,
       _loading = false;

  const AsyncStatePanel.error({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
    this.title,
    this.icon = Icons.error_outline,
    this.padding = const EdgeInsets.all(16),
    super.key,
  }) : _loading = false;

  final String? title;
  final String? message;
  final String? retryLabel;
  final VoidCallback? onRetry;
  final IconData? icon;
  final EdgeInsetsGeometry padding;
  final bool _loading;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Padding(
        padding: padding,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Padding(
      padding: padding,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 10),
              ],
              if (title != null) ...[
                Text(
                  title!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
              ],
              Text(message!),
              if (onRetry != null) ...[
                const SizedBox(height: 12),
                PrimaryButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: Text(retryLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
