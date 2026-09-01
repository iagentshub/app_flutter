class LegalLocalizedDocument {
  const LegalLocalizedDocument({required this.url, required this.sha256});

  final String url;
  final String sha256;

  factory LegalLocalizedDocument.fromJson(Map<String, dynamic> json) {
    return LegalLocalizedDocument(
      url: json['url'] as String? ?? '',
      sha256: json['sha256'] as String? ?? '',
    );
  }
}

class LegalDocumentContract {
  const LegalDocumentContract({
    required this.documentType,
    required this.version,
    required this.locales,
  });

  final String documentType;
  final String version;
  final Map<String, LegalLocalizedDocument> locales;

  LegalLocalizedDocument? localized(String locale) {
    final language = locale.toLowerCase().split('-').first;
    return locales[language] ?? locales['es'];
  }

  factory LegalDocumentContract.fromJson(
    String documentType,
    Map<String, dynamic> json,
  ) {
    final rawLocales = json['locales'];
    final locales = <String, LegalLocalizedDocument>{};
    if (rawLocales is Map) {
      for (final entry in rawLocales.entries) {
        final value = entry.value;
        if (value is Map) {
          locales[entry.key.toString().toLowerCase()] =
              LegalLocalizedDocument.fromJson(Map<String, dynamic>.from(value));
        }
      }
    }
    return LegalDocumentContract(
      documentType: documentType,
      version: json['version'] as String? ?? '',
      locales: locales,
    );
  }
}

class LegalContract {
  const LegalContract({
    required this.required,
    required this.ready,
    required this.acceptUrl,
    required this.documents,
  });

  const LegalContract.empty()
    : required = false,
      ready = false,
      acceptUrl = '/app/legal-acceptance',
      documents = const {};

  final bool required;
  final bool ready;
  final String acceptUrl;
  final Map<String, LegalDocumentContract> documents;

  bool get canAccept =>
      ready &&
      const {'terms', 'privacy'}.every((type) {
        final document = documents[type];
        return document != null &&
            document.version.isNotEmpty &&
            document.locales.isNotEmpty;
      });

  factory LegalContract.fromPlatform(Map<String, dynamic> platform) {
    final raw = platform['legal'];
    if (raw is! Map) return const LegalContract.empty();
    final json = Map<String, dynamic>.from(raw);
    final rawDocuments = json['documents'];
    final documents = <String, LegalDocumentContract>{};
    if (rawDocuments is Map) {
      for (final type in const ['terms', 'privacy']) {
        final document = rawDocuments[type];
        if (document is Map) {
          documents[type] = LegalDocumentContract.fromJson(
            type,
            Map<String, dynamic>.from(document),
          );
        }
      }
    }
    return LegalContract(
      required: json['required'] == true,
      ready: json['ready'] == true,
      acceptUrl: json['accept_url'] as String? ?? '/app/legal-acceptance',
      documents: documents,
    );
  }

  Map<String, dynamic> acceptancePayload(String locale) {
    if (!canAccept) {
      throw StateError('El contrato legal vigente no está disponible');
    }
    final language = locale.toLowerCase().split('-').first;
    final selectedLanguage =
        documents.values.every(
          (document) => document.locales.containsKey(language),
        )
        ? language
        : 'es';
    return {
      'accepted': true,
      'locale': selectedLanguage,
      'documents': [
        for (final type in const ['terms', 'privacy'])
          {
            'document_type': type,
            'version': documents[type]!.version,
            'content_sha256': documents[type]!
                .localized(selectedLanguage)!
                .sha256,
            'document_url': documents[type]!.localized(selectedLanguage)!.url,
          },
      ],
    };
  }
}
