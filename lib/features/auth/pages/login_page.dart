import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/widgets/buttons/app_buttons.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/router/route_names.dart';
import '../../../core/network/api_error.dart';
import '../../../core/storage/local_store.dart';
import '../../../shared/i18n/locale_loader.dart';
import '../repositories/auth_repository.dart';
import '../../../shared/state/backend_controller.dart';
import '../../../shared/state/boot_platform_cache.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../../../utils/safe_redirect.dart';
import '../../../utils/validators.dart';

part '../widgets/login_form.dart';
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
      });
    } else {
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
      _oauthGoogleEnabled || _oauthAppleEnabled || _oauthMicrosoftEnabled;

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
      unawaited(
        widget.authRepository
            .getLanguage(token)
            .then(widget.localeController.syncFromBackend),
      );

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

  Future<void> _submitGuest() async {
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
            final wide = constraints.maxWidth >= 900;
            final formArea = Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: _buildFormCard(context),
                ),
              ),
            );

            final body = wide
                ? Row(
                    children: [
                      Expanded(child: _buildHeroPanel(context)),
                      Expanded(child: formArea),
                    ],
                  )
                : formArea;

            return Stack(
              children: [
                body,
                if (!wide)
                  const Positioned(top: 12, left: 16, child: _BrandMark()),
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
