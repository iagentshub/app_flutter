part of '../pages/login_page.dart';

extension _LoginHero on _LoginPageState {
  // Escala tipográfica del panel según su ancho real: en pantallas anchas
  // este panel pasa de 800 px y un tamaño fijo se ve diminuto en monitores
  // grandes (1440p/4K). Solo la aplican titular y entradilla; el ojo de las
  // etiquetas monoespaciadas es deliberadamente constante, porque crecen mal
  // -- una versalita espaciada a 18 px deja de leerse como etiqueta.
  double _heroTextScale(double panelWidth) {
    final t = ((panelWidth - 450) / (900 - 450)).clamp(0.0, 1.0);
    return 1.0 + t * 0.42;
  }

  Widget _buildHeroPanel(BuildContext context, {bool compact = false}) {
    // El fondo y la geometría viven a nivel de pantalla. Si este panel pintara
    // su propio degradado o recortara los arcos, reaparecería la costura exacta
    // entre hero y formulario que el fondo continuo evita.
    if (compact) {
      return Padding(
        key: const Key('login-mobile-hero'),
        padding: const EdgeInsets.only(bottom: 88),
        child: _heroTexts(context, compact: true, scale: 1),
      );
    }

    return LayoutBuilder(
      key: const Key('login-desktop-hero'),
      builder: (context, panelConstraints) => Padding(
        padding: const EdgeInsets.fromLTRB(64, 56, 64, 44),
        child: _heroTexts(
          context,
          compact: false,
          scale: _heroTextScale(panelConstraints.maxWidth),
        ),
      ),
    );
  }

  Widget _heroTexts(
    BuildContext context, {
    required bool compact,
    required double scale,
  }) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _authTextsFuture,
      builder: (context, snapshot) {
        final t = snapshot.data ?? const <String, dynamic>{};
        final accent = Theme.of(context).colorScheme.primary;

        return Column(
          mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IAgentsMarkTile(size: compact ? 36 : 44),
                SizedBox(width: compact ? 11 : 14),
                Text(
                  'iAgents Hub',
                  style: TextStyle(
                    fontSize: compact ? FncFonts.size18 : FncFonts.size20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: FncColors.white,
                  ),
                ),
              ],
            ),
            if (compact) const SizedBox(height: 20) else const Spacer(),

            // `badge` llevaba escrito y traducido desde el principio sin que
            // ninguna pantalla llegara a pintarlo.
            Text(
              _txt(t, 'badge').toUpperCase(),
              style: TextStyle(
                fontFamily: FncFonts.geistMono,
                fontSize: compact ? FncFonts.size10 : FncFonts.size11,
                fontWeight: FontWeight.w500,
                letterSpacing: compact ? 1.6 : 2,
                color: FncColors.white.withValues(alpha: 0.45),
              ),
            ),
            SizedBox(height: compact ? 12 : 22),

            // El corte en tres partes del titular existe desde siempre y la
            // tercera se llama `headline_accent`, pero se pintaba en blanco
            // como las otras dos: el acento no se veía en ninguna parte.
            Text(
              '${_txt(t, 'headline_1')} ${_txt(t, 'headline_pre')}',
              style: _headlineStyle(compact, scale, FncColors.white),
            ),
            Text(
              _txt(t, 'headline_accent'),
              style: _headlineStyle(compact, scale, accent),
            ),
            SizedBox(height: compact ? 14 : 24),

            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: compact ? 300 : 400),
              child: Text(
                _txt(t, 'hero_sub'),
                style: TextStyle(
                  fontSize:
                      (compact ? FncFonts.size14 : FncFonts.size15) * scale,
                  height: 1.65,
                  color: FncColors.white.withValues(alpha: 0.6),
                ),
              ),
            ),

            if (!compact) ...[
              const Spacer(flex: 2),
              Text(
                _txt(t, 'hero_areas').toUpperCase(),
                style: TextStyle(
                  fontFamily: FncFonts.geistMono,
                  fontSize: FncFonts.size10,
                  letterSpacing: 1.4,
                  height: 1.8,
                  color: FncColors.white.withValues(alpha: 0.34),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  TextStyle _headlineStyle(bool compact, double scale, Color color) =>
      TextStyle(
        fontSize: (compact ? FncFonts.size32 : FncFonts.size46) * scale,
        fontWeight: FontWeight.w600,
        height: 1.04,
        letterSpacing: compact ? -0.9 : -1.3,
        color: color,
      );
}
