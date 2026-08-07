part of '../pages/admin_page.dart';

/// Tarjeta "Banners de notificación" del tab de Configuración — extraída de
/// _AdminConfigTab por el mismo motivo que _AdminUpdatesCard (ver ese
/// archivo): es un subsistema independiente que persiste al instante
/// (crear/editar/borrar), no espera al botón "Guardar" del resto de campos.
class _AdminBannersCard extends StatefulWidget {
  const _AdminBannersCard({
    required this.repository,
    required this.token,
    required this.tx,
  });

  final AdminPlatformRepository repository;
  final String token;
  final String Function(String path, String fallback) tx;

  @override
  State<_AdminBannersCard> createState() => _AdminBannersCardState();
}

class _AdminBannersCardState extends State<_AdminBannersCard>
    with StateMessaging {
  List<Map<String, dynamic>> _banners = [];
  bool _loading = true;
  String? _error;

  String _tx(String path, String fallback) => widget.tx(path, fallback);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final banners = await widget.repository.listNotificationBanners(
        widget.token,
      );
      banners.sort(
        (a, b) => (a['start_at'] ?? '').toString().compareTo(
          (b['start_at'] ?? '').toString(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _banners = banners;
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

  Future<void> _openCreateDialog() async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _NotificationBannerFormDialog(tx: _tx),
    );
    if (payload == null) return;
    await _save(payload);
  }

  Future<void> _openEditDialog(Map<String, dynamic> banner) async {
    final bannerId = _bannerId(banner);
    if (bannerId == null) {
      _showInvalidBannerId();
      return;
    }
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          _NotificationBannerFormDialog(tx: _tx, initial: banner),
    );
    if (payload == null) return;
    await _save(payload, bannerId: bannerId);
  }

  Future<void> _save(Map<String, dynamic> payload, {String? bannerId}) async {
    try {
      if (bannerId == null) {
        await widget.repository.createNotificationBanner(widget.token, payload);
      } else {
        await widget.repository.updateNotificationBanner(
          widget.token,
          bannerId,
          payload,
        );
      }
      await _load();
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(
        _tx('admin.error_generic', 'No se pudo completar la acción'),
        isError: true,
      );
    }
  }

  Future<void> _delete(Map<String, dynamic> banner) async {
    final bannerId = _bannerId(banner);
    if (bannerId == null) {
      _showInvalidBannerId();
      return;
    }
    final confirmed = await showConfirmActionDialog(
      context,
      title: _tx('admin.config_banners_delete_title', 'Eliminar banner'),
      message: _tx(
        'admin.config_banners_delete_confirm',
        '¿Seguro que quieres eliminar este banner?',
      ),
      cancelLabel: _tx('common.cancel', 'Cancelar'),
      confirmLabel: _tx('common.delete', 'Eliminar'),
    );
    if (!confirmed) return;
    try {
      await widget.repository.deleteNotificationBanner(widget.token, bannerId);
      await _load();
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(
        _tx('admin.error_generic', 'No se pudo completar la acción'),
        isError: true,
      );
    }
  }

  String? _bannerId(Map<String, dynamic> banner) {
    final value = banner['id'];
    if (value is! String || value.trim().isEmpty) return null;
    return value;
  }

  void _showInvalidBannerId() {
    showMessage(
      _tx(
        'admin.config_banners_invalid_id',
        'El banner no tiene un identificador válido.',
      ),
      isError: true,
    );
  }

  String _fmt(String? iso) {
    final dt = DateTime.tryParse(iso ?? '')?.toLocal();
    if (dt == null) return '—';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return _sectionCard(
      _tx('admin.config_section_banners', 'Banners de notificación'),
      [
        Text(
          _tx(
            'admin.config_banners_hint',
            'Se muestran como card en el Dashboard mientras dure su rango de fechas, en el idioma de cada usuario.',
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_error != null)
          Text(_error!, style: const TextStyle(color: FncColors.materialRed))
        else if (_banners.isEmpty)
          Text(
            _tx('admin.config_banners_empty', 'No hay banners creados.'),
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          Column(
            children: [for (final banner in _banners) _bannerTile(banner)],
          ),
        const SizedBox(height: 10),
        PrimaryButton.icon(
          onPressed: _openCreateDialog,
          icon: const Icon(Icons.campaign_outlined),
          label: Text(
            _tx(
              'admin.config_banners_create_btn',
              'Crear banner de notificación',
            ),
          ),
        ),
      ],
    );
  }

  Widget _bannerTile(Map<String, dynamic> banner) {
    final message =
        (banner['message'] as Map?)?.cast<String, dynamic>() ?? const {};
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_fmt(banner['start_at'] as String?)} → ${_fmt(banner['end_at'] as String?)}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: FncFonts.size12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              (message['es'] ?? '').toString(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Row(
              children: [
                const Spacer(),
                ActionIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: _tx('common.edit', 'Editar'),
                  onPressed: () => _openEditDialog(banner),
                ),
                ActionIconButton(
                  icon: Icons.delete_outline,
                  tooltip: _tx('common.delete', 'Eliminar'),
                  danger: true,
                  onPressed: () => _delete(banner),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
