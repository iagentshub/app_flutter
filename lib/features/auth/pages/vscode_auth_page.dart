import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_error.dart';
import '../repositories/auth_repository.dart';
import '../../../shared/state/session_controller.dart';

const _vsCodeSchemes = {'vscode', 'vscode-insiders', 'vscodium', 'cursor', 'windsurf'};
const _vsCodeAuthority = 'iagentshub.iagentshub';

Uri? _safeCallback(String? value) {
  if (value == null || value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri == null) return null;
  if (!_vsCodeSchemes.contains(uri.scheme) || uri.authority != _vsCodeAuthority) return null;
  return uri;
}

class VsCodeAuthPage extends StatefulWidget {
  const VsCodeAuthPage({
    required this.authRepository,
    required this.sessionController,
    this.state,
    this.callback,
    super.key,
  });

  final AuthRepository authRepository;
  final SessionController sessionController;
  final String? state;
  final String? callback;

  @override
  State<VsCodeAuthPage> createState() => _VsCodeAuthPageState();
}

class _VsCodeAuthPageState extends State<VsCodeAuthPage> {
  bool _loading = false;
  bool _done = false;
  String? _error;

  Uri? get _target => _safeCallback(widget.callback);

  Future<void> _authorize() async {
    final token = widget.sessionController.gaToken;
    final state = widget.state;
    final target = _target;
    if (token == null || state == null || target == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final code = await widget.authRepository.authorizeVsCode(token, state: state);
      final destination = target.replace(queryParameters: {
        ...target.queryParameters,
        'code': code,
        'state': state,
      });
      if (!mounted) return;
      setState(() => _done = true);
      await launchUrl(destination, mode: LaunchMode.externalApplication);
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo autorizar la conexión');
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
      body = const Text('Enlace de autorización inválido o incompleto.');
    } else if (_done) {
      body = const Text('Autorización completada. Puedes volver a tu editor.');
    } else {
      final username = widget.sessionController.user?.username ?? '';
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Vas a conectar tu editor con la cuenta de $username.'),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Colors.red.shade700)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton(
                onPressed: _loading ? null : _authorize,
                child: Text(_loading ? 'Autorizando…' : 'Autorizar'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _loading ? null : () => Navigator.of(context).maybePop(),
                child: const Text('Cancelar'),
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
                  const Text('Autorizar VS Code', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
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
