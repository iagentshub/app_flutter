part of '../pages/admin_page.dart';

/// Tarjeta "Actualizaciones" del tab de Configuración — extraída de
/// _AdminConfigTab para mantener ambos archivos bajo el límite de 600 líneas
/// que exige feature_architecture_test.dart. Vive aparte porque ya era un
/// subsistema independiente: a diferencia del resto de campos de la pestaña
/// (que esperan al botón "Guardar"), el auto-update se aplica al instante y
/// el chequeo de versión no forma parte del payload de _AdminConfigTab._save().
class _AdminUpdatesCard extends StatefulWidget {
  const _AdminUpdatesCard({
    required this.repository,
    required this.token,
    required this.initialAutoUpdate,
    required this.autoUpdateAvailable,
    required this.tx,
  });

  final AdminPlatformRepository repository;
  final String token;
  final bool initialAutoUpdate;

  /// Si esta instalación puede gobernar Watchtower de verdad. En producción no
  /// puede: el despliegue fija un tag inmutable y deja "watchtower" y
  /// "docker-proxy" en el perfil `manual-updates`, sin arrancar. El
  /// interruptor salía igualmente encendido —lee la preferencia guardada, que
  /// por defecto es True— y solo confesaba con un 502 al tocarlo.
  final bool autoUpdateAvailable;
  final String Function(String path) tx;

  @override
  State<_AdminUpdatesCard> createState() => _AdminUpdatesCardState();
}

class _AdminUpdatesCardState extends State<_AdminUpdatesCard> {
  late bool _autoUpdate;
  bool _checkingUpdate = false;
  String? _checkResult;
  bool? _checkOk;
  String? _autoUpdateResult;
  List<({String text, Color? color})> _commitLines = [];
  bool _triggeringUpdate = false;
  String? _triggerResult;

  String _tx(String path) => widget.tx(path);

  @override
  void initState() {
    super.initState();
    _autoUpdate = widget.initialAutoUpdate;
  }

