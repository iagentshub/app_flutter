import 'package:flutter/material.dart';

import '../../app/theme/fnc_colors.dart';
import '../../app/theme/fnc_fonts.dart';

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
                  color: FncColors.red,
                ),
                title: const Text('Español'),
                onTap: () => Navigator.of(dialogContext).pop('es'),
              ),
              ListTile(
                leading: Icon(
                  isEnglish ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: FncColors.red,
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
              color: FncColors.white,
              fontWeight: FontWeight.w800,
              fontSize: FncFonts.size20,
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
                    color: FncColors.red,
                    borderRadius: BorderRadius.all(Radius.circular(6)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    child: Text(
                      'HUB',
                      style: TextStyle(
                        color: FncColors.white,
                        fontSize: FncFonts.size12,
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
            foregroundColor: FncColors.white,
            side: const BorderSide(color: FncColors.white),
          ),
          child: Text(loginLabel),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () => _showLanguageDialog(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: FncColors.white,
            side: const BorderSide(color: FncColors.overlayWhite40),
            minimumSize: const Size(56, 40),
          ),
          child: Text(isEnglish ? 'ES' : 'EN'),
        ),
      ],
    );
  }
}
