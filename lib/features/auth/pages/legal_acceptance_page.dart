import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router/external_router.dart';
import '../../../core/network/api_error.dart';
import '../../../models/auth/legal_contract.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../repositories/auth_repository.dart';

class LegalAcceptancePage extends StatefulWidget {
  const LegalAcceptancePage({
    required this.authRepository,
    required this.sessionController,
    required this.localeController,
    super.key,
  });

  final AuthRepository authRepository;
  final SessionController sessionController;
  final LocaleController localeController;

  @override
  State<LegalAcceptancePage> createState() => _LegalAcceptancePageState();
}

class _LegalAcceptancePageState extends State<LegalAcceptancePage> {
  late final TranslatedTexts _texts;
  LegalContract _contract = const LegalContract.empty();
  bool _loading = true;
  bool _accepted = false;
  bool _submitting = false;
  String? _error;

  String _tx(String path) => _texts.text(path);
  String get _language => widget.localeController.languageCode;

  @override
  void initState() {
    super.initState();
    _texts = TranslatedTexts(
      localeController: widget.localeController,
      namespace: 'auth',
    )..addListener(_refreshText);
    _load();
  }

  void _refreshText() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _texts.removeListener(_refreshText);
    _texts.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final platform = await widget.authRepository.platformPublic();
      final contract = LegalContract.fromPlatform(platform);
      if (!contract.canAccept) {
        throw StateError(_tx('legal_acceptance.unavailable'));
      }
      if (!mounted) return;
      setState(() {
        _contract = contract;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _tx('legal_acceptance.unavailable');
      });
    }
  }

  Future<void> _openDocument(String type) async {
    final localized = _contract.documents[type]?.localized(_language);
    if (localized == null || localized.url.isEmpty) return;
    final parsed = Uri.parse(localized.url);
    final uri = parsed.hasScheme
        ? parsed
        : resolvePublicSiteUri(path: localized.url, useSameOrigin: kIsWeb);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _submit() async {
    final token = widget.sessionController.gaToken;
    if (!_accepted || token == null || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.authRepository.acceptLegal(
        token,
        _contract.acceptancePayload(_language),
      );
      final user = await widget.authRepository.me(token);
      widget.sessionController.actualizarUsuario(user);
    } on ApiError catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = _tx('legal_acceptance.error'));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_tx('legal_acceptance.title'))),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.policy_outlined,
                              size: 44,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 18),
                            Text(
                              _tx('legal_acceptance.heading'),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _tx('legal_acceptance.body'),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            SecondaryButton.icon(
                              onPressed: () => _openDocument('terms'),
                              icon: const Icon(Icons.open_in_new),
                              label: Text(_tx('legal_acceptance.terms')),
                            ),
                            const SizedBox(height: 10),
                            SecondaryButton.icon(
                              onPressed: () => _openDocument('privacy'),
                              icon: const Icon(Icons.open_in_new),
                              label: Text(_tx('legal_acceptance.privacy')),
                            ),
                            const SizedBox(height: 16),
                            CheckboxListTile(
                              value: _accepted,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(_tx('legal_acceptance.confirm')),
                              onChanged: _contract.canAccept
                                  ? (value) => setState(
                                      () => _accepted = value ?? false,
                                    )
                                  : null,
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            PrimaryButton(
                              onPressed: _accepted && !_submitting
                                  ? _submit
                                  : null,
                              child: Text(
                                _submitting
                                    ? _tx('legal_acceptance.submitting')
                                    : _tx('legal_acceptance.submit'),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
