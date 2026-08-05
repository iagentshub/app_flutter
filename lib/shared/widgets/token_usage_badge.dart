import 'package:flutter/material.dart';

/// "16.4K", "820", "1.2M" — mismo formato compacto usado en el panel de
/// administración (`admin_page.dart::_fmtTokens`) para que el número se lea
/// igual en toda la app.
String formatTokenCount(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

/// Insignia compacta de tokens consumidos — mismo estilo visual que las
/// insignias de tipo/scope del panel de administración, para que agentes y
/// conexiones se lean como parte del mismo sistema. No se pinta nada si el
/// total es 0 (recurso que aún no se ha usado).
class TokenUsageBadge extends StatelessWidget {
  const TokenUsageBadge({
    required this.tokensIn,
    required this.tokensOut,
    this.tooltip,
    super.key,
  });

  final int tokensIn;
  final int tokensOut;
  final String? tooltip;

  static const _color = Color(0xFF0891B2);

  @override
  Widget build(BuildContext context) {
    final total = tokensIn + tokensOut;
    if (total <= 0) return const SizedBox.shrink();

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt, size: 12, color: _color),
          const SizedBox(width: 3),
          Text(
            formatTokenCount(total),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _color,
            ),
          ),
        ],
      ),
    );
    if (tooltip == null || tooltip!.isEmpty) return badge;
    return Tooltip(message: tooltip!, child: badge);
  }
}
