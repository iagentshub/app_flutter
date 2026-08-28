part of '../pages/login_page.dart';

/// Fondo de la pantalla: degradado muy suave sobre el color de página, con un
/// toque del acento en las esquinas. Plano se veía como un folio en blanco.
class _LoginBackground extends StatelessWidget {
  const _LoginBackground();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.scaffoldBackgroundColor;
    final accent = theme.colorScheme.primary;
    Color tint(double alpha) =>
        Color.alphaBlend(accent.withValues(alpha: alpha), base);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tint(0.05), base, tint(0.09)],
          stops: const [0, 0.55, 1],
        ),
      ),
    );
  }
}

class _OauthDivider extends StatelessWidget {
  const _OauthDivider({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(text, style: Theme.of(context).textTheme.labelSmall),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _OauthButton extends StatelessWidget {
  const _OauthButton({required this.label, required this.icon, this.onPressed});

  final String label;
  final Widget icon;

  /// Null (Google/Apple/Microsoft, sin implementación real todavía) deja el
  /// botón deshabilitado con el tooltip "Próximamente". Con callback
  /// (GitHub) el botón es real.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final button = SecondaryButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [icon, const SizedBox(width: 8), Text(label)],
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: onPressed == null
          ? Tooltip(message: tr('common.coming_soon'), child: button)
          : button,
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.scale = 1.0});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: FncColors.white,
          fontWeight: FontWeight.w800,
          fontSize: FncFonts.size22 * scale,
          letterSpacing: -0.2,
        ),
        children: [
          const TextSpan(text: 'iAgents'),
          SizedBox(width: 6 * scale).toWidgetSpan(),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: FncColors.red,
                borderRadius: BorderRadius.circular(6 * scale),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 8 * scale,
                  vertical: 2 * scale,
                ),
                child: Text(
                  'HUB',
                  style: TextStyle(
                    color: FncColors.white,
                    fontSize: FncFonts.size12 * scale,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension _WidgetSpanExt on Widget {
  WidgetSpan toWidgetSpan() =>
      WidgetSpan(alignment: PlaceholderAlignment.middle, child: this);
}

enum _BackendStatus { checking, ok, down }

class _StatusLed extends StatefulWidget {
  const _StatusLed({required this.status});

  final _BackendStatus status;

  @override
  State<_StatusLed> createState() => _StatusLedState();
}

class _StatusLedState extends State<_StatusLed>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = switch (widget.status) {
      _BackendStatus.checking => FncColors.materialGrey,
      _BackendStatus.ok => FncColors.materialGreenAccent.shade400,
      _BackendStatus.down => FncColors.materialRedAccent,
    };

    if (widget.status == _BackendStatus.checking) {
      return _dot(color, 0.6);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => _dot(color, 0.35 + 0.65 * _controller.value),
    );
  }

  Widget _dot(Color color, double opacity) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: opacity),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: opacity * 0.6),
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}
