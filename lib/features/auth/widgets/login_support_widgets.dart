part of '../pages/login_page.dart';

/// Fondo de la pantalla: degradado muy suave sobre el color de página, con un
/// toque del acento en las esquinas. Plano se veía como un folio en blanco.
class _LoginBackground extends StatefulWidget {
  const _LoginBackground();

  @override
  State<_LoginBackground> createState() => _LoginBackgroundState();
}

class _LoginBackgroundState extends State<_LoginBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool? _reducedMotion;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = AppMotion.reduced(context);
    if (_reducedMotion == reduced) return;
    _reducedMotion = reduced;
    if (reduced) {
      _controller
        ..stop()
        ..value = 0;
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RepaintBoundary(
      key: const Key('login-atmosphere'),
      child: CustomPaint(
        key: Key(
          _reducedMotion == true
              ? 'login-atmosphere-static'
              : 'login-atmosphere-animated',
        ),
        painter: _LoginAtmospherePainter(
          animation: _controller,
          base: theme.scaffoldBackgroundColor,
          accent: theme.colorScheme.primary,
          brightness: theme.brightness,
        ),
      ),
    );
  }
}

/// Los arcos de la marca, ampliados hasta ser la arquitectura del panel.
///
/// No es un patrón decorativo: son `coordinatorLeft` y `coordinatorRight` —la
/// misma cúbica que dibuja el logo— repetidas a cinco escalas sobre un único
/// punto de convergencia, con el asta cayendo de él igual que en la marca.
/// El fondo dibuja así lo que dice el titular, y como la geometría sale de
/// [BrandMarkGeometry], un retoque del logo llega aquí solo.
class _LoginAtmospherePainter extends CustomPainter {
  _LoginAtmospherePainter({
    required this.animation,
    required this.base,
    required this.accent,
    required this.brightness,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Color base;
  final Color accent;
  final Brightness brightness;

  /// Escala de cada capa, en anchos de panel, con su opacidad. Las grandes
  /// se salen por los lados a propósito: el recorte por el borde es lo que
  /// hace que se lean como algo que entra desde fuera y no como un adorno
  /// centrado.
  static const _capas = <(double, double)>[
    (0.645, 0.24),
    (1.29, 0.16),
    (2.10, 0.11),
    (3.23, 0.075),
    (4.84, 0.05),
  ];

  /// Punto en el que se juntan los dos brazos dentro de la marca, y por tanto
  /// el origen del que cuelga toda esta geometría.
  static const _origen = BrandPoint(0.5, 0.635);

  Offset _punto(BrandPoint p, Offset centro, double escala) => Offset(
    centro.dx + (p.x - _origen.x) * escala,
    centro.dy + (p.y - _origen.y) * escala,
  );

  Path _arco(BrandCubic curva, Offset centro, double escala) {
    final inicio = _punto(curva.start, centro, escala);
    final c1 = _punto(curva.control1, centro, escala);
    final c2 = _punto(curva.control2, centro, escala);
    final fin = _punto(curva.end, centro, escala);
    return Path()
      ..moveTo(inicio.dx, inicio.dy)
      ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, fin.dx, fin.dy);
  }

  Offset _puntoEnArco(
    BrandCubic curva,
    double t,
    Offset centro,
    double escala,
  ) {
    final start = _punto(curva.start, centro, escala);
    final c1 = _punto(curva.control1, centro, escala);
    final c2 = _punto(curva.control2, centro, escala);
    final end = _punto(curva.end, centro, escala);
    final mt = 1 - t;
    return Offset(
      mt * mt * mt * start.dx +
          3 * mt * mt * t * c1.dx +
          3 * mt * t * t * c2.dx +
          t * t * t * end.dx,
      mt * mt * mt * start.dy +
          3 * mt * mt * t * c1.dy +
          3 * mt * t * t * c2.dy +
          t * t * t * end.dy,
    );
  }

  void _paintBackground(Canvas canvas, Size size, bool wide) {
    final rect = Offset.zero & size;
    final isDark = brightness == Brightness.dark;

    // Una sola base vertical para toda la ventana. Antes el cambio de color
    // avanzaba de izquierda a derecha y, aunque fuera un degradado, coincidía
    // visualmente con el ancho del hero y seguía pareciendo un panel.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(
              FncColors.white.withValues(alpha: isDark ? 0.025 : 0.12),
              base,
            ),
            Color.alphaBlend(
              accent.withValues(alpha: isDark ? 0.035 : 0.025),
              base,
            ),
          ],
        ).createShader(rect),
    );

    // En claro, la nube oscura mantiene el contraste del hero; en oscuro solo
    // aporta profundidad. Es radial y rebasa ampliamente la zona de contenido,
    // por lo que nunca puede leerse como un rectángulo independiente.
    final heroShade = isDark
        ? FncColors.loginPanelTop
        : FncColors.loginPanelDeep;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: wide
              ? const Alignment(-1.05, -0.08)
              : const Alignment(0, -0.78),
          radius: wide ? 1.18 : 1.05,
          colors: [
            heroShade.withValues(alpha: isDark ? 0.34 : 0.94),
            heroShade.withValues(alpha: isDark ? 0.14 : 0.52),
            heroShade.withValues(alpha: 0),
          ],
          stops: const [0, 0.52, 1],
        ).createShader(rect),
    );

    canvas.drawRect(
      rect,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                accent.withValues(alpha: isDark ? 0.055 : 0.035),
                accent.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(
                center: Offset(size.width * 0.91, size.height * 0.08),
                radius: size.shortestSide * 0.82,
              ),
            ),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final wide = size.width >= 1000;
    _paintBackground(canvas, size, wide);

    final phase = animation.value * math.pi * 2;
    final heroWidth = wide
        ? (size.width * 0.43).clamp(420.0, 720.0)
        : size.width;
    final centroBase = Offset(
      wide ? heroWidth * 0.5 : size.width * 0.5,
      wide ? size.height * 0.78 : math.min(size.height * 0.48, 370),
    );
    final centro =
        centroBase + Offset(math.cos(phase) * 2, math.sin(phase) * 5);
    final haloRadius = heroWidth * (wide ? 0.30 : 0.42);

    canvas.drawCircle(
      centro,
      haloRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            FncColors.red.withValues(alpha: 0.28),
            FncColors.red.withValues(alpha: 0.07),
            FncColors.red.withValues(alpha: 0),
          ],
          stops: const [0, 0.38, 1],
        ).createShader(Rect.fromCircle(center: centro, radius: haloRadius)),
    );

    for (var index = 0; index < _capas.length; index++) {
      final (escala, opacidad) = _capas[index];
      final breathe = 1 + math.sin(phase + index * 0.68) * 0.012;
      final ancho = heroWidth * escala * breathe;
      final alpha = opacidad * (0.88 + math.sin(phase + index) * 0.12);
      final trazo = Paint()
        ..shader = LinearGradient(
          colors: [
            FncColors.white.withValues(alpha: alpha),
            FncColors.white.withValues(alpha: alpha * 0.72),
            accent.withValues(alpha: alpha * 0.30),
            accent.withValues(alpha: 0),
          ],
          stops: const [0, 0.38, 0.72, 1],
        ).createShader(Offset.zero & size)
        ..style = PaintingStyle.stroke
        ..strokeWidth = index == 0 ? 1.25 : 1.0
        ..strokeCap = StrokeCap.round;
      canvas
        ..drawPath(
          _arco(BrandMarkGeometry.coordinatorLeft, centro, ancho),
          trazo,
        )
        ..drawPath(
          _arco(BrandMarkGeometry.coordinatorRight, centro, ancho),
          trazo,
        );

      if (index < 3) {
        final signalCurves = [
          BrandMarkGeometry.coordinatorLeft,
          BrandMarkGeometry.coordinatorRight,
        ];
        for (var branch = 0; branch < signalCurves.length; branch++) {
          // Cada señal tiene un nacimiento propio. Todas completan exactamente
          // un recorrido durante el ciclo del controller; esto evita el salto
          // que producía avanzar solo una fracción antes de reiniciar. Los
          // desfases hacen que, cuando una muere en el nodo, otras ya estén
          // naciendo o bajando por ramas diferentes.
          final signalLife =
              (animation.value + index * 0.29 + branch * 0.17) % 1;
          final signalT = Curves.easeInOutSine.transform(signalLife);
          final signalOpacity = math
              .pow(math.sin(math.pi * signalLife).clamp(0.0, 1.0), 0.72)
              .toDouble();
          final signal = _puntoEnArco(
            signalCurves[branch],
            signalT,
            centro,
            ancho,
          );
          final coreRadius = 1.45 + ((index + branch) % 3) * 0.16;
          canvas
            ..drawCircle(
              signal,
              coreRadius * 3.1,
              Paint()..color = accent.withValues(alpha: 0.09 * signalOpacity),
            )
            ..drawCircle(
              signal,
              coreRadius,
              Paint()
                ..color = FncColors.white.withValues(
                  alpha: 0.58 * signalOpacity,
                ),
            );
        }
      }
    }

    final lineEnd = Offset(
      centro.dx,
      wide ? size.height * 0.96 : centro.dy + heroWidth * 0.27,
    );
    canvas.drawLine(
      centro,
      lineEnd,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            FncColors.white.withValues(alpha: 0.22),
            FncColors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromPoints(centro, lineEnd))
        ..strokeWidth = 1.1,
    );

    final pulse = (math.sin(phase) + 1) * 0.5;
    canvas
      ..drawCircle(
        centro,
        12 + pulse * 6,
        Paint()..color = FncColors.red.withValues(alpha: 0.16 - pulse * 0.06),
      )
      ..drawCircle(
        centro,
        8.5,
        Paint()..color = FncColors.red.withValues(alpha: 0.42),
      )
      ..drawCircle(
        centro,
        4.8 + pulse * 0.7,
        Paint()..color = FncColors.loginNode,
      );
  }

  @override
  bool shouldRepaint(_LoginAtmospherePainter oldDelegate) =>
      oldDelegate.animation != animation ||
      oldDelegate.base != base ||
      oldDelegate.accent != accent ||
      oldDelegate.brightness != brightness;
}

