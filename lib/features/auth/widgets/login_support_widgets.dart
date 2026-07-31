part of '../pages/login_page.dart';

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
  const _OauthButton({required this.label, required this.icon});

  final String label;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Tooltip(
        message: 'Próximamente',
        child: SecondaryButton(
          onPressed: null,
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            minimumSize: const Size(44, 44),
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [icon, const SizedBox(width: 8), Text(label)],
          ),
        ),
      ),
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
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 22 * scale,
          letterSpacing: -0.2,
        ),
        children: [
          const TextSpan(text: 'iAgents'),
          SizedBox(width: 6 * scale).toWidgetSpan(),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFD90429),
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
                    color: Colors.white,
                    fontSize: 12 * scale,
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
      _BackendStatus.checking => Colors.grey,
      _BackendStatus.ok => Colors.greenAccent.shade400,
      _BackendStatus.down => Colors.redAccent,
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
