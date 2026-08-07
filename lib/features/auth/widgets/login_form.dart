part of '../pages/login_page.dart';

extension _LoginForm on _LoginPageState {
  Widget _buildFormCard(BuildContext context) {
    return Card(
      key: const Key('login-form-card'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _authTextsFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final t = snapshot.data!;
            final cardTitle = _txt(
              t,
              'card_title',
              _isEnglish ? 'Welcome' : 'Bienvenido',
            );
            final cardSub = _txt(
              t,
              'card_sub',
              _isEnglish
                  ? 'Access your agent platform'
                  : 'Accede a tu espacio de agentes',
            );
            final fieldIdentifier = _txt(
              t,
              'field_identifier',
              _isEnglish ? 'Username or email' : 'Usuario o email',
            );
            final fieldPassword = _txt(
              t,
              'field_password',
              _isEnglish ? 'Password' : 'Contraseña',
            );
            final loginBtn = _txt(
              t,
              'login_btn',
              _isEnglish ? 'Sign in' : 'Entrar',
            );
            final loginBtnLoading = _txt(
              t,
              'login_btn_loading',
              _isEnglish ? 'Signing in…' : 'Entrando…',
            );
            final forgotPassword = _txt(
              t,
              'forgot_password',
              _isEnglish
                  ? 'Forgot your password?'
                  : '¿Olvidaste tu contraseña?',
            );
            final rememberAccount = _txt(
              t,
              'remember_account',
              _isEnglish ? 'Remember my account' : 'Recordar mi cuenta',
            );
            final divider = _txt(t, 'divider', _isEnglish ? 'or' : 'o');
            final guestLogin = _txt(
              t,
              'guest_login',
              _isEnglish ? 'Access as guest' : 'Acceder como invitado',
            );
            final guestLoading = _txt(
              t,
              'guest_entering',
              _isEnglish ? 'Entering…' : 'Entrando…',
            );
            final registerAction = _txt(
              t,
              'register_action',
              _isEnglish ? 'Create account' : 'Crear cuenta',
            );
            final fieldPasswordRequired = _txt(
              t,
              'field_password_required',
              _isEnglish
                  ? 'Password is required'
                  : 'La contraseña es obligatoria',
            );
            final backendDown = _backendStatus == _BackendStatus.down;
            final backendDownMsg = _txt(
              t,
              'backend_down',
              _isEnglish
                  ? 'Unable to reach this backend. Check your connection or pick another backend below.'
                  : 'No se pudo conectar con este backend. Revisa tu conexión o elige otro backend abajo.',
            );

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
                      style: const TextStyle(
                        fontSize: FncFonts.size22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      cardSub,
                      style: Theme.of(context).textTheme.bodyMedium,
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
                      message: _isEnglish
                          ? 'Username or email is required'
                          : 'El usuario o email es obligatorio',
                    ),
                    autocorrect: false,
                    textCapitalization: TextCapitalization.none,
                    decoration: InputDecoration(
                      labelText: fieldIdentifier,
                      border: const OutlineInputBorder(),
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
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: AppIconButton(
                        // Sin tooltip, un lector de pantalla anunciaba solo
                        // «botón»: ni qué hace ni si la contraseña está ya
                        // visible. Las cadenas llevaban traducidas desde el
                        // principio, sin que nadie las usara.
                        tooltip: _showPassword
                            ? _txt(
                                t,
                                'hide_password',
                                _isEnglish
                                    ? 'Hide password'
                                    : 'Ocultar contraseña',
                              )
                            : _txt(
                                t,
                                'show_password',
                                _isEnglish
                                    ? 'Show password'
                                    : 'Mostrar contraseña',
                              ),
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
                        onTap: () => refresh(
                          () => _rememberAccount = !_rememberAccount,
                        ),
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
                      onPressed: (_loading || backendDown) ? null : _submit,
                      child: Text(_loading ? loginBtnLoading : loginBtn),
                    ),
                  ),
                  if (_errorMessage != null) ...[
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
                        _errorMessage!,
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
                          if (_oauthGoogleEnabled)
                            const _OauthButton(
                              label: 'Google',
                              icon: FaIcon(FontAwesomeIcons.google, size: 17),
                            ),
                          if (_oauthAppleEnabled)
                            const _OauthButton(
                              label: 'Apple',
                              icon: FaIcon(FontAwesomeIcons.apple, size: 18),
                            ),
                          if (_oauthMicrosoftEnabled)
                            const _OauthButton(
                              label: 'Microsoft',
                              icon: FaIcon(
                                FontAwesomeIcons.microsoft,
                                size: 17,
                              ),
                            ),
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
                          onPressed: (_loading || backendDown)
                              ? null
                              : _submitGuest,
                          child: Text(_loading ? guestLoading : guestLogin),
                        ),
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
                              style: Theme.of(context).textTheme.bodySmall,
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
