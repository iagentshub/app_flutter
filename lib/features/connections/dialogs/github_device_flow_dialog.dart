part of '../widgets/providers_section.dart';

/// Login con GitHub vía OAuth Device Flow: en vez de pegar un Personal
/// Access Token a mano, el usuario visita una URL, introduce un código y
/// autoriza el acceso desde su navegador — este diálogo sondea hasta que
/// GitHub confirma la autorización y devuelve el access_token resultante
/// (`Navigator.pop(accessToken)`), o `null` si se cancela.
class _GithubDeviceFlowDialog extends StatefulWidget {
  const _GithubDeviceFlowDialog({
    required this.apiClient,
    required this.token,
    required this.tx,
  });

  final ApiClient apiClient;
  final String token;
  final String Function(String path) tx;

  @override
  State<_GithubDeviceFlowDialog> createState() =>
      _GithubDeviceFlowDialogState();
}

class _GithubDeviceFlowDialogState extends State<_GithubDeviceFlowDialog> {
  late final AccountsRepository _repository;
  GithubDeviceCode? _code;
  String? _error;
  bool _loading = true;
  Timer? _pollTimer;
  DateTime? _expiresAt;

  @override
  void initState() {
    super.initState();
    _repository = AccountsRepository(apiClient: widget.apiClient);
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
      final code = await _repository.startGithubDeviceFlow(widget.token);
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
        _error = widget.tx('providers.github_start_error');
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
      setState(() => _error = widget.tx('providers.github_code_expired'));
      return;
    }
    try {
      final result = await _repository.pollGithubDeviceToken(
        widget.token,
        code.deviceCode,
      );
      if (!mounted) return;
      if (result.ok) {
        Navigator.of(context).pop(result.accessToken);
        return;
      }
      if (result.pending) {
        _schedulePoll(result.slowDown ? code.interval + 5 : code.interval);
        return;
      }
      setState(() => _error = _githubErrorMessage(result.error));
    } catch (_) {
      if (!mounted) return;
      _schedulePoll(code.interval);
    }
  }

  String _githubErrorMessage(String? error) {
    switch (error) {
      case 'expired_token':
        return widget.tx('providers.github_code_expired');
      case 'access_denied':
        return widget.tx('providers.github_access_denied');
      default:
        return widget.tx('providers.github_start_error');
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
      SnackBar(content: Text(widget.tx('providers.github_code_copied'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.tx('providers.github_connect_title')),
      content: SizedBox(
        width: dialogContentWidth(context, 380),
        child: _buildBody(),
      ),
      actions: [
        TertiaryButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.tx('common.cancel')),
        ),
        if (_error != null)
          PrimaryButton(
            onPressed: _start,
            child: Text(widget.tx('common.retry')),
          ),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const SizedBox(
        height: 80,
        child: Center(child: IAgentsLoadingMark()),
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
        Text(widget.tx('providers.github_device_hint')),
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
          label: Text(widget.tx('providers.github_open_action')),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const SizedBox(width: 16, height: 16, child: IAgentsLoadingMark()),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.tx('providers.github_waiting'),
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
