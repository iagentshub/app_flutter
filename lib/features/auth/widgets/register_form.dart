part of '../pages/register_page.dart';

/// La tarjeta: formulario cuando el registro está abierto, y el aviso de
/// cerrado cuando no. Son excluyentes a propósito — antes se pintaban los tres
/// campos en gris junto al aviso, y un formulario muerto invita a rellenarlo.
extension _RegisterForm on _RegisterPageState {
  Widget _tarjeta() {
    final Widget contenido;
    if (!_configLoaded) {
      contenido = const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: CircularProgressIndicator(color: FncColors.publicCoral),
        ),
      );
    } else if (!_registrationEnabled) {
      contenido = _contenidoCerrado();
    } else {
      contenido = _contenidoFormulario();
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radioPanel),
        border: Border.all(color: FncColors.publicBorderStrong),
        // .landing-panel
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FncColors.publicSurface, FncColors.publicSurfaceElevated],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
      child: contenido,
    );
  }

  Widget _contenidoFormulario() {
    final puedeEnviar = !_loading && _legalAccepted;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _tx('register.title'),
            style: _tituloTarjeta(),
          ),
          const SizedBox(height: 6),
          Text(
            _tx('register.card_sub'),
            style: _texto(
              FncFonts.size14,
              400,
              color: FncColors.publicTextSecondary,
              alto: 1.5,
            ),
          ),
          if (_message != null) ...[
            const SizedBox(height: 22),
            _banner(),
          ],
          const SizedBox(height: 26),
          _CampoPublico(
            label: _tx('register.username_label'),
            hint: _tx('register.username_placeholder'),
            helper: _tx('register.username_hint'),
            controller: _usernameController,
            validator: _validarUsuario,
            autofillHints: const [AutofillHints.newUsername],
          ),
          const SizedBox(height: 18),
          _CampoPublico(
            label: _tx('register.email_label'),
            hint: _tx('register.email_placeholder'),
            controller: _emailController,
            validator: _validarEmail,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
          ),
          const SizedBox(height: 18),
          _CampoPublico(
            label: _tx('register.password_label'),
            hint: _tx('register.password_placeholder'),
            controller: _passwordController,
            obscure: !_showPassword,
            keyboardType: TextInputType.visiblePassword,
            autofillHints: const [AutofillHints.newPassword],
            validator: _validarContrasena,
            suffix: AppIconButton(
              tooltip: _showPassword
                  ? _tx('hide_password')
                  : _tx('show_password'),
              onPressed: () => refresh(() => _showPassword = !_showPassword),
              icon: Icon(
                _showPassword ? Icons.visibility_off : Icons.visibility,
                size: 18,
                color: FncColors.publicTextSecondary,
              ),
            ),
          ),
          const SizedBox(height: 22),
          _aceptacionLegal(),
          const SizedBox(height: 22),
          // `.public-button:disabled` baja la opacidad del botón entero en vez
          // de recolorearlo; con `disabledBackgroundColor` el coral se apagaba
          // a un gris que no existe en el sistema público.
          Opacity(
            opacity: puedeEnviar ? 1 : 0.42,
            child: PrimaryButton(
              onPressed: puedeEnviar ? _submit : null,
              style: FilledButton.styleFrom(
                backgroundColor: FncColors.publicCoral,
                foregroundColor: FncColors.publicCanvas,
                disabledBackgroundColor: FncColors.publicCoral,
                disabledForegroundColor: FncColors.publicCanvas,
                minimumSize: const Size.fromHeight(_altoControl),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_radioControl),
                ),
                textStyle: _texto(FncFonts.size13, 550),
              ),
              child: Text(
                _loading
                    ? _tx('register.submit_btn_loading')
                    : _tx('register.create_account_btn'),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: FncColors.publicBorder),
          const SizedBox(height: 16),
          _pieIniciarSesion(),
        ],
      ),
    );
  }

  // `Validators.username` y `Validators.email` resuelven sus mensajes contra
  // `auth.*`, que vive en resources.json — un bundle que esta pantalla no
  // carga, así que salía la clave cruda («auth.email_invalid») debajo del
  // campo. Aquí se les da el mensaje desde el namespace que sí está cargado.
  // El mismo fallo se ve en login, forgot-password y reset-password.
  String? _validarUsuario(String? value) {
    final requerido = Validators.requiredField(
      value,
      message: _tx('register.error_username_required'),
    );
    if (requerido != null) return requerido;
    return Validators.username(value);
  }

  String? _validarEmail(String? value) {
    final requerido = Validators.requiredField(
      value,
      message: _tx('register.error_email_required'),
    );
    if (requerido != null) return requerido;
    return Validators.email(value) == null
        ? null
        : _tx('register.error_invalid_email');
  }

  String? _validarContrasena(String? value) {
    final requerido = Validators.requiredField(
      value,
      message: _tx('register.error_password_required'),
    );
    if (requerido != null) return requerido;
    if ((value ?? '').trim().length < 8) {
      return _tx('register.error_short_password');
    }
    return null;
  }

  Widget _contenidoCerrado() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: FncColors.publicCoralRing),
              color: FncColors.publicCoralSurface,
            ),
            child: const Icon(
              Icons.lock_outline,
              size: 24,
              color: FncColors.publicCoral,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          _tx('register.closed_kicker'),
          textAlign: TextAlign.center,
          style: _mono(
            FncFonts.size11,
            500,
            color: FncColors.publicTextTertiary,
            espaciado: FncFonts.size11 * 0.12,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _tx('register.closed_title'),
          textAlign: TextAlign.center,
          style: _tituloTarjeta(),
        ),
        const SizedBox(height: 10),
        Text(
          _tx('register.disabled_message'),
          textAlign: TextAlign.center,
          style: _texto(
            FncFonts.size14,
            400,
            color: FncColors.publicTextSecondary,
            alto: 1.6,
          ),
        ),
        const SizedBox(height: 24),
        SecondaryButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: FncColors.publicText,
            backgroundColor: FncColors.publicSurfaceElevated,
            side: const BorderSide(color: FncColors.publicBorder),
            minimumSize: const Size.fromHeight(_altoControl),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_radioControl),
            ),
            textStyle: _texto(FncFonts.size13, 550),
          ),
          onPressed: () => AppRouter.toLogin(context),
          child: Text(_tx('register.sign_in_link')),
        ),
        const SizedBox(height: 14),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: _tx('register.closed_home_pre')),
              TextSpan(
                text: _tx('register.closed_home_link'),
                style: _texto(
                  FncFonts.size13,
                  500,
                  color: FncColors.publicCoral,
                ),
                recognizer: _tocarInicio,
              ),
              TextSpan(text: _tx('register.closed_home_post')),
            ],
          ),
          textAlign: TextAlign.center,
          style: _texto(
            FncFonts.size13,
            400,
            color: FncColors.publicTextSecondary,
            alto: 1.5,
          ),
        ),
      ],
    );
  }

  TextStyle _tituloTarjeta() => _texto(
    FncFonts.size24,
    550,
    color: FncColors.publicText,
    alto: 1.15,
    espaciado: FncFonts.size24 * -0.025,
  );

  /// Los dos documentos van dentro de la frase, no en dos botones sueltos
  /// debajo: la casilla dice qué se acepta y desde ahí mismo se abre.
  Widget _aceptacionLegal() {
    final enlace = _texto(FncFonts.size13, 500, color: FncColors.publicText);
    return InkWell(
      onTap: () => refresh(() => _legalAccepted = !_legalAccepted),
      borderRadius: BorderRadius.circular(_radioControl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: _legalAccepted,
              onChanged: (value) =>
                  refresh(() => _legalAccepted = value ?? false),
              side: const BorderSide(color: FncColors.publicBorderStrong),
              checkColor: FncColors.publicCanvas,
              fillColor: WidgetStateProperty.resolveWith(
                (estados) => estados.contains(WidgetState.selected)
                    ? FncColors.publicCoral
                    : FncColors.publicSurfaceElevated,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: _tx('register.accept_legal_pre')),
                  TextSpan(
                    text: _tx('register.accept_legal_terms'),
                    style: enlace,
                    recognizer: _tocarTerminos,
                  ),
                  TextSpan(text: _tx('register.accept_legal_mid')),
                  TextSpan(
                    text: _tx('register.accept_legal_privacy'),
                    style: enlace,
                    recognizer: _tocarPrivacidad,
                  ),
                ],
              ),
              style: _texto(
                FncFonts.size13,
                400,
                color: FncColors.publicTextSecondary,
                alto: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pieIniciarSesion() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Flexible(
        child: Text(
          _tx('register.already_have_account'),
          style: _texto(
            FncFonts.size13,
            400,
            color: FncColors.publicTextSecondary,
          ),
        ),
      ),
      const SizedBox(width: 6),
      TertiaryButton(
        style: TextButton.styleFrom(
          foregroundColor: FncColors.publicCoral,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          minimumSize: Size.zero,
          textStyle: _texto(FncFonts.size13, 550),
        ),
        onPressed: () => AppRouter.toLogin(context),
        child: Text(_tx('register.sign_in_link')),
      ),
    ],
  );

  Widget _banner() {
    final error = _messageIsError;
    final color = error ? FncColors.publicError : FncColors.publicSuccess;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radioControl),
        border: Border.all(color: color.withValues(alpha: 0.34)),
        color: error
            ? FncColors.publicCoralSurface
            : color.withValues(alpha: 0.10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            error ? Icons.error_outline : Icons.check_circle_outline,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _message!,
              style: _texto(FncFonts.size13, 400, color: color, alto: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
