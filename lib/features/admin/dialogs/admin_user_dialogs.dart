part of '../pages/admin_page.dart';

class _OwnerPickerDialog extends StatefulWidget {
  const _OwnerPickerDialog({
    required this.currentOwner,
    required this.usernames,
    required this.tx,
  });

  final String currentOwner;
  final List<String> usernames;
  final String Function(String path, String fallback) tx;

  @override
  State<_OwnerPickerDialog> createState() => _OwnerPickerDialogState();
}

class _OwnerPickerDialogState extends State<_OwnerPickerDialog> {
  String _selected = '';

  @override
  Widget build(BuildContext context) {
    final tx = widget.tx;
    return AlertDialog(
      title: Text(tx('admin.change_owner_title', 'Cambiar propietario')),
      content: SizedBox(
        width: dialogContentWidth(context, 360),
        child: Autocomplete<String>(
          optionsBuilder: (value) {
            if (value.text.isEmpty) return widget.usernames;
            final q = value.text.toLowerCase();
            return widget.usernames.where((u) => u.toLowerCase().contains(q));
          },
          onSelected: (value) => setState(() => _selected = value),
          fieldViewBuilder: (context, controller, focusNode, onSubmit) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: tx('admin.change_owner_hint', 'Nuevo propietario'),
                helperText: tx('admin.change_owner_current', 'Actual: {owner}')
                    .replaceAll(
                      '{owner}',
                      widget.currentOwner.isEmpty ? '—' : widget.currentOwner,
                    ),
              ),
              onChanged: (v) => setState(() => _selected = v),
            );
          },
        ),
      ),
      actions: [
        TertiaryButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tx('common.cancel', 'Cancelar')),
        ),
        PrimaryButton(
          onPressed: _selected.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(_selected.trim()),
          child: Text(tx('admin.action_change_owner', 'Cambiar propietario')),
        ),
      ],
    );
  }
}

class _UserEditDialog extends StatefulWidget {
  const _UserEditDialog({required this.user, required this.tx});

  final Map<String, dynamic> user;
  final String Function(String path, String fallback) tx;

  @override
  State<_UserEditDialog> createState() => _UserEditDialogState();
}

class _UserEditDialogState extends State<_UserEditDialog> {
  late String _role;
  late bool _active;
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _role = (widget.user['role'] ?? 'standard').toString();
    _active =
        widget.user['is_active'] != 0 && widget.user['is_active'] != false;
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final email = (widget.user['email'] ?? widget.user['username'] ?? '')
        .toString();
    return AlertDialog(
      title: Text(widget.tx('admin.edit_user_title', 'Editar usuario')),
      content: SizedBox(
        width: dialogContentWidth(context, 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(email, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: InputDecoration(
                labelText: widget.tx('admin.field_role', 'Rol'),
              ),
              items: [
                DropdownMenuItem(
                  value: 'standard',
                  child: Text(widget.tx('admin.role_standard', 'Estándar')),
                ),
                DropdownMenuItem(
                  value: 'admin',
                  child: Text(widget.tx('admin.role_admin', 'Admin')),
                ),
              ],
              onChanged: (v) => setState(() => _role = v ?? 'standard'),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(widget.tx('admin.field_active', 'Activo')),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: widget.tx(
                  'admin.field_password_optional',
                  'Nueva contraseña (opcional)',
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TertiaryButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.tx('common.cancel', 'Cancelar')),
        ),
        PrimaryButton(
          onPressed: () => Navigator.of(context).pop({
            'role': _role,
            'is_active': _active,
            'password': _passwordController.text.trim(),
          }),
          child: Text(widget.tx('common.save', 'Guardar')),
        ),
      ],
    );
  }
}

class _UserCreateDialog extends StatefulWidget {
  const _UserCreateDialog({required this.tx});

  final String Function(String path, String fallback) tx;

  @override
  State<_UserCreateDialog> createState() => _UserCreateDialogState();
}

class _UserCreateDialogState extends State<_UserCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _passwordController = TextEditingController();
  String _role = 'standard';

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    Navigator.of(context).pop({
      'username': _usernameController.text.trim().toLowerCase(),
      'email': _emailController.text.trim(),
      'display_name': _displayNameController.text.trim(),
      'password': _passwordController.text.trim(),
      'role': _role,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.tx('admin.create_user_title', 'Nuevo usuario')),
      content: SizedBox(
        width: dialogContentWidth(context, 420),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _usernameController,
                autocorrect: false,
                textCapitalization: TextCapitalization.none,
                decoration: InputDecoration(
                  labelText: widget.tx(
                    'admin.field_username',
                    'Usuario público',
                  ),
                ),
                validator: Validators.username,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: widget.tx('admin.field_email', 'Email'),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? widget.tx('agents.name_required', 'Obligatorio')
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _displayNameController,
                decoration: InputDecoration(
                  labelText: widget.tx(
                    'admin.field_display_name',
                    'Nombre para mostrar',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: widget.tx('admin.field_password', 'Contraseña'),
                ),
                validator: (value) => (value == null || value.trim().length < 4)
                    ? widget.tx('agents.name_required', 'Obligatorio')
                    : null,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: InputDecoration(
                  labelText: widget.tx('admin.field_role', 'Rol'),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'standard',
                    child: Text(widget.tx('admin.role_standard', 'Estándar')),
                  ),
                  DropdownMenuItem(
                    value: 'admin',
                    child: Text(widget.tx('admin.role_admin', 'Admin')),
                  ),
                ],
                onChanged: (v) => setState(() => _role = v ?? 'standard'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TertiaryButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.tx('common.cancel', 'Cancelar')),
        ),
        PrimaryButton(
          onPressed: _submit,
          child: Text(widget.tx('common.create', 'Crear')),
        ),
      ],
    );
  }
}
