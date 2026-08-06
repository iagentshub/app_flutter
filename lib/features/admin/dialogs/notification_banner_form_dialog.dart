part of '../pages/admin_page.dart';

/// Dialog de alta/edición de un banner de notificación — fecha de inicio,
/// fecha de fin y mensaje en cada idioma soportado (es/en). Las fechas se
/// convierten a UTC antes de enviarse: a diferencia del antiguo
/// maintenance_at (solo informativo), estas se comparan de verdad contra
/// "ahora" en el servidor para decidir si el banner está vigente.
class _NotificationBannerFormDialog extends StatefulWidget {
  const _NotificationBannerFormDialog({required this.tx, this.initial});

  final String Function(String path, String fallback) tx;
  final Map<String, dynamic>? initial;

  @override
  State<_NotificationBannerFormDialog> createState() =>
      _NotificationBannerFormDialogState();
}

class _NotificationBannerFormDialogState
    extends State<_NotificationBannerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _messageEsController;
  late final TextEditingController _messageEnController;
  DateTime? _startAt;
  DateTime? _endAt;
  String? _rangeError;

  String _tx(String path, String fallback) => widget.tx(path, fallback);

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    final message = (initial?['message'] as Map?)?.cast<String, dynamic>();
    _messageEsController = TextEditingController(
      text: (message?['es'] ?? '').toString(),
    );
    _messageEnController = TextEditingController(
      text: (message?['en'] ?? '').toString(),
    );
    _startAt = DateTime.tryParse(
      (initial?['start_at'] ?? '').toString(),
    )?.toLocal();
    _endAt = DateTime.tryParse(
      (initial?['end_at'] ?? '').toString(),
    )?.toLocal();
  }

  @override
  void dispose() {
    _messageEsController.dispose();
    _messageEnController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime(bool isStart) async {
    final current = isStart ? _startAt : _endAt;
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: current != null
          ? TimeOfDay.fromDateTime(current)
          : TimeOfDay.fromDateTime(now),
    );
    if (time == null) return;
    setState(() {
      final picked = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (isStart) {
        _startAt = picked;
      } else {
        _endAt = picked;
      }
    });
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    if (_startAt == null || _endAt == null) {
      setState(
        () => _rangeError = _tx(
          'admin.config_banners_missing_dates',
          'Elige fecha de inicio y fin',
        ),
      );
      return;
    }
    if (!_endAt!.isAfter(_startAt!)) {
      setState(
        () => _rangeError = _tx(
          'admin.config_banners_range_error',
          'La fecha de fin debe ser posterior a la de inicio',
        ),
      );
      return;
    }
    Navigator.of(context).pop({
      'start_at': _startAt!.toUtc().toIso8601String(),
      'end_at': _endAt!.toUtc().toIso8601String(),
      'message': {
        'es': _messageEsController.text.trim(),
        'en': _messageEnController.text.trim(),
      },
    });
  }

  String _fmt(DateTime? dt) {
    if (dt == null) {
      return _tx('admin.config_banners_no_date', 'Sin fecha');
    }
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  String? _requiredMessage(String? value) {
    if (value == null || value.trim().isEmpty) {
      return _tx(
        'admin.config_banners_message_required',
        'El mensaje es obligatorio',
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initial == null
            ? _tx(
                'admin.config_banners_create_title',
                'Crear banner de notificación',
              )
            : _tx(
                'admin.config_banners_edit_title',
                'Editar banner de notificación',
              ),
      ),
      content: SizedBox(
        width: dialogContentWidth(context, 480),
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_tx('admin.config_banners_start', 'Inicio')}: ${_fmt(_startAt)}',
                    ),
                  ),
                  TertiaryButton(
                    onPressed: () => _pickDateTime(true),
                    child: Text(
                      _tx('admin.config_banners_pick_date', 'Elegir fecha'),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_tx('admin.config_banners_end', 'Fin')}: ${_fmt(_endAt)}',
                    ),
                  ),
                  TertiaryButton(
                    onPressed: () => _pickDateTime(false),
                    child: Text(
                      _tx('admin.config_banners_pick_date', 'Elegir fecha'),
                    ),
                  ),
                ],
              ),
              if (_rangeError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Text(
                    _rangeError!,
                    style: const TextStyle(color: FncColors.materialRed),
                  ),
                ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _messageEsController,
                maxLength: 500,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: _tx(
                    'admin.config_banners_message_es',
                    'Mensaje (Español)',
                  ),
                ),
                validator: _requiredMessage,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _messageEnController,
                maxLength: 500,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: _tx(
                    'admin.config_banners_message_en',
                    'Mensaje (English)',
                  ),
                ),
                validator: _requiredMessage,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TertiaryButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_tx('common.cancel', 'Cancelar')),
        ),
        PrimaryButton(onPressed: _submit, child: Text(_tx('common.save', 'Guardar'))),
      ],
    );
  }
}
