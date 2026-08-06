import 'package:flutter/material.dart';

import '../../../shared/widgets/buttons/app_buttons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/fnc_colors.dart';
import '../../../app/theme/fnc_fonts.dart';
import '../../../core/network/api_error.dart';
import '../../../shared/i18n/locale_loader.dart';
import '../../../shared/state/locale_controller.dart';
import '../repositories/auth_repository.dart';
import '../../../shared/state/session_controller.dart';

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
    required this.sessionController,
    required this.localeController,
    this.state,
    this.callback,
    super.key,
  });

  final AuthRepository authRepository;
  final SessionController sessionController;
  final LocaleController localeController;
  final String? state;
  final String? callback;

  @override
  State<VsCodeAuthPage> createState() => _VsCodeAuthPageState();
}

class _VsCodeAuthPageState extends State<VsCodeAuthPage> {
  bool _loading = false;
  bool _done = false;
  String? _error;
  late Future<Map<String, dynamic>> _textsFuture;

  bool get _isEnglish => widget.localeController.isEnglish;

  Uri? get _target => _safeCallback(widget.callback);

  @override
  void initState() {
    super.initState();
    _textsFuture = LocaleLoader.load(isEnglish: _isEnglish, namespace: 'auth');
    widget.localeController.addListener(_onLocaleChanged);
  }

  void _onLocaleChanged() {
    if (!mounted) return;
    setState(
      () => _textsFuture = LocaleLoader.load(
        isEnglish: _isEnglish,
        namespace: 'auth',
      ),
    );
  }

  @override
  void dispose() {
    widget.localeController.removeListener(_onLocaleChanged);
    super.dispose();
  }

  String _txt(Map<String, dynamic> bundle, String path, String fallback) {
    return LocaleLoader.text(bundle, path, fallback: fallback);
  }

  Future<void> _authorize(Map<String, dynamic> t) async {
    final token = widget.sessionController.gaToken;
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
      setState(
        () => _error = _txt(
          t,
          'vscode_auth.error_generic',
          'No se pudo autorizar la conexión',
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _textsFuture,
      builder: (context, snapshot) {
        final t = snapshot.data ?? const {};
        final target = _target;
        final state = widget.state;

        Widget body;
        if (target == null || state == null || state.isEmpty) {
          body = Text(
            _txt(
              t,
              'vscode_auth.invalid_link',
              'Enlace de autorización inválido o incompleto.',
            ),
          );
        } else if (_done) {
          body = Text(
            _txt(
              t,
              'vscode_auth.done_message',
              'Autorización completada. Puedes volver a tu editor.',
            ),
          );
        } else {
          final username = widget.sessionController.user?.username ?? '';
          body = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _txt(
                  t,
                  'vscode_auth.connect_prompt',
                  'Vas a conectar tu editor con la cuenta de {{username}}.',
                ).replaceAll('{{username}}', username),
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
                    onPressed: _loading ? null : () => _authorize(t),
                    child: Text(
                      _loading
                          ? _txt(
                              t,
                              'vscode_auth.authorize_btn_loading',
                              'Autorizando…',
                            )
                          : _txt(t, 'vscode_auth.authorize_btn', 'Autorizar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TertiaryButton(
                    onPressed: _loading
                        ? null
                        : () => Navigator.of(context).maybePop(),
                    child: Text(_txt(t, 'vscode_auth.cancel_btn', 'Cancelar')),
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
                        _txt(t, 'vscode_auth.title', 'Autorizar VS Code'),
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
      },
    );
  }
}