class _LanguageSwitcher extends StatelessWidget {
  const _LanguageSwitcher({
    required this.languageCode,
    required this.onPressed,
  });

  final String languageCode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 1000;
    final foreground = theme.brightness == Brightness.light && compact
        ? FncColors.white
        : theme.colorScheme.onSurface;
    return TertiaryButton.icon(
      key: const Key('login-language-switcher'),
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: foreground.withValues(alpha: 0.74),
        backgroundColor: foreground.withValues(alpha: 0.045),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        shape: StadiumBorder(
          side: BorderSide(color: foreground.withValues(alpha: 0.10)),
        ),
      ),
      icon: const Icon(Icons.language_rounded, size: 16),
      label: Text(
        languageCode.toUpperCase(),
        style: const TextStyle(
          fontFamily: FncFonts.geistMono,
          fontSize: FncFonts.size11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
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
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: FncColors.textMuted(context),
              fontWeight: FontWeight.w600,
            ),
          ),
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

  /// Puede quedar deshabilitado mientras se completa un acceso en curso.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final button = SecondaryButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        // El borde deshabilitado se atenúa durante el acceso en curso.
        side: onPressed == null
            ? BorderSide(color: FncColors.borderSubtle(context))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [icon, const SizedBox(width: 8), Text(label)],
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: button,
    );
  }
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
