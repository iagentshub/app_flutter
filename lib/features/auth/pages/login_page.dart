import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/router/route_names.dart';
import '../../../core/network/api_error.dart';
import '../../../core/storage/local_store.dart';
import '../../../shared/i18n/locale_loader.dart';
import '../repositories/auth_repository.dart';
import '../../../shared/state/backend_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../../../utils/safe_redirect.dart';
import '../../../utils/validators.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    required this.backendController,
    required this.sessionController,
    required this.authRepository,
    this.redirectTo,
    super.key,
  });

  final BackendController backendController;
  final SessionController sessionController;
  final AuthRepository authRepository;
  final String? redirectTo;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _showPassword = false;
  bool _isEnglish = false;
  bool _rememberAccount = false;
  String? _errorMessage;
  late Future<Map<String, dynamic>> _authTextsFuture;
  bool _platformLoaded = false;
  bool _guestEnabled = false;
  bool _showRegister = false;
  bool _oauthGoogleEnabled = false;
  bool _oauthAppleEnabled = false;
  bool _oauthMicrosoftEnabled = false;
  _BackendStatus _backendStatus = _BackendStatus.checking;

  static const _rememberedEmailKey = 'remembered_email';

  @override
  void initState() {
    super.initState();
    _authTextsFuture = LocaleLoader.load(isEnglish: _isEnglish, namespace: 'auth');
    _loadPlatformSettings();
    _loadRememberedAccount();
  }

  Future<void> _loadRememberedAccount() async {
    final prefs = await LocalStore.instance();
    final rememberedEmail = prefs.getString(_rememberedEmailKey);
    if (!mounted || rememberedEmail == null || rememberedEmail.isEmpty) return;
    setState(() {
      _emailController.text = rememberedEmail;
      _rememberAccount = true;
    });
  }

  Future<void> _persistRememberedAccount() async {
    final prefs = await LocalStore.instance();
    if (_rememberAccount) {
      await prefs.setString(_rememberedEmailKey, _emailController.text.trim());
    } else {
      await prefs.remove(_rememberedEmailKey);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadPlatformSettings() async {
    if (mounted) {
      setState(() {
        _platformLoaded = false;
        _backendStatus = _BackendStatus.checking;
      });
    }
    try {
      final platform = await widget.authRepository.platformPublic();
      if (!mounted) return;

      final registration = (platform['registration'] ?? '').toString();
      final billingEnabled = platform['billing_enabled'] == true;
      setState(() {
        _platformLoaded = true;
        _backendStatus = _BackendStatus.ok;
        _guestEnabled = platform['guest_enabled'] == true;
        _showRegister = registration == 'open' && !billingEnabled;
        _oauthGoogleEnabled = platform['oauth_google_enabled'] != false;
        _oauthAppleEnabled = platform['oauth_apple_enabled'] != false;
        _oauthMicrosoftEnabled = platform['oauth_microsoft_enabled'] != false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _platformLoaded = true;
        _backendStatus = _BackendStatus.down;
        _guestEnabled = false;
        _showRegister = false;
        _oauthGoogleEnabled = false;
        _oauthAppleEnabled = false;
        _oauthMicrosoftEnabled = false;
      });
    }
  }

  void _toggleLanguage() {
    setState(() {
      _isEnglish = !_isEnglish;
      _authTextsFuture = LocaleLoader.load(isEnglish: _isEnglish, namespace: 'auth');
    });
  }

  String _txt(Map<String, dynamic> bundle, String path, String fallback) {
    return LocaleLoader.text(bundle, path, fallback: fallback);
  }

  Future<void> _openBackendConfig() async {
    await context.push(RouteNames.backendConfig);
    if (!mounted) return;
    await _loadPlatformSettings();
    setState(() {});
  }

  bool get _showAnyOauth => _oauthGoogleEnabled || _oauthAppleEnabled || _oauthMicrosoftEnabled;

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final texts = await _authTextsFuture;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final (result, token) = await widget.authRepository.login(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!result.ok) {
        throw ApiError(statusCode: 401, message: _txt(texts, 'error_invalid', 'Credenciales incorrectas'));
      }

      final me = await widget.authRepository.me(token);
      await widget.sessionController.login(token: token, user: me);
      await _persistRememberedAccount();

      if (!mounted) return;
      final destination = safeRedirect(widget.redirectTo);
      context.go(destination);
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = _txt(texts, 'error_connection', 'Error de conexión'));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _submitGuest() async {
    final texts = await _authTextsFuture;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final (result, token) = await widget.authRepository.guestLogin();
      if (!result.ok) {
        throw ApiError(statusCode: 401, message: _txt(texts, 'guest_error', 'No fue posible iniciar como invitado'));
      }

      final me = await widget.authRepository.me(token);
      await widget.sessionController.login(token: token, user: me);
      if (!mounted) return;
      final destination = safeRedirect(widget.redirectTo);
      context.go(destination);
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = _txt(texts, 'guest_error', 'No se pudo iniciar como invitado'));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                final formCard = Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: _buildFormCard(context),
                    ),
                  ),
                );

                if (!wide) return formCard;

                return Row(
                  children: [
                    Expanded(child: _buildHeroPanel(context)),
                    Expanded(child: formCard),
                  ],
                );
              },
            ),
            Positioned(
              top: 8,
              right: 8,
              child: TextButton(
                onPressed: _toggleLanguage,
                child: Text(_isEnglish ? 'ES' : 'EN'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroPanel(BuildContext context) {
    return Container(
      color: const Color(0xFF0B0B0B),
      padding: const EdgeInsets.all(48),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _authTextsFuture,
        builder: (context, snapshot) {
          final t = snapshot.data ?? const {};
          final headlinePre = _txt(t, 'headline_pre', _isEnglish ? 'in' : 'en');
          final headline1 = _txt(t, 'headline_1', _isEnglish ? 'All your AI' : 'Toda tu IA');
          final headlineAccent = _txt(t, 'headline_accent', _isEnglish ? 'one place' : 'un solo lugar');
          final heroSub = _txt(
            t,
            'hero_sub',
            _isEnglish
                ? 'Agents, knowledge, workflows and connections — from your phone, your desktop, or the web.'
                : 'Agentes, conocimiento, workflows y conexiones — desde tu móvil, tu escritorio o la web.',
          );

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _BrandMark(scale: 1.6),
              const SizedBox(height: 24),
              Text(
                '$headline1 $headlinePre\n$headlineAccent',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, height: 1.2, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                heroSub,
                style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.7), height: 1.5),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFormCard(BuildContext context) {
    return Card(
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
            final cardTitle = _txt(t, 'card_title', _isEnglish ? 'Welcome' : 'Bienvenido');
            final cardSub = _txt(t, 'card_sub', _isEnglish ? 'Access your agent workspace' : 'Accede a tu espacio de agentes');
            final fieldEmail = _txt(t, 'field_email', 'Email');
            final fieldPassword = _txt(t, 'field_password', _isEnglish ? 'Password' : 'Contraseña');
            final loginBtn = _txt(t, 'login_btn', _isEnglish ? 'Sign in' : 'Entrar');
            final loginBtnLoading = _txt(t, 'login_btn_loading', _isEnglish ? 'Signing in…' : 'Entrando…');
            final forgotPassword = _txt(t, 'forgot_password', _isEnglish ? 'Forgot your password?' : '¿Olvidaste tu contraseña?');
            final rememberAccount = _txt(t, 'remember_account', _isEnglish ? 'Remember my account' : 'Recordar mi cuenta');
            final divider = _txt(t, 'divider', _isEnglish ? 'or' : 'o');
            final guestLogin = _txt(t, 'guest_login', _isEnglish ? 'Access as guest' : 'Acceder como invitado');
            final guestLoading = _txt(t, 'guest_entering', _isEnglish ? 'Entering…' : 'Entrando…');
            final registerAction = _txt(t, 'register_action', _isEnglish ? 'Create account' : 'Crear cuenta');
            final fieldPasswordRequired = _txt(
              t,
              'field_password_required',
              _isEnglish ? 'Password is required' : 'La contraseña es obligatoria',
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
                  const Center(child: _BrandMark()),
                  const SizedBox(height: 14),
                  Center(
                    child: Text(cardTitle, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(cardSub, style: Theme.of(context).textTheme.bodyMedium),
                  ),
                  const SizedBox(height: 24),

                  if (backendDown) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _StatusLed(status: _BackendStatus.down),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(backendDownMsg, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // -- Credenciales --------------------------------------------------
                  TextFormField(
                    controller: _emailController,
                    validator: Validators.email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: fieldEmail,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.mail_outline, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_showPassword,
                    validator: (value) => Validators.requiredField(value, message: fieldPasswordRequired),
                    decoration: InputDecoration(
                      labelText: fieldPassword,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _showPassword = !_showPassword),
                        icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: () => setState(() => _rememberAccount = !_rememberAccount),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: _rememberAccount,
                                  onChanged: (value) => setState(() => _rememberAccount = value ?? false),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(rememberAccount, style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go(RouteNames.forgotPassword),
                        child: Text(forgotPassword, style: Theme.of(context).textTheme.bodySmall),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // -- Acción principal ------------------------------------------------
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: (_loading || backendDown) ? null : _submit,
                      child: Text(_loading ? loginBtnLoading : loginBtn),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                      ),
                      child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                    ),
                  ],

                  // -- Accesos alternativos --------------------------------------------
                  if (_platformLoaded && (_showAnyOauth || _guestEnabled)) ...[
                    const SizedBox(height: 20),
                    _OauthDivider(text: divider),
                    const SizedBox(height: 14),
                    if (_showAnyOauth)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_oauthGoogleEnabled)
                            const _OauthButton(label: 'Google', icon: FaIcon(FontAwesomeIcons.google, size: 17)),
                          if (_oauthAppleEnabled)
                            const _OauthButton(label: 'Apple', icon: FaIcon(FontAwesomeIcons.apple, size: 18)),
                          if (_oauthMicrosoftEnabled)
                            const _OauthButton(label: 'Microsoft', icon: FaIcon(FontAwesomeIcons.microsoft, size: 17)),
                        ],
                      ),
                    if (_guestEnabled) ...[
                      if (_showAnyOauth) const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: (_loading || backendDown) ? null : _submitGuest,
                          child: Text(_loading ? guestLoading : guestLogin),
                        ),
                      ),
                    ],
                  ],
                  if (_platformLoaded && _showRegister) ...[
                    const SizedBox(height: 14),
                    Center(
                      child: TextButton(
                        onPressed: () => context.go(RouteNames.register),
                        child: Text(registerAction),
                      ),
                    ),
                  ],

                  // -- Pie: backend activo ----------------------------------------------
                  const SizedBox(height: 18),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  InkWell(
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
                          Icon(Icons.chevron_right, size: 16, color: Theme.of(context).textTheme.bodySmall?.color),
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
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelSmall,
          ),
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
        child: OutlinedButton(
          onPressed: null,
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            minimumSize: const Size(44, 44),
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(width: 8),
              Text(label),
            ],
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
                padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 2 * scale),
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
  WidgetSpan toWidgetSpan() => WidgetSpan(alignment: PlaceholderAlignment.middle, child: this);
}

enum _BackendStatus { checking, ok, down }

class _StatusLed extends StatefulWidget {
  const _StatusLed({required this.status});

  final _BackendStatus status;

  @override
  State<_StatusLed> createState() => _StatusLedState();
}

class _StatusLedState extends State<_StatusLed> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
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
          BoxShadow(color: color.withValues(alpha: opacity * 0.6), blurRadius: 5, spreadRadius: 1),
        ],
      ),
    );
  }
}
