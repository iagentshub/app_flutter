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
      });
    }
    try {
      final platform = await widget.authRepository.platformPublic();
      if (!mounted) return;

      final registration = (platform['registration'] ?? '').toString();
      final billingEnabled = platform['billing_enabled'] == true;
      setState(() {
        _platformLoaded = true;
        _guestEnabled = platform['guest_enabled'] == true;
        _showRegister = registration == 'open' && !billingEnabled;
        _oauthGoogleEnabled = platform['oauth_google_enabled'] != false;
        _oauthAppleEnabled = platform['oauth_apple_enabled'] != false;
        _oauthMicrosoftEnabled = platform['oauth_microsoft_enabled'] != false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _platformLoaded = true);
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
        throw ApiError(statusCode: 401, message: 'Credenciales incorrectas');
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
      setState(() => _errorMessage = _isEnglish
          ? 'Unable to connect to the selected backend'
          : 'No se pudo conectar con el backend seleccionado');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _submitGuest() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final (result, token) = await widget.authRepository.guestLogin();
      if (!result.ok) {
        throw ApiError(statusCode: 401, message: 'No fue posible iniciar como invitado');
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
      setState(() => _errorMessage = _isEnglish
          ? 'Could not sign in as guest'
          : 'No se pudo iniciar como invitado');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final backendLabel = widget.backendController.selectedOption.label;
    final backendUrl = widget.backendController.effectiveBaseUrl;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
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

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Spacer(),
                                TextButton(
                                  onPressed: _toggleLanguage,
                                  child: Text(_isEnglish ? 'ES' : 'EN'),
                                ),
                              ],
                            ),
                            const Center(child: _BrandMark()),
                            const SizedBox(height: 12),
                            Center(
                              child: Text(
                                cardTitle,
                                style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Center(
                              child: Text(
                                cardSub,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            const SizedBox(height: 18),
                            TextFormField(
                              controller: _emailController,
                              validator: Validators.email,
                              decoration: InputDecoration(
                                labelText: fieldEmail,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: !_showPassword,
                              validator: (value) => Validators.requiredField(
                                value,
                                message: _isEnglish ? 'Password is required' : 'La contraseña es obligatoria',
                              ),
                              decoration: InputDecoration(
                                labelText: fieldPassword,
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  onPressed: () => setState(() => _showPassword = !_showPassword),
                                  icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
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
                                  child: Text(forgotPassword),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _loading ? null : _submit,
                                child: Text(_loading ? loginBtnLoading : loginBtn),
                              ),
                            ),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.redAccent),
                              ),
                            ],
                            if (_platformLoaded && _showAnyOauth) ...[
                              const SizedBox(height: 12),
                              _OauthDivider(text: divider),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
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
                                      icon: FaIcon(FontAwesomeIcons.microsoft, size: 17),
                                    ),
                                ],
                              ),
                            ],
                            if (_platformLoaded && _guestEnabled) ...[
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: _loading ? null : _submitGuest,
                                  child: Text(_loading ? guestLoading : guestLogin),
                                ),
                              ),
                            ],
                            if (_platformLoaded && _showRegister) ...[
                              const SizedBox(height: 8),
                              Center(
                                child: TextButton(
                                  onPressed: () => context.go(RouteNames.register),
                                  child: Text(registerAction),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF141414),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF2F2F2F)),
                              ),
                              child: Text(
                                '${_isEnglish ? 'Backend' : 'Backend'}: $backendLabel\n$backendUrl',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _openBackendConfig,
                                icon: const Icon(Icons.settings_ethernet),
                                label: Text(_isEnglish ? 'Configure backend' : 'Configurar backend'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
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
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: const TextSpan(
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 22,
          letterSpacing: -0.2,
        ),
        children: [
          TextSpan(text: 'iAgents'),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: SizedBox(width: 6),
          ),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFFD90429),
                borderRadius: BorderRadius.all(Radius.circular(6)),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Text(
                  'HUB',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
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
