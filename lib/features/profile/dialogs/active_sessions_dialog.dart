import 'package:flutter/material.dart';

import '../../../app/theme/fnc_colors.dart';
import '../../../app/theme/fnc_fonts.dart';
import '../../../models/profile/profile_models.dart';
import '../../../shared/widgets/buttons/action_icon_button.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/responsive_dialog.dart';
import '../../../shared/widgets/state_messaging_mixin.dart';
import '../repositories/profile_repository.dart';

/// Sesiones abiertas del usuario, con la opción de cerrarlas.
///
/// Es lo que convierte la revocación en algo que el usuario puede usar: el
/// backend sabe cerrar una sesión desde que existe la tabla `sessions`, pero
/// sin esta pantalla la única forma de echar a un acceso ajeno seguía siendo
/// cambiar la contraseña. Ver docs/adr/008-sesiones-revocables.md en
/// `backend_fastapi`.
Future<void> showActiveSessionsDialog({
  required BuildContext context,
  required ProfileRepository repository,
  required String token,
  required String Function(String path, String fallback) tx,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) =>
        _ActiveSessionsDialog(repository: repository, token: token, tx: tx),
  );
}

class _ActiveSessionsDialog extends StatefulWidget {
  const _ActiveSessionsDialog({
    required this.repository,
    required this.token,
    required this.tx,
  });

  final ProfileRepository repository;
  final String token;
  final String Function(String path, String fallback) tx;

  @override
  State<_ActiveSessionsDialog> createState() => _ActiveSessionsDialogState();
}

class _ActiveSessionsDialogState extends State<_ActiveSessionsDialog>
    with StateMessaging {
  List<ActiveSession> _sessions = const [];
  bool _loading = true;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final sessions = await widget.repository.listSessions(widget.token);
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      showMessage(
        widget.tx('profile.sessions_error', 'No se pudieron cargar las sesiones'),
        isError: true,
      );
    }
  }

  Future<void> _revoke(ActiveSession session) async {
    setState(() => _working = true);
    try {
      await widget.repository.revokeSession(widget.token, session.id);
      showMessage(widget.tx('profile.sessions_closed', 'Sesión cerrada'));
      await _load();
    } catch (_) {
      showMessage(
        widget.tx('profile.sessions_close_error', 'No se pudo cerrar la sesión'),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _revokeOthers() async {
    setState(() => _working = true);
    try {
      await widget.repository.revokeOtherSessions(widget.token);
      showMessage(
        widget.tx(
          'profile.sessions_others_closed',
          'Se han cerrado las demás sesiones',
        ),
      );
      await _load();
    } catch (_) {
      showMessage(
        widget.tx('profile.sessions_close_error', 'No se pudo cerrar la sesión'),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final otras = _sessions.where((s) => !s.current).length;

    return AlertDialog(
      title: Text(widget.tx('profile.sessions_title', 'Sesiones activas')),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      content: SizedBox(
        width: dialogContentWidth(context, 480),
        child: _loading
            ? const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < _sessions.length; i++) ...[
                      if (i > 0) const Divider(height: 20),
                      _fila(_sessions[i]),
                    ],
                    if (otras == 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.tx(
                          'profile.sessions_empty',
                          'No hay otras sesiones abiertas',
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        if (otras > 0)
          DangerButton(
            onPressed: _working ? null : _revokeOthers,
            child: Text(
              widget.tx(
                'profile.sessions_close_others',
                'Cerrar las demás sesiones',
              ),
            ),
          ),
        TertiaryButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.tx('common.close', 'Cerrar')),
        ),
      ],
    );
  }

  Widget _fila(ActiveSession session) {
    final scheme = Theme.of(context).colorScheme;
    final origen = [
      session.ip,
      session.userAgent,
    ].where((v) => v != null && v.isNotEmpty).join(' · ');

    return Row(
      children: [
        Icon(
          session.current ? Icons.verified_user_outlined : Icons.devices_other,
          size: 20,
          color: session.current ? FncColors.teal : scheme.onSurfaceVariant,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                origen.isEmpty
                    ? widget.tx(
                        'profile.sessions_unknown_origin',
                        'Origen desconocido',
                      )
                    : origen,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: FncFonts.size13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${widget.tx('profile.sessions_last_seen', 'Última actividad')}: '
                '${_fecha(session.lastSeenAt ?? session.createdAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (session.current)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.tx('profile.sessions_current', 'Esta sesión'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else
          ActionIconButton(
            icon: Icons.logout,
            tooltip: widget.tx('profile.sessions_close', 'Cerrar sesión'),
            danger: true,
            onPressed: _working ? null : () => _revoke(session),
          ),
      ],
    );
  }

  /// Fecha legible sin traer una dependencia de formato: el backend devuelve
  /// ISO-8601 y aquí basta con recortar los segundos y la zona.
  String _fecha(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    final local = parsed.toLocal();
    String dos(int v) => v.toString().padLeft(2, '0');
    return '${dos(local.day)}/${dos(local.month)}/${local.year} '
        '${dos(local.hour)}:${dos(local.minute)}';
  }
}