  Future<void> _toggleAutoUpdate(bool desired) async {
    setState(() {
      _autoUpdate = desired;
      _autoUpdateResult = null;
    });
    try {
      final result = await widget.repository.setAutoUpdate(
        widget.token,
        desired,
      );
      final enabled = result['auto_update_enabled'] == true;
      if (!mounted) return;
      setState(() {
        _autoUpdate = enabled;
        _autoUpdateResult = enabled
            ? _tx('admin.config_auto_update_on')
            : _tx('admin.config_auto_update_off');
      });
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _autoUpdate = !desired;
        _autoUpdateResult = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _autoUpdate = !desired;
        _autoUpdateResult = _tx('admin.error_generic');
      });
    }
  }

  /// Línea "Backend: al día (abc1234)" / "App (Flutter): desactualizado…"
  /// para un componente, con el color de estado ya resuelto (verde al día,
  /// ámbar desactualizado, sin color si no se pudo verificar) — o `null` si
  /// ese repo no se horneó en la imagen (`commit == 'dev'`, instalaciones sin
  /// BACKEND_COMMIT/FRONTEND_COMMIT/APP_COMMIT, o builds locales).
  ({String text, Color? color})? _commitLine(
    String label,
    dynamic commit,
    dynamic latest,
    dynamic upToDate,
  ) {
    final commitStr = commit?.toString() ?? 'dev';
    if (commitStr == 'dev') return null;
    final String description;
    Color? color;
    if (upToDate == true) {
      description = _tx(
        'admin.config_commit_up_to_date',
      ).replaceAll('{commit}', commitStr);
      color = _statusOkColor;
    } else if (upToDate == false) {
      description = _tx('admin.config_commit_outdated')
          .replaceAll('{commit}', commitStr)
          .replaceAll('{latest}', '${latest ?? '?'}');
      color = _statusWarnColor;
    } else {
      description = _tx(
        'admin.config_commit_unchecked',
      ).replaceAll('{commit}', commitStr);
      color = null;
    }
    return (text: '$label: $description', color: color);
  }

  List<({String text, Color? color})> _buildCommitLines(
    Map<String, dynamic> data,
  ) {
    final lines = <({String text, Color? color})?>[
      _commitLine(
        _tx('admin.config_backend_commit_label'),
        data['backend_commit'],
        data['backend_commit_latest'],
        data['backend_up_to_date'],
      ),
      _commitLine(
        _tx('admin.config_frontend_commit_label'),
        data['frontend_commit'],
        data['frontend_commit_latest'],
        data['frontend_up_to_date'],
      ),
      _commitLine(
        _tx('admin.config_app_commit_label'),
        data['app_commit'],
        data['app_commit_latest'],
        data['app_up_to_date'],
      ),
    ];
    return [for (final line in lines) ?line];
  }

  Future<void> _checkUpdate() async {
    setState(() {
      _checkingUpdate = true;
      _checkResult = null;
      _checkOk = null;
      _commitLines = [];
    });
    try {
      final data = await widget.repository.checkUpdate(widget.token);
      if (!mounted) return;
      final commitLines = _buildCommitLines(data);
      if (data['checked'] != true) {
        setState(() {
          _checkResult = _tx('admin.config_check_error');
          _checkOk = null;
          _commitLines = commitLines;
        });
      } else if (data['update_available'] == true) {
        setState(() {
          _checkResult = _tx('admin.config_update_available')
              .replaceAll('{latest}', '${data['latest_version']}')
              .replaceAll('{current}', '${data['current_version']}');
          _checkOk = false;
          _commitLines = commitLines;
        });
      } else {
        setState(() {
          _checkResult = _tx(
            'admin.config_up_to_date',
          ).replaceAll('{version}', '${data['current_version']}');
          _checkOk = true;
          _commitLines = commitLines;
        });
      }
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() => _checkResult = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _checkResult = _tx('admin.config_check_error'));
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  /// Dispara /api/admin/update-now (API HTTP de Watchtower) en vez de
  /// esperar hasta 1h a que Watchtower haga su siguiente comprobación
  /// periódica. Si aplica una actualización real, este mismo contenedor se
  /// reinicia a mitad de la operación — por eso un error de red aquí no
  /// necesariamente significa que haya fallado.
  Future<void> _triggerUpdateNow() async {
    setState(() {
      _triggeringUpdate = true;
      _triggerResult = null;
    });
    try {
      await widget.repository.triggerUpdateNow(widget.token);
      if (!mounted) return;
      setState(() {
        _triggerResult = _tx('admin.config_update_now_triggered');
      });
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() => _triggerResult = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _triggerResult = _tx('admin.error_generic'));
    } finally {
      if (mounted) setState(() => _triggeringUpdate = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = widget.autoUpdateAvailable;
    return _sectionCard(_tx('admin.config_section_updates'), [
      if (available)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_tx('admin.config_auto_update')),
          value: _autoUpdate,
          onChanged: _toggleAutoUpdate,
        )
      else
        Text(
          _tx('admin.config_auto_update_unavailable'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      if (_autoUpdateResult != null)
        Text(_autoUpdateResult!, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          // "Buscar actualización" se queda siempre: pregunta a GHCR y no
          // depende de Watchtower para nada.
          SecondaryButton(
            onPressed: _checkingUpdate ? null : _checkUpdate,
            child: Text(
              _checkingUpdate
                  ? _tx('admin.config_check_update_loading')
                  : _tx('admin.config_check_update_btn'),
            ),
          ),
          if (available)
            SecondaryButton(
              onPressed: _triggeringUpdate ? null : _triggerUpdateNow,
              child: Text(
                _triggeringUpdate
                    ? _tx('admin.config_update_now_loading')
                    : _tx('admin.config_update_now_btn'),
              ),
            ),
        ],
      ),
      if (_checkResult != null) ...[
        const SizedBox(height: 6),
        Text(
          _checkResult!,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: _checkOk == null
                ? null
                : (_checkOk == true ? _statusOkColor : _statusWarnColor),
          ),
        ),
      ],
      if (_triggerResult != null) ...[
        const SizedBox(height: 6),
        Text(_triggerResult!, style: Theme.of(context).textTheme.bodySmall),
      ],
      for (final line in _commitLines)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            line.text,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: line.color),
          ),
        ),
    ]);
  }
}
