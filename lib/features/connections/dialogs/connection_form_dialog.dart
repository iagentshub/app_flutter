part of '../pages/connections_page.dart';

class _ConnectionFormDialog extends StatefulWidget {
  const _ConnectionFormDialog({required this.providers, this.initial});

  final List<ConnectionProvider> providers;
  final Map<String, dynamic>? initial;

  @override
  State<_ConnectionFormDialog> createState() => _ConnectionFormDialogState();
}

class _ConnectionFormDialogState extends State<_ConnectionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _scope = 'group';
  String _selectedType = '';
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, bool> _boolValues = {};

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController.text = (initial?['name'] as String?) ?? '';
    _scope = initial?['_personal_key'] == true ? 'personal' : 'group';

    if (widget.providers.isNotEmpty) {
      final initialType = initial?['type'] as String?;
      _selectedType = widget.providers.any((p) => p.type == initialType)
          ? (initialType ?? widget.providers.first.type)
          : widget.providers.first.type;
      _syncControllersFromProvider();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  ConnectionProvider? get _provider {
    for (final p in widget.providers) {
      if (p.type == _selectedType) return p;
    }
    return null;
  }

  void _syncControllersFromProvider() {
    final provider = _provider;
    if (provider == null) return;
    final initial = widget.initial;

    for (final field in provider.fields) {
      if (field.type == 'checkbox') {
        final raw = initial?[field.key];
        final boolValue = raw is bool
            ? raw
            : (raw is String
                  ? raw.toLowerCase() == 'true'
                  : field.defaultValue.toLowerCase() == 'true');
        _boolValues[field.key] = boolValue;
        continue;
      }

      final existingController = _textControllers[field.key];
      if (existingController != null) continue;

      final value = initial?[field.key]?.toString() ?? field.defaultValue;
      _textControllers[field.key] = TextEditingController(text: value);
    }
  }

  bool _visible(ProviderField field) {
    if (field.dependsOn == null || field.dependsOn!.isEmpty) return true;
    final dependsOn = field.dependsOn!;
    final expected = field.dependsValue ?? '';
    final boolVal = _boolValues[dependsOn];
    if (boolVal != null) {
      return boolVal.toString() == expected;
    }
    final textVal = _textControllers[dependsOn]?.text ?? '';
    return textVal == expected;
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    final provider = _provider;
    if (provider == null) return;

    final payload = <String, dynamic>{
      'name': _nameController.text.trim(),
      'type': _selectedType,
      'scope': _scope,
    };

    for (final field in provider.fields) {
      if (!_visible(field)) continue;

      if (field.type == 'checkbox') {
        payload[field.key] = _boolValues[field.key] ?? false;
        continue;
      }

      final raw = _textControllers[field.key]?.text ?? '';
      if (field.type == 'number') {
        final parsed = num.tryParse(raw.trim());
        if (parsed != null) {
          payload[field.key] = parsed;
        } else {
          payload[field.key] = raw.trim();
        }
      } else {
        payload[field.key] = raw.trim();
      }
    }

    Navigator.of(context).pop(payload);
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider;

    return AlertDialog(
      title: Text(
        widget.initial == null ? 'Nueva conexión' : 'Editar conexión',
      ),
      content: SizedBox(
        width: dialogContentWidth(context, 560),
        child: provider == null
            ? const Text('No hay proveedores disponibles')
            : Form(
                key: _formKey,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'El nombre es obligatorio';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedType,
                      items: widget.providers
                          .map(
                            (p) => DropdownMenuItem<String>(
                              value: p.type,
                              child: Text('${p.label} (${p.type})'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _selectedType = value;
                          _syncControllersFromProvider();
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Proveedor'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _scope,
                      items: const [
                        DropdownMenuItem(value: 'group', child: Text('Grupo')),
                        DropdownMenuItem(
                          value: 'personal',
                          child: Text('Personal'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _scope = value);
                      },
                      decoration: const InputDecoration(labelText: 'Ámbito'),
                    ),
                    const SizedBox(height: 10),
                    ...provider.fields
                        .where(_visible)
                        .map((field) => _buildField(field))
                        .expand(
                          (widget) => [widget, const SizedBox(height: 10)],
                        ),
                  ],
                ),
              ),
      ),
      actions: [
        TertiaryButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        PrimaryButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }

  Widget _buildField(ProviderField field) {
    if (field.type == 'checkbox') {
      final value = _boolValues[field.key] ?? false;
      return SwitchListTile(
        title: Text(field.label),
        value: value,
        onChanged: (next) => setState(() => _boolValues[field.key] = next),
        contentPadding: EdgeInsets.zero,
      );
    }

    if (field.type == 'select') {
      final controller = _textControllers[field.key] ??= TextEditingController(
        text: field.defaultValue,
      );
      final current = controller.text.isEmpty ? null : controller.text;
      return DropdownButtonFormField<String>(
        initialValue: current,
        decoration: InputDecoration(labelText: field.label),
        items: field.options
            .map(
              (option) => DropdownMenuItem<String>(
                value: option.value,
                child: Text(option.label),
              ),
            )
            .toList(),
        onChanged: (value) {
          controller.text = value ?? '';
          setState(() {});
        },
        validator: (value) {
          if (field.required && (value == null || value.trim().isEmpty)) {
            return 'Campo obligatorio';
          }
          return null;
        },
      );
    }

    final controller = _textControllers[field.key] ??= TextEditingController(
      text: field.defaultValue,
    );
    final isPassword = field.type == 'password';
    final isNumber = field.type == 'number';
    final isTextarea = field.type == 'textarea';

    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      minLines: isTextarea ? 3 : 1,
      maxLines: isTextarea ? 5 : 1,
      decoration: InputDecoration(
        labelText: field.label,
        hintText: field.placeholder.isEmpty ? null : field.placeholder,
      ),
      validator: (value) {
        if (field.required && (value == null || value.trim().isEmpty)) {
          return 'Campo obligatorio';
        }
        return null;
      },
    );
  }
}
