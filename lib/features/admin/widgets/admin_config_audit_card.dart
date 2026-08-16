part of '../pages/admin_page.dart';

/// Tarjeta "Diagnóstico de configuración" del tab de Configuración.
///
/// Muestra lo que el backend audita al arrancar (`/api/admin/config-audit`):
/// qué funciones quedan desactivadas y por qué variable. Existe porque una
/// variable de entorno mal escrita no rompe nada —simplemente apaga el cobro,
/// o el envío de correo— y el único sitio donde eso se veía era el log del
/// arranque, que nadie mira.
///
/// La respuesta trae **nombres** de variable, nunca valores.
class _AdminConfigAuditCard extends StatefulWidget {
  const _AdminConfigAuditCard({
    required this.repository,
    required this.token,
    required this.tx,
  });

  final AdminPlatformRepository repository;
  final String token;
  final String Function(String path, String fallback) tx;

  @override
  State<_AdminConfigAuditCard> createState() => _AdminConfigAuditCardState();
}

class _AdminConfigAuditCardState extends State<_AdminConfigAuditCard> {
  List<Map<String, dynamic>> _checks = const [];
  bool _loading = true;
  bool _strict = false;
  int _errors = 0;
  int _warnings = 0;
  String? _error;
  // Lo interesante son los problemas: las comprobaciones correctas se pliegan
  // para que una instalación sana ocupe tres líneas, no veinte.
  bool _showOk = false;

  String _tx(String path, String fallback) => widget.tx(path, fallback);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final report = await widget.repository.getConfigAudit(widget.token);
      if (!mounted) return;
      setState(() {
        _checks = (report['checks'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
        _strict = report['strict'] == true;
        _errors = (report['errors'] as num?)?.toInt() ?? 0;
        _warnings = (report['warnings'] as num?)?.toInt() ?? 0;
        _loading = false;
        _error = null;
      });
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = _tx('admin.error_generic', 'No se pudo completar la acción');
        _loading = false;
      });
    }
  }

  Color _severityColor(String severity) => switch (severity) {
    'error' => FncColors.danger,
    'warning' => _statusWarnColor,
    _ => _statusOkColor,
  };

  IconData _severityIcon(String severity) => switch (severity) {
    'error' => Icons.error_outline,
    'warning' => Icons.warning_amber_outlined,
    _ => Icons.check_circle_outline,
  };

  Widget _checkTile(Map<String, dynamic> check) {
    final severity = (check['severity'] ?? 'ok').toString();
    final variables = (check['variables'] as List? ?? const [])
        .map((v) => v.toString())
        .join(', ');
    final color = _severityColor(severity);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 8),
            child: Icon(_severityIcon(severity), size: 16, color: color),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (check['feature'] ?? '').toString(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  (check['detail'] ?? '').toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (variables.isNotEmpty)
                  Text(
                    variables,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: FncFonts.monospace,
                      color: color,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary() {
    if (_errors == 0 && _warnings == 0) {
      return Text(
        _tx(
          'admin.config_audit_all_ok',
          'Configuración completa: ninguna función degradada.',
        ),
        style: const TextStyle(color: _statusOkColor),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _tx('admin.config_audit_summary', '{errors} errores, {warnings} avisos')
              .replaceAll('{errors}', '$_errors')
              .replaceAll('{warnings}', '$_warnings'),
          style: TextStyle(
            color: _errors > 0 ? FncColors.danger : _statusWarnColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (_errors > 0 && !_strict) ...[
          const SizedBox(height: 4),
          Text(
            _tx(
              'admin.config_audit_strict_hint',
              'Estos errores no impiden arrancar. Define GAIA_STRICT_CONFIG=true '
                  'en producción para que sí lo hagan.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _sectionCard(
        _tx('admin.config_section_audit', 'Diagnóstico de configuración'),
        const [Center(child: CircularProgressIndicator())],
      );
    }
    if (_error != null) {
      return _sectionCard(
        _tx('admin.config_section_audit', 'Diagnóstico de configuración'),
        [Text(_error!, style: const TextStyle(color: FncColors.danger))],
      );
    }

    final problems = _checks
        .where((c) => (c['severity'] ?? 'ok').toString() != 'ok')
        .toList();
    final okChecks = _checks
        .where((c) => (c['severity'] ?? 'ok').toString() == 'ok')
        .toList();

    return _sectionCard(
      _tx('admin.config_section_audit', 'Diagnóstico de configuración'),
      [
        _summary(),
        const SizedBox(height: 12),
        ...problems.map(_checkTile),
        if (okChecks.isNotEmpty) ...[
          if (_showOk) ...okChecks.map(_checkTile),
          Align(
            alignment: Alignment.centerLeft,
            child: SecondaryButton(
              onPressed: () => setState(() => _showOk = !_showOk),
              child: Text(
                _showOk
                    ? _tx('admin.config_audit_hide_ok', 'Ocultar las correctas')
                    : _tx(
                        'admin.config_audit_show_ok',
                        'Ver las {count} correctas',
                      ).replaceAll('{count}', '${okChecks.length}'),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
