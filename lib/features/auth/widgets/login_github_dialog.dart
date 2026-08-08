part of '../pages/login_page.dart';

/// Login con GitHub vía OAuth Device Flow, sin sesión previa. Mismo patrón
/// UX que `_GithubDeviceFlowDialog` en Connections (vincular cuenta
/// proveedor), pero aquí el resultado es abrir sesión en la app: al
/// autorizar, `Navigator.pop` devuelve el [GithubLoginPollResult] ya listo
/// para pasar a `SessionController.login`, o `null` si se cancela.
class _GithubLoginDialog extends StatefulWidget {
  const _GithubLoginDialog({required this.authRepository, required this.tx});

  final AuthRepository authRepository;
  final String Function(String path, String fallback) tx;

  @override
  State<_GithubLoginDialog> createState() => _GithubLoginDialogState();
}

class _GithubLoginDialogState extends State<_GithubLoginDialog> {
  GithubDeviceCode? _code;
  String? _error;
  bool _loading = true;
  Timer? _pollTimer;
  DateTime? _expiresAt;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final code = await widget.authRepository.startGithubLogin();
      if (!mounted) return;
      setState(() {
        _code = code;
        _loading = false;
        _expiresAt = DateTime.now().add(Duration(seconds: code.expiresIn));
      });
      _schedulePoll(code.interval);
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = widget.tx(
          'github_start_error',
          'No se pudo iniciar la conexión con GitHub',
        );
      });
    }
  }

  void _schedulePoll(int intervalSeconds) {
    _pollTimer?.cancel();
    _pollTimer = Timer(Duration(seconds: intervalSeconds), _poll);
  }

  Future<void> _poll() async {
    final code = _code;
    if (code == null || !mounted) return;
    final expiresAt = _expiresAt;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
      setState(
        () => _error = widget.tx(
          'github_code_expired',
          'El código expiró — inténtalo de nuevo',
        ),
      );
      return;
    }
    try {
      final result = await widget.authRepository.pollGithubLogin(
        code.deviceCode,
      );
      if (!mounted) return;
      if (result.isReady) {
        Navigator.of(context).pop(result);
        return;
      }
      if (result.tokenResult.pending) {
        _schedulePoll(
          result.tokenResult.slowDown ? code.interval + 5 : code.interval,
        );
        return;
      }
      setState(() => _error = _githubErrorMessage(result.tokenResult.error));
    } catch (_) {
      if (!mounted) return;
      _schedulePoll(code.interval);
    }
  }

  String _githubErrorMessage(String? error) {
    switch (error) {
      case 'expired_token':
        return widget.tx(
          'github_code_expired',
          'El código expiró — inténtalo de nuevo',
        );
      case 'access_denied':
        return widget.tx(
          'github_access_denied',
          'Autorización rechazada en GitHub',
        );
      default:
        return widget.tx(
          'github_start_error',
          'No se pudo iniciar la conexión con GitHub',
        );
    }
  }

  Future<void> _openGithub() async {
    final uri = Uri.tryParse(_code?.verificationUri ?? '');
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _copyCode() {
    final code = _code?.userCode;
    if (code == null || code.isEmpty) return;
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.tx('github_code_copied', 'Código copiado')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.tx('github_connect_title', 'Continuar con GitHub')),
      content: SizedBox(
        width: dialogContentWidth(context, 380),
        child: _buildBody(),
      ),
      actions: [
        TertiaryButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.tx('common_cancel', 'Cancelar')),
        ),
        if (_error != null)
          PrimaryButton(
            onPressed: _start,
            child: Text(widget.tx('common_retry', 'Reintentar')),
          ),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Text(
        _error!,
        style: TextStyle(color: FncColors.materialRed.shade700),
      );
    }
    final code = _code;
    if (code == null) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.tx(
            'github_device_hint',
            'Visita esta URL e introduce el código para autorizar el acceso:',
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _copyCode,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                code.userCode,
                style: const TextStyle(
                  fontSize: FncFonts.size22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SecondaryButton.icon(
          onPressed: _openGithub,
          icon: const Icon(Icons.open_in_new),
          label: Text(widget.tx('github_open_action', 'Abrir GitHub')),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.tx('github_waiting', 'Esperando autorización...'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
