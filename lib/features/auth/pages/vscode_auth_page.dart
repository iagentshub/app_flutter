import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/fnc_colors.dart';
import '../../../app/theme/fnc_fonts.dart';
import '../../../core/network/api_error.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/app_services_scope.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../repositories/auth_repository.dart';

const _vsCodeSchemes = {
  'vscode',
  'vscode-insiders',
  'vscodium',
  'cursor',
  'windsurf',
};
const _vsCodeAuthority = 'iagentshub.iagentshub';

Uri? _safeCallback(String? value) {
  if (value == null || value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri == null) return null;
  if (!_vsCodeSchemes.contains(uri.scheme) ||
      uri.authority != _vsCodeAuthority) {
    return null;
  }
  return uri;
}

class VsCodeAuthPage extends StatefulWidget {
  const VsCodeAuthPage({
    required this.authRepository,
    this.state,
    this.callback,
    super.key,
  });

  final AuthRepository authRepository;
  final String? state;
  final String? callback;

  @override
  State<VsCodeAuthPage> createState() => _VsCodeAuthPageState();
}

class _VsCodeAuthPageState extends State<VsCodeAuthPage> {
  /// Servicios globales (cliente HTTP, sesión, idioma): los aporta el
  /// AppServicesScope montado en App, no el router.
  late final _services = AppServicesScope.of(context);

  bool _loading = false;
  bool _done = false;
  String? _error;
  late final TranslatedTexts _t;

  Uri? get _target => _safeCallback(widget.callback);

  @override
  void initState() {
    super.initState();
    _t = TranslatedTexts(
      localeController: _services.localeController,
      namespace: 'auth',
    )..addListener(_onTextsChanged);
  }

  void _onTextsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _t.removeListener(_onTextsChanged);
    _t.dispose();
    super.dispose();
  }

  String _tx(String path) => _t.text(path);

  Future<void> _authorize() async {
    final token = _services.sessionController.gaToken;
    final state = widget.state;
    final target = _target;
    if (token == null || state == null || target == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final code = await widget.authRepository.authorizeVsCode(
        token,
        state: state,
      );
      final destination = target.replace(
        queryParameters: {
          ...target.queryParameters,
          'code': code,
          'state': state,
        },
      );
      if (!mounted) return;
      setState(() => _done = true);
      await launchUrl(destination, mode: LaunchMode.externalApplication);
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = _tx('vscode_auth.error_generic'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = _target;
    final state = widget.state;

    Widget body;
    if (target == null || state == null || state.isEmpty) {
      body = Text(_tx('vscode_auth.invalid_link'));
    } else if (_done) {
      body = Text(_tx('vscode_auth.done_message'));
    } else {
      final username = _services.sessionController.user?.username ?? '';
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _tx('vscode_auth.connect_prompt')
                .replaceAll('{{username}}', username),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: FncColors.materialRed.shade700),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              PrimaryButton(
                onPressed: _loading ? null : _authorize,
                child: Text(
                  _loading
                      ? _tx('vscode_auth.authorize_btn_loading')
                      : _tx('vscode_auth.authorize_btn'),
                ),
              ),
              const SizedBox(width: 8),
              TertiaryButton(
                onPressed: _loading
                    ? null
                    : () => Navigator.of(context).maybePop(),
                child: Text(_tx('vscode_auth.cancel_btn')),
              ),
            ],
          ),
        ],
      );
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _tx('vscode_auth.title'),
                    style: const TextStyle(
                      fontSize: FncFonts.size20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  body,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
