/// Metadata fija de los proveedores soportados por `/api/accounts`.
///
/// El backend (`_PROVIDERS`/`_PROVIDER_LABELS` en
/// `app/api/routes/accounts.py`) no expone un endpoint de metadata dinámica
/// para este recurso (a diferencia de `/api/connections/providers`), así que
/// la lista vive aquí en espejo.
class AccountProviderMeta {
  const AccountProviderMeta({
    required this.provider,
    required this.label,
    required this.requiresApiKey,
    required this.usesHost,
    this.requiresUrl = false,
    this.requiresUsername = false,
  });

  final String provider;
  final String label;

  /// Para `iagentshub` es el campo "Contraseña" del login, no una API key.
  final bool requiresApiKey;
  final bool usesHost;
  final bool requiresUrl;
  final bool requiresUsername;

  static const List<AccountProviderMeta> all = [
    AccountProviderMeta(
      provider: 'anthropic',
      label: 'Anthropic',
      requiresApiKey: true,
      usesHost: false,
    ),
    AccountProviderMeta(
      provider: 'openai',
      label: 'OpenAI',
      requiresApiKey: true,
      usesHost: false,
    ),
    AccountProviderMeta(
      provider: 'github',
      label: 'GitHub Copilot',
      requiresApiKey: true,
      usesHost: false,
    ),
    AccountProviderMeta(
      provider: 'ollama',
      label: 'Ollama',
      requiresApiKey: false,
      usesHost: true,
    ),
    AccountProviderMeta(
      provider: 'nvidia',
      label: 'NVIDIA NIM',
      requiresApiKey: true,
      usesHost: false,
    ),
    AccountProviderMeta(
      provider: 'google',
      label: 'Google Gemini',
      requiresApiKey: true,
      usesHost: false,
    ),
    AccountProviderMeta(
      provider: 'iagentshub',
      label: 'iAgents Hub',
      requiresApiKey: true,
      usesHost: false,
      requiresUrl: true,
      requiresUsername: true,
    ),
  ];
}

class AccountSyncSummary {
  const AccountSyncSummary({
    required this.connectionsCreated,
    required this.connectionsUpdated,
    required this.agentsCount,
    required this.routinesCount,
    required this.skillsPrivateCount,
  });

  final int connectionsCreated;
  final int connectionsUpdated;
  final int agentsCount;
  final int routinesCount;
  final int skillsPrivateCount;

  factory AccountSyncSummary.fromJson(Map<String, dynamic> json) {
    return AccountSyncSummary(
      connectionsCreated: json['connections_created'] as int? ?? 0,
      connectionsUpdated: json['connections_updated'] as int? ?? 0,
      agentsCount: json['agents_count'] as int? ?? 0,
      routinesCount: json['routines_count'] as int? ?? 0,
      skillsPrivateCount: json['skills_private_count'] as int? ?? 0,
    );
  }
}

/// Resumen de sincronización de una cuenta `iagentshub` — forma distinta a
/// [AccountSyncSummary]: trae agentes/skills/conocimiento/conexiones de otra
/// instancia, no modelos elegidos por checkbox.
class AccountHubSyncSummary {
  const AccountHubSyncSummary({
    required this.ok,
    required this.agents,
    required this.skills,
    required this.knowledge,
    required this.connections,
    required this.updated,
    required this.errors,
  });

  final bool ok;
  final int agents;
  final int skills;
  final int knowledge;
  final int connections;
  final int updated;
  final List<String> errors;

  factory AccountHubSyncSummary.fromJson(Map<String, dynamic> json) {
    final rawErrors = json['errors'];
    return AccountHubSyncSummary(
      ok: json['ok'] == true,
      agents: json['agents'] as int? ?? 0,
      skills: json['skills'] as int? ?? 0,
      knowledge: json['knowledge'] as int? ?? 0,
      connections: json['connections'] as int? ?? 0,
      updated: json['updated'] as int? ?? 0,
      errors: rawErrors is List
          ? rawErrors.map((e) => e.toString()).toList()
          : const [],
    );
  }
}

/// Cuenta vinculada a un proveedor externo, tal como la devuelve
/// `GET /api/accounts` — solo las que están realmente vinculadas; puede
/// haber varias con el mismo [provider] (cada una con su propio [id]).
class AccountItem {
  const AccountItem({required this.raw});

  final Map<String, dynamic> raw;

  String get id => raw['id'] as String? ?? '';
  String get provider => raw['provider'] as String? ?? '';

  /// Nombre a mostrar: el que puso el usuario o, si no hay, el label del
  /// proveedor — relevante cuando hay varias cuentas del mismo proveedor.
  String get name => raw['name'] as String? ?? '';
  String get apiKeyMasked => raw['api_key_masked'] as String? ?? '';
  String get host => raw['host'] as String? ?? '';
  String get url => raw['url'] as String? ?? '';
  String get username => raw['username'] as String? ?? '';
  String get lastSyncedAt => raw['last_synced_at'] as String? ?? '';

  List<String> get models {
    final value = raw['models'];
    if (value is List) return value.map((item) => item.toString()).toList();
    return const [];
  }

  AccountSyncSummary? get syncSummary {
    final value = raw['sync_summary'];
    if (provider != 'iagentshub' && value is Map<String, dynamic>) {
      return AccountSyncSummary.fromJson(value);
    }
    return null;
  }

  AccountHubSyncSummary? get hubSyncSummary {
    final value = raw['sync_summary'];
    if (provider == 'iagentshub' && value is Map<String, dynamic>) {
      return AccountHubSyncSummary.fromJson(value);
    }
    return null;
  }
}

/// Respuesta de `POST /api/accounts/{provider}/test`: previsualización de
/// modelos disponibles (o, para `iagentshub`, resultado del login) antes o
/// después de vincular la cuenta.
class AccountModelsPreview {
  const AccountModelsPreview({
    required this.ok,
    required this.models,
    this.message,
  });

  final bool ok;
  final List<String> models;
  final String? message;

  int get modelsCount => models.length;

  factory AccountModelsPreview.fromJson(Map<String, dynamic> json) {
    final value = json['models'];
    return AccountModelsPreview(
      ok: json['ok'] == true,
      models: value is List
          ? value.map((item) => item.toString()).toList()
          : const [],
      message: json['message'] as String?,
    );
  }
}
