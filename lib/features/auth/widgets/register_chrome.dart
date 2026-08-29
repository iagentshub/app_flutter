part of '../pages/register_page.dart';

/// Cabecera y columna de marca: lo que hace que /register se lea como una
/// página más del sitio público y no como una pantalla de la app.
extension _RegisterChrome on _RegisterPageState {
  Widget _cabecera({required double ancho, required bool amplio}) {
    // .landing-header repite el borde izquierdo del contenido:
    // max(gutter, (100% - medida)/2 + gutter).
    final calle = math.max(_calle, (ancho - _medida) / 2 + _calle);
    return Container(
      height: _altoCabecera,
      padding: EdgeInsets.symmetric(horizontal: calle),
      decoration: const BoxDecoration(
        color: FncColors.publicTopbar,
        border: Border(bottom: BorderSide(color: FncColors.publicBorder)),
      ),
      child: Row(
        children: [
          const _MarcaPublica(),
          // El menú desaparece igual que `.landing-nav` a 900 px. Va dentro de
          // un scroll bloqueado, no suelto en la fila: con la fuente de
          // respaldo —antes de que cargue Geist, y en los tests— los cinco
          // enlaces miden bastante más y reventaban la cabecera. Así se
          // recortan en silencio en vez de pintar la barra de desbordamiento.
          if (amplio)
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 32),
                    _enlaceMenu(_tx('register.nav_home'), '/'),
                    const SizedBox(width: 24),
                    _enlaceMenu(
                      _tx('register.nav_about'),
                      ExternalRoutes.about,
                    ),
                    const SizedBox(width: 24),
                    _enlaceMenu(_tx('register.nav_docs'), ExternalRoutes.docs),
                    const SizedBox(width: 24),
                    _enlaceMenu(
                      _tx('register.nav_pricing'),
                      ExternalRoutes.pricing,
                    ),
                    const SizedBox(width: 24),
                    _enlaceMenu(
                      _tx('register.nav_support'),
                      ExternalRoutes.support,
                    ),
                  ],
                ),
              ),
            )
          else
            const Spacer(),
          _selectorIdioma(),
          const SizedBox(width: 12),
          _botonEntrar(),
        ],
      ),
    );
  }

  Widget _enlaceMenu(String etiqueta, String path) => TertiaryButton(
    style: TextButton.styleFrom(
      foregroundColor: FncColors.publicTextSecondary,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
      minimumSize: Size.zero,
      textStyle: _texto(FncFonts.size13, 500),
    ),
    onPressed: () => _abrirPaginaPublica(path),
    child: Text(etiqueta),
  );

  /// `.public-language-trigger`: 34 de alto, radio 7, sin caja hasta el hover.
  /// El blanco táctil sigue siendo de 48 (`tapTargetSize` por defecto).
  Widget _selectorIdioma() => TertiaryButton(
    style: TextButton.styleFrom(
      foregroundColor: FncColors.publicText,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      minimumSize: const Size(0, 34),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
    ),
    onPressed: () => widget.localeController.setLanguage(_siguienteIdioma),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.language,
          size: 16,
          color: FncColors.publicTextSecondary,
        ),
        const SizedBox(width: 7),
        Text(
          _languageCode.toUpperCase(),
          style: _texto(FncFonts.size13, 500, color: FncColors.publicText),
        ),
        const SizedBox(width: 7),
        const Icon(
          Icons.keyboard_arrow_down,
          size: 12,
          color: FncColors.publicTextSecondary,
        ),
      ],
    ),
  );

  /// `.btn.btn-ghost.btn-sm`: 5x11 de relleno, 12 px con peso 550.
  Widget _botonEntrar() => SecondaryButton(
    style: OutlinedButton.styleFrom(
      foregroundColor: FncColors.publicText,
      backgroundColor: FncColors.publicSurfaceElevated,
      side: const BorderSide(color: FncColors.publicBorderStrong),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      minimumSize: Size.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radioControl),
      ),
      textStyle: _texto(FncFonts.size12, 550),
    ),
    onPressed: () => AppRouter.toLogin(context),
    child: Text(_tx('register.sign_in_link')),
  );

  Widget _columnaCopy({required bool compacto}) {
    final tamanoTitular = compacto ? FncFonts.size28 : FncFonts.size46;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _tx('register.hero_kicker'),
          style: _mono(
            FncFonts.size11,
            500,
            color: FncColors.publicTextTertiary,
            // El 0.12em de .landing-hero-kicker, en píxeles.
            espaciado: FncFonts.size11 * 0.12,
          ),
        ),
        SizedBox(height: compacto ? 8 : 24),
        Text(
          _tx('register.hero_headline'),
          style: _texto(
            tamanoTitular,
            520,
            color: FncColors.publicText,
            alto: compacto ? 1.05 : 0.99,
            espaciado: tamanoTitular * -0.035,
          ),
        ),
        if (!compacto) ...[
          const SizedBox(height: 28),
          _ventaja(
            _tx('register.benefit_selfhosted_title'),
            _tx('register.benefit_selfhosted_body'),
          ),
          const SizedBox(height: 16),
          _ventaja(
            _tx('register.benefit_providers_title'),
            _tx('register.benefit_providers_body'),
          ),
          const SizedBox(height: 16),
          _ventaja(
            _tx('register.benefit_agents_title'),
            _tx('register.benefit_agents_body'),
          ),
          const SizedBox(height: 16),
          _ventaja(
            _tx('register.benefit_groups_title'),
            _tx('register.benefit_groups_body'),
          ),
        ],
      ],
    );
  }

  /// Una ventaja del hero: check coral, título y una línea.
  ///
  /// Sustituye al párrafo de `hero.sub` que se copió de la landing. Ahí ese
  /// texto explica qué es el producto, que es lo que toca en la portada; aquí
  /// el visitante ya viene de leerlo y la pregunta es otra —qué gana creando
  /// la cuenta—, y eso se lee en lista, no en prosa.
  ///
  /// Las dos cadenas llegan resueltas y no se compone la clave con
  /// interpolación: `_tx('register.benefit_${x}_title')` funcionaría, pero el
  /// guardián de claves solo ve identificadores literales y dejaría de
  /// vigilarlas.
  Widget _ventaja(String titulo, String cuerpo) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.only(top: 3),
        child: Icon(Icons.check, size: 16, color: FncColors.publicCoral),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              titulo,
              style: _texto(FncFonts.size14, 550, color: FncColors.publicText),
            ),
            const SizedBox(height: 2),
            Text(
              cuerpo,
              style: _texto(
                FncFonts.size13,
                400,
                color: FncColors.publicTextSecondary,
                alto: 1.5,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// `.landing-logo`: «iAgents» y «Hub» en caja, nunca pegados.
class _MarcaPublica extends StatelessWidget {
  const _MarcaPublica();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'iAgents',
            style: _texto(
              FncFonts.size16,
              700,
              color: FncColors.publicText,
              espaciado: FncFonts.size16 * -0.03,
            ),
          ),
          const SizedBox(width: 4),
          DecoratedBox(
            decoration: BoxDecoration(
              color: FncColors.publicAccentSolid,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(5, 1, 5, 2),
              child: Text(
                'Hub',
                style: _texto(
                  FncFonts.size16,
                  700,
                  color: FncColors.white,
                  espaciado: FncFonts.size16 * -0.02,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Los dos radiales coral de `.public-shell-glow`. El radio de Flutter es una
/// fracción del lado corto, así que los 448 y 384 px del CSS se traducen
/// tomando como referencia los 900 de alto de la maqueta.
class _Resplandor extends StatelessWidget {
  const _Resplandor();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.52, -0.82),
                  radius: 0.50,
                  colors: [FncColors.publicGlowStrong, FncColors.transparent],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.84, -0.16),
                  radius: 0.43,
                  colors: [FncColors.publicGlowSoft, FncColors.transparent],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
