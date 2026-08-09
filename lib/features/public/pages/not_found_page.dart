import 'package:flutter/material.dart';

import '../../../app/router/router.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/app_services_scope.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';

class NotFoundPage extends StatefulWidget {
  const NotFoundPage({super.key});

  @override
  State<NotFoundPage> createState() => _NotFoundPageState();
}

class _NotFoundPageState extends State<NotFoundPage> {
  late final TranslatedTexts _t;

  String _tx(String path, String fallback) => _t.text(path, fallback: fallback);

  @override
  void initState() {
    super.initState();
    _t = TranslatedTexts(
      localeController: AppServicesScope.of(context).localeController,
      namespace: 'resources',
    )..addListener(_onTextsChanged);
  }

  void _onTextsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _t.removeListener(_onTextsChanged);
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_tx('common.not_found', 'Página no encontrada')),
              const SizedBox(height: 8),
              PrimaryButton(
                onPressed: () => AppRouter.toLogin(context),
                child: Text(_tx('common.go_home', 'Ir al inicio')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
