import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/widgets/buttons/app_buttons.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/fnc_colors.dart';
import '../../../app/theme/fnc_fonts.dart';
import '../../../core/network/api_error.dart';
import '../../../core/storage/local_store.dart';
import '../../../models/github/github_device_flow.dart';
import '../../../shared/i18n/locale_loader.dart';
import '../repositories/auth_repository.dart';
import '../../../shared/state/backend_controller.dart';
import '../../../shared/state/boot_platform_cache.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/state/theme_controller.dart';
import '../../../shared/widgets/responsive_dialog.dart';
import '../../../utils/safe_redirect.dart';
import '../../../utils/validators.dart';

part '../widgets/login_form.dart';
part '../widgets/login_github_dialog.dart';
part '../widgets/login_hero.dart';
part '../widgets/login_support_widgets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    required this.backendController,
    required this.sessionController,
    required this.localeController,
    required this.authRepository,
    this.redirectTo,
    super.key,
  });

  final BackendController backendController;
  final SessionController sessionController;
  final LocaleController localeController;
  final AuthRepository authRepository;
  final String? redirectTo;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _showPassword = false;
  bool _rememberAccount = false;
  String? _errorMessage;
  late Future<Map<String, dynamic>> _authTextsFuture;
  bool _platformLoaded = false;
  bool _guestEnabled = false;
  bool _showRegister = false;
  bool _oauthGoogleEnabled = false;
  bool _oauthAppleEnabled = false;
  bool _oauthMicrosoftEnabled = false;
  bool _oauthGithubEnabled = false;
  _BackendStatus _backendStatus = _BackendStatus.checking;

  static const _rememberedAccountKey = 'remembered_account';

  bool get _isEnglish => widget.localeController.isEnglish;

  @override
  void initState() {
    super.initState();
    _authTextsFuture = LocaleLoader.load(
      isEnglish: _isEnglish,
      namespace: 'auth',
    );
    widget.localeController.addListener(_onLocaleChanged);
    widget.backendController.addListener(_onBackendConnectivityChanged);
    _loadPlatformSettings();
    _loadRememberedAccount();
  }

  void _onLocaleChanged() {
    if (!mounted) return;
    setState(
      () => _authTextsFuture = LocaleLoader.load(
        isEnglish: _isEnglish,
        namespace: 'auth',
      ),
    );
  }

  // El chequeo inicial (_loadPlatformSettings) solo toma una foto puntual del
  // backend. Sin esto, si la conexión se cae DESPUÉS (p.ej. al intentar
  // entrar) el LED se queda en verde aunque ApiClient ya haya reportado el
  // fallo a BackendController. Reflejamos aquí esa señal en vivo.
  void _onBackendConnectivityChanged() {
    if (!mounted || !_platformLoaded) return;
    final next = widget.backendController.hasConnectionIssue
        ? _BackendStatus.down
        : _BackendStatus.ok;
    if (next != _backendStatus) {
      setState(() => _backendStatus = next);
    }
  }

  Future<void> _loadRememberedAccount() async {
    final prefs = await LocalStore.instance();
    final rememberedAccount =
        prefs.getString(_rememberedAccountKey) ??
        prefs.getString('remembered_email');
    if (!mounted || rememberedAccount == null || rememberedAccount.isEmpty) {
      return;
    }
    setState(() {
      _identifierController.text = rememberedAccount;
      _rememberAccount = true;
    });
  }

  Future<void> _persistRememberedAccount() async {
    final prefs = await LocalStore.instance();
    if (_rememberAccount) {
      await prefs.setString(
        _rememberedAccountKey,
        _identifierController.text.trim(),
      );
      await prefs.remove('remembered_email');
    } else {
      await prefs.remove(_rememberedAccountKey);
      await prefs.remove('remembered_email');
    }
  }

  @override
  void dispose() {
    widget.localeController.removeListener(_onLocaleChanged);
    widget.backendController.removeListener(_onBackendConnectivityChanged);
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadPlatformSettings() async {
    final cached = BootPlatformCache.consume();
    if (cached != null) {
      _applyPlatformResult(cached.platform, cached.reachable);
      return;
    }

    if (mounted) {
      setState(() {
        _platformLoaded = false;
        _backendStatus = _BackendStatus.checking;
      });
    }
    try {
      final platform = await widget.authRepository.platformPublic();
      _applyPlatformResult(platform, true);
    } catch (_) {
      _applyPlatformResult(null, false);
    }
  }

  void _applyPlatformResult(Map<String, dynamic>? platform, bool reachable) {
    if (!mounted) return;
    if (reachable && platform != null) {
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
        _oauthGithubEnabled = platform['oauth_github_enabled'] == true;
      });
      unawaited(
        ThemeControllerScope.of(
          context,
          listen: false,
        ).syncFromBackend(platform['default_theme'] as String?),
      );
    } else {
      setState(() {
        _platformLoaded = true;
        _backendStatus = _BackendStatus.down;
        _guestEnabled = false;
        _showRegister = false;
        _oauthGoogleEnabled = false;
        _oauthAppleEnabled = false;
        _oauthMicrosoftEnabled = false;
        _oauthGithubEnabled = false;
      });
    }
  }

  void _toggleLanguage() {
    widget.localeController.setEnglish(!_isEnglish);
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

  bool get _showAnyOauth =>
      _oauthGoogleEnabled ||
      _oauthAppleEnabled ||
      _oauthMicrosoftEnabled ||
      _oauthGithubEnabled;

  Future<void> _syncUserSettings(
    String token,
    ThemeController themeController,
  ) async {
    try {
      final settings = await widget.authRepository.getSettings(token);
      await widget.localeController.syncFromBackend(
        settings['language'] as String?,
      );
      await themeController.syncFromBackend(settings['theme'] as String?);
    } catch (_) {
      // El login sigue siendo válido aunque fallen preferencias no críticas.
    }
  }

  Future<void> _submit() async {
    final themeController = ThemeControllerScope.of(context, listen: false);
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final texts = await _authTextsFuture;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final (result, token) = await widget.authRepository.login(
        identifier: _identifierController.text,
        password: _passwordController.text,
      );
      if (!result.ok) {
        throw ApiError(
          statusCode: 401,
          message: _txt(texts, 'error_invalid', 'Credenciales incorrectas'),
        );
      }

      final me = await widget.authRepository.me(token);
      widget.authRepository.clearCache();
      await widget.sessionController.login(
        token: token,
        user: me,
        remember: _rememberAccount,
      );
      await _persistRememberedAccount();
      unawaited(_syncUserSettings(token, themeController));

      if (!mounted) return;
      final destination = safeRedirect(widget.redirectTo);
      context.go(destination);
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _errorMessage = _txt(
          texts,
          'error_connection',
          'Error de conexión',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// Login con GitHub (OAuth Device Flow): abre el diálogo, que hace todo el
  /// intercambio y sondeo por su cuenta y devuelve el resultado ya listo
  /// para abrir sesión — mismos pasos finales que [_submit] tras un login
  /// por contraseña.
  Future<void> _loginWithGithub() async {
    final themeController = ThemeControllerScope.of(context, listen: false);
    final texts = await _authTextsFuture;
    String tx(String path, String fallback) => _txt(texts, path, fallback);

    if (!mounted) return;
    final result = await showDialog<GithubLoginPollResult>(
      context: context,
      builder: (context) =>
          _GithubLoginDialog(authRepository: widget.authRepository, tx: tx),
    );
    if (result == null || !result.isReady) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final token = result.gaToken!;
      final me = await widget.authRepository.me(token);
      widget.authRepository.clearCache();
      await widget.sessionController.login(
        token: token,
        user: me,
        remember: true,
      );
      unawaited(_syncUserSettings(token, themeController));
      if (!mounted) return;
      final destination = safeRedirect(widget.redirectTo);
      context.go(destination);
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _errorMessage = tx('error_connection', 'Error de conexión'),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitGuest() async {
    final themeController = ThemeControllerScope.of(context, listen: false);
    final texts = await _authTextsFuture;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final (result, token) = await widget.authRepository.guestLogin();
      if (!result.ok) {
        throw ApiError(
          statusCode: 401,
          message: _txt(
            texts,
            'guest_error',
            'No fue posible iniciar como invitado',
          ),
        );
      }

      final me = await widget.authRepository.me(token);
      await widget.sessionController.login(
        token: token,
        user: me,
        remember: false,
      );
      await _syncUserSettings(token, themeController);
      if (!mounted) return;
      final destination = safeRedirect(widget.redirectTo);
      context.go(destination);
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _errorMessage = _txt(
          texts,
          'guest_error',
          'No se pudo iniciar como invitado',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _refresh(VoidCallback update) => setState(update);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1000;
            final formArea = Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 56, 24, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: _buildFormCard(context),
                ),
              ),
            );

            if (!wide) {
              return SingleChildScrollView(
                key: const Key('login-mobile-layout'),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: TertiaryButton(
                            onPressed: _toggleLanguage,
                            child: Text(_isEnglish ? 'ES' : 'EN'),
                          ),
                        ),
                        _buildHeroPanel(context, compact: true),
                        _buildFormCard(context),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Stack(
              key: const Key('login-desktop-layout'),
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1360),
                      child: Row(
                        children: [
                          Expanded(flex: 5, child: _buildHeroPanel(context)),
                          const SizedBox(width: 48),
                          Expanded(flex: 6, child: formArea),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 16,
                  child: TertiaryButton(
                    onPressed: _toggleLanguage,
                    child: Text(_isEnglish ? 'ES' : 'EN'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
