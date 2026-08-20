part of '../pages/login_page.dart';

extension _LoginHero on _LoginPageState {
  // Escala tipográfica del panel según su ancho real: en pantallas anchas
  // (>=900 de ventana) este panel ocupa la mitad del ancho, y un tamaño fijo
  // de fuente se ve diminuto en monitores grandes (1440p/4K).
  double _heroTextScale(double panelWidth) {
    final t = ((panelWidth - 450) / (900 - 450)).clamp(0.0, 1.0);
    return 1.0 + t * 0.6;
  }

  Widget _buildHeroPanel(BuildContext context, {bool compact = false}) {
    return Container(
      key: Key(compact ? 'login-mobile-hero' : 'login-desktop-hero'),
      color: FncColors.black,
      padding: compact
          ? const EdgeInsets.fromLTRB(4, 12, 4, 32)
          : const EdgeInsets.all(48),
      child: LayoutBuilder(
        builder: (context, panelConstraints) {
          final scale = compact
              ? 0.88
              : _heroTextScale(panelConstraints.maxWidth);
          final brandScale = compact ? 1.0 : 1.6 * (1 + (scale - 1) * 0.5);

          return FutureBuilder<Map<String, dynamic>>(
            future: _authTextsFuture,
            builder: (context, snapshot) {
              final t = snapshot.data ?? const {};
              final headlinePre = _txt(t, 'headline_pre');
              final headline1 = _txt(t, 'headline_1');
              final headlineAccent = _txt(t, 'headline_accent');
              final heroSub = _txt(t, 'hero_sub');

              return Column(
                mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
                mainAxisAlignment: compact
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BrandMark(scale: brandScale),
                  SizedBox(height: (compact ? 18 : 24) * scale),
                  Text(
                    '$headline1 $headlinePre\n$headlineAccent',
                    style: TextStyle(
                      fontSize: FncFonts.size32 * scale,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      color: FncColors.white,
                    ),
                  ),
                  SizedBox(height: (compact ? 12 : 16) * scale),
                  Text(
                    heroSub,
                    style: TextStyle(
                      fontSize: FncFonts.size15 * scale,
                      color: FncColors.white.withValues(alpha: 0.7),
                      height: 1.5,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
