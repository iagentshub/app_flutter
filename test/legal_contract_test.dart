import 'package:app_flutter/models/auth/legal_contract.dart';
import 'package:app_flutter/models/auth/session_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('construye la aceptación exacta de la versión e idioma vigentes', () {
    final contract = LegalContract.fromPlatform(_platformLegal());

    expect(contract.required, isTrue);
    expect(contract.canAccept, isTrue);
    expect(contract.acceptancePayload('en-US'), {
      'accepted': true,
      'locale': 'en',
      'documents': [
        {
          'document_type': 'terms',
          'version': 'terms-v2',
          'content_sha256': 'c' * 64,
          'document_url': '/en/terms',
        },
        {
          'document_type': 'privacy',
          'version': 'privacy-v3',
          'content_sha256': 'd' * 64,
          'document_url': '/en/privacy',
        },
      ],
    });
  });

  test('usa español si el idioma solicitado no está publicado', () {
    final payload = LegalContract.fromPlatform(_platformLegal())
        .acceptancePayload('fr');

    expect(payload['locale'], 'es');
    expect((payload['documents'] as List).first['document_url'], '/terms');
  });

  test('la sesión expone el bloqueo legal aditivo', () {
    final user = SessionUser.fromJson({
      'username': 'alice',
      'role': 'standard',
      'legal_acceptance_required': true,
    });

    expect(user.legalAcceptanceRequired, isTrue);
    expect(user.conAvatar('/avatar').legalAcceptanceRequired, isTrue);
  });
}

Map<String, dynamic> _platformLegal() => {
  'legal': {
    'required': true,
    'ready': true,
    'accept_url': '/app/legal-acceptance',
    'documents': {
      'terms': {
        'version': 'terms-v2',
        'locales': {
          'es': {'url': '/terms', 'sha256': 'a' * 64},
          'en': {'url': '/en/terms', 'sha256': 'c' * 64},
        },
      },
      'privacy': {
        'version': 'privacy-v3',
        'locales': {
          'es': {'url': '/privacy', 'sha256': 'b' * 64},
          'en': {'url': '/en/privacy', 'sha256': 'd' * 64},
        },
      },
    },
  },
};
