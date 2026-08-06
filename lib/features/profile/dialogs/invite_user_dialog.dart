part of '../widgets/profile_groups_section.dart';

class _InviteUserDialog extends StatefulWidget {
  const _InviteUserDialog({required this.tx});

  final String Function(String path, String fallback) tx;

  @override
  State<_InviteUserDialog> createState() => _InviteUserDialogState();
}

class _InviteUserDialogState extends State<_InviteUserDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.tx('groups.invite_dialog_title', 'Invitar usuario')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.tx(
              'groups.invite_dialog_body',
              'Se enviará una invitación al usuario indicado para unirse a este grupo.',
            ),
            style: const TextStyle(fontSize: FncFonts.size12),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: widget.tx(
                'groups.invite_dialog_label',
                'Email o usuario del invitado',
              ),
            ),
            onSubmitted: (_) =>
                Navigator.of(context).pop(_controller.text.trim()),
          ),
        ],
      ),
      actions: [
        TertiaryButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.tx('common.cancel', 'Cancelar')),
        ),
        PrimaryButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(widget.tx('groups.invite_user', 'Invitar usuario')),
        ),
      ],
    );
  }
}
