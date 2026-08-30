part of '../pages/login_page.dart';

extension _LoginForm on _LoginPageState {
  Widget _buildFormCard(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Card(
      key: const Key('login-form-card'),
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surface.withValues(alpha: dark ? 0.88 : 0.94),
      elevation: 0,
      // La transparencia deja entrar el fondo continuo sin sacrificar el
      // contraste del formulario; el borde sustituye a una sombra pesada.
      surfaceTintColor: FncColors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.10),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _authTextsFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: IAgentsLoadingIndicator(
                    localeController: widget.localeController,
                    logoSize: 56,
                    maxMessageWidth: 240,
                  ),
                ),
              );
            }

            final t = snapshot.data!;
            final cardTitle = _txt(t, 'card_title');
            final cardSub = _txt(t, 'card_sub');
            final fieldIdentifier = _txt(t, 'field_identifier');
            final fieldPassword = _txt(t, 'field_password');
            final loginBtn = _txt(t, 'login_btn');
            final loginBtnLoading = _txt(t, 'login_btn_loading');
            final forgotPassword = _txt(t, 'forgot_password');
            final rememberAccount = _txt(t, 'remember_account');
            final divider = _txt(t, 'divider');
            final guestLogin = _txt(t, 'guest_login');
            final guestLoading = _txt(t, 'guest_entering');
            final guestNotice = _txt(t, 'guest_notice');
            final registerAction = _txt(t, 'register_action');
            final fieldPasswordRequired = _txt(t, 'field_password_required');
            final backendDown = _backendStatus == _BackendStatus.down;
            final backendDownMsg = _txt(t, 'backend_down');

            return Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // -- Encabezado ---------------------------------------------------
                  Center(
                    child: Text(
                      cardTitle,
                      // w800 a 22 px se lee tosco, y con la entradilla al
                      // mismo blanco que él las dos líneas competían.
                      style: const TextStyle(
                        fontSize: FncFonts.size22,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Center(
                    child: Text(
                      cardSub,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: FncColors.textMuted(context)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (backendDown) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: FncColors.materialRedAccent.withValues(
                          alpha: 0.08,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: FncColors.materialRedAccent.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _StatusLed(status: _BackendStatus.down),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              backendDownMsg,
                              style: const TextStyle(
                                color: FncColors.materialRedAccent,
                                fontSize: FncFonts.size13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // -- Credenciales --------------------------------------------------
                  TextFormField(
                    controller: _identifierController,
                    validator: (value) => Validators.requiredField(
                      value,
                      message: tr('auth.identifier_required'),
                    ),
                    autocorrect: false,
                    textCapitalization: TextCapitalization.none,
                    decoration: InputDecoration(
                      labelText: fieldIdentifier,
                      prefixIcon: const Icon(Icons.person_outline, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_showPassword,
                    validator: (value) => Validators.requiredField(
                      value,
                      message: fieldPasswordRequired,
                    ),
                    decoration: InputDecoration(
                      labelText: fieldPassword,
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: AppIconButton(
                        // Sin tooltip, un lector de pantalla anunciaba solo
                        // «botón»: ni qué hace ni si la contraseña está ya
                        // visible. Las cadenas llevaban traducidas desde el
                        // principio, sin que nadie las usara.
                        tooltip: _showPassword
                            ? _txt(t, 'hide_password')
                            : _txt(t, 'show_password'),
                        onPressed: () =>
                            refresh(() => _showPassword = !_showPassword),
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  LayoutBuilder(
                    builder: (context, actionConstraints) {
                      final stacked = actionConstraints.maxWidth < 360;
                      final rememberControl = InkWell(
                        onTap: () =>
                            refresh(() => _rememberAccount = !_rememberAccount),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: _rememberAccount,
                                  onChanged: (value) => refresh(
                                    () => _rememberAccount = value ?? false,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  rememberAccount,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                      final forgotControl = TertiaryButton(
                        style: stacked
                            ? TextButton.styleFrom(
                                minimumSize: Size.zero,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              )
                            : null,
                        onPressed: () => AppRouter.toForgotPassword(context),
                        child: Text(
                          forgotPassword,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      );

                      if (stacked) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            rememberControl,
                            Align(
                              alignment: Alignment.centerRight,
                              child: forgotControl,
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Flexible(child: rememberControl),
                          forgotControl,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),

                  // -- Acción principal ------------------------------------------------
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: PrimaryButton(
                      // La pastilla es el `StadiumBorder` que M3 pone solo, y
                      // no casaba con nada más de la tarjeta: campos y botones
                      // OAuth van a radio 10. Aquí se iguala para que los
                      // radios de la pantalla sean un sistema y no la suma de
                      // tres valores por defecto.
                      style: FilledButton.styleFrom(
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                      ),
                      onPressed: (_loading || backendDown) ? null : _submit,
                      child: Text(_loading ? loginBtnLoading : loginBtn),
                    ),
                  ),
                  if (_errorVisible != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: FncColors.materialRedAccent.withValues(
                          alpha: 0.08,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: FncColors.materialRedAccent.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      child: Text(
                        _errorVisible!,
                        style: const TextStyle(
                          color: FncColors.materialRedAccent,
                        ),
                      ),
                    ),
                  ],

                  // -- Accesos alternativos --------------------------------------------
                  if (_platformLoaded && (_showAnyOauth || _guestEnabled)) ...[
                    const SizedBox(height: 20),
                    _OauthDivider(text: divider),
                    const SizedBox(height: 14),
                    if (_showAnyOauth)
                      Wrap(
                        alignment: WrapAlignment.center,
                        runSpacing: 8,
                        children: [
                          if (_oauthGithubEnabled)
                            _OauthButton(
                              label: 'GitHub',
                              icon: const FaIcon(
                                FontAwesomeIcons.github,
                                size: 18,
                              ),
                              onPressed: _loading ? null : _loginWithGithub,
                            ),
                        ],
                      ),
                    if (_guestEnabled) ...[
                      if (_showAnyOauth) const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: SecondaryButton(
                          // Con el borde blanco entero del tema, el acceso de
                          // invitado pesaba en pantalla lo mismo que «Entrar».
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: FncColors.borderQuiet(context),
                            ),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(10),
                              ),
                            ),
                            minimumSize: const Size.fromHeight(44),
                          ),
                          onPressed: (_loading || backendDown)
                              ? null
                              : _submitGuest,
                          child: Text(_loading ? guestLoading : guestLogin),
                        ),
                      ),
                      // El invitado hace ya lo mismo que una cuenta, así que lo
                      // único que lo distingue —que al salir se borra entero—
                      // hay que decirlo antes de que empiece a trabajar.
                      const SizedBox(height: 8),
                      Text(
                        guestNotice,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: FncColors.textMuted(context)),
                      ),
                    ],
                  ],
                  if (_platformLoaded && _showRegister) ...[
                    const SizedBox(height: 14),
                    Center(
                      child: TertiaryButton(
                        onPressed: () => AppRouter.toRegister(context),
                        child: Text(registerAction),
                      ),
                    ),
                  ],

                  // -- Pie: backend activo ----------------------------------------------
                  const SizedBox(height: 18),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  InkWell(
                    key: const Key('login-backend-selector'),
                    onTap: _openBackendConfig,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          _StatusLed(status: _backendStatus),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.backendController.selectedOption.label,
                              overflow: TextOverflow.ellipsis,
                              // Es un host, no una frase: en monoespaciada se
                              // lee como lo que es.
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontFamily: FncFonts.geistMono),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
