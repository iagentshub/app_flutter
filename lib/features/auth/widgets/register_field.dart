part of '../pages/register_page.dart';

/// `.public-field`: etiqueta encima, control de 44 y ayuda debajo.
///
/// Nada que ver con el `InputDecoration` del resto de la app, que flota la
/// etiqueta sobre el borde al estilo Material. El sitio público la pone
/// encima, y esta pantalla sigue al sitio público.
///
/// Tiene estado solo por el anillo de foco: `:focus` dibuja un contorno coral
/// alrededor del borde, y para saber cuándo toca hay que oír al FocusNode.
class _CampoPublico extends StatefulWidget {
  const _CampoPublico({
    required this.label,
    required this.controller,
    this.hint,
    this.helper,
    this.validator,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.autofillHints,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? helper;
  final FormFieldValidator<String>? validator;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;

  @override
  State<_CampoPublico> createState() => _CampoPublicoState();
}

class _CampoPublicoState extends State<_CampoPublico> {
  final _foco = FocusNode();

  @override
  void initState() {
    super.initState();
    _foco.addListener(_alCambiarFoco);
  }

  void _alCambiarFoco() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _foco.removeListener(_alCambiarFoco);
    _foco.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label,
          style: _texto(FncFonts.size13, 550, color: FncColors.publicText),
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radioControl),
            boxShadow: _foco.hasFocus
                ? const [
                    // ponytail: anillo pegado al borde. El CSS lo separa 2 px
                    // (outline-offset) y aquí eso pediría pintar el hueco con
                    // el color exacto del degradado de la tarjeta en cada
                    // punto. Si algún día molesta, la salida es un Stack con
                    // el hueco recortado, no adivinar el color.
                    BoxShadow(
                      color: FncColors.publicCoralRing,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: TextFormField(
            controller: widget.controller,
            focusNode: _foco,
            validator: widget.validator,
            obscureText: widget.obscure,
            keyboardType: widget.keyboardType,
            autofillHints: widget.autofillHints,
            autocorrect: false,
            textCapitalization: TextCapitalization.none,
            cursorColor: FncColors.publicCoral,
            style: _texto(FncFonts.size15, 400, color: FncColors.publicText),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: _texto(
                FncFonts.size15,
                400,
                color: FncColors.publicTextTertiary,
              ),
              helperText: widget.helper,
              helperMaxLines: 3,
              helperStyle: _texto(
                FncFonts.size13,
                400,
                color: FncColors.publicTextSecondary,
                alto: 1.4,
              ),
              errorMaxLines: 3,
              errorStyle: _texto(
                FncFonts.size13,
                400,
                color: FncColors.publicError,
                alto: 1.4,
              ),
              filled: true,
              fillColor: FncColors.publicSurfaceElevated,
              isDense: true,
              constraints: const BoxConstraints(minHeight: _altoControl),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              suffixIcon: widget.suffix,
              suffixIconConstraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 40,
              ),
              border: _borde(FncColors.publicBorder),
              enabledBorder: _borde(FncColors.publicBorder),
              disabledBorder: _borde(FncColors.publicBorder),
              focusedBorder: _borde(FncColors.publicCoral),
              errorBorder: _borde(FncColors.publicError),
              focusedErrorBorder: _borde(FncColors.publicError),
            ),
          ),
        ),
      ],
    );
  }
}
