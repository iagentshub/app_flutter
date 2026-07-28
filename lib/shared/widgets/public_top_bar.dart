import 'package:flutter/material.dart';

class PublicTopBar extends StatelessWidget {
  const PublicTopBar({
    required this.isEnglish,
    required this.onLogin,
    required this.onLanguageSelected,
    required this.loginLabel,
    super.key,
  });

  final bool isEnglish;
  final VoidCallback onLogin;
  final ValueChanged<String> onLanguageSelected;
  final String loginLabel;

  Future<void> _showLanguageDialog(BuildContext context) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Seleccionar idioma / Select language'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  isEnglish ? Icons.radio_button_unchecked : Icons.check_circle,
                  color: const Color(0xFFD90429),
                ),
                title: const Text('Español'),
                onTap: () => Navigator.of(dialogContext).pop('es'),
              ),
              ListTile(
                leading: Icon(
                  isEnglish ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: const Color(0xFFD90429),
                ),
                title: const Text('English'),
                onTap: () => Navigator.of(dialogContext).pop('en'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar / Cancel'),
            ),
          ],
        );
      },
    );

    if (selected == null) return;
    onLanguageSelected(selected);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        RichText(
          text: const TextSpan(
            style: TextStyle(
              color: Color(0xFFFFFFFF),
              fontWeight: FontWeight.w800,
              fontSize: 20,
              letterSpacing: -0.2,
            ),
            children: [
              TextSpan(text: 'iAgents'),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: SizedBox(width: 6),
              ),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFFD90429),
                    borderRadius: BorderRadius.all(Radius.circular(6)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    child: Text(
                      'HUB',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        OutlinedButton(
          onPressed: onLogin,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFFFFFFF),
            side: const BorderSide(color: Color(0xFFFFFFFF)),
          ),
          child: Text(loginLabel),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () => _showLanguageDialog(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFFFFFFF),
            side: const BorderSide(color: Color(0x66FFFFFF)),
            minimumSize: const Size(56, 40),
          ),
          child: Text(isEnglish ? 'ES' : 'EN'),
        ),
      ],
    );
  }
}
