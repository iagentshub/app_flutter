import '../common/resource_item.dart';

class ConnectionItem extends ResourceItem {
  const ConnectionItem({required super.raw});

  String get type => raw['type'] as String? ?? 'unknown';
  String get model => raw['model'] as String? ?? '';
  String get host => raw['host'] as String? ?? '';
  String get url => raw['url'] as String? ?? '';
  bool get personalKey => raw['_personal_key'] == true;
  bool get isVirtual =>
      raw['is_virtual'] == true ||
      type == 'llm_orchestration' ||
      id.contains('::');
  int get tokensIn => (raw['tokens_in'] as num?)?.toInt() ?? 0;
  int get tokensOut => (raw['tokens_out'] as num?)?.toInt() ?? 0;
}

class ProviderFieldOption {
  const ProviderFieldOption({required this.value, required this.label});

  final String value;
  final String label;

  factory ProviderFieldOption.fromJson(Map<String, dynamic> json) {
    return ProviderFieldOption(
      value: json['value'] as String? ?? '',
      label: json['label'] as String? ?? '',
    );
  }
}

class ProviderField {
  const ProviderField({
    required this.key,
    required this.label,
    required this.type,
    required this.placeholder,
    required this.required,
    required this.defaultValue,
    required this.options,
    required this.dependsOn,
    required this.dependsValue,
  });

  final String key;
  final String label;
  final String type;
  final String placeholder;
  final bool required;
  final String defaultValue;
  final List<ProviderFieldOption> options;
  final String? dependsOn;
  final String? dependsValue;

  factory ProviderField.fromJson(Map<String, dynamic> json) {
    final optionsJson = json['options'];
    final options = <ProviderFieldOption>[];
    if (optionsJson is List) {
      for (final item in optionsJson) {
        if (item is Map<String, dynamic>) {
          options.add(ProviderFieldOption.fromJson(item));
        }
      }
    }

    return ProviderField(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      type: json['type'] as String? ?? 'text',
      placeholder: json['placeholder'] as String? ?? '',
      required: json['required'] == true,
      defaultValue: json['default'] as String? ?? '',
      options: options,
      dependsOn: json['depends_on'] as String?,
      dependsValue: json['depends_value'] as String?,
    );
  }
}

class ConnectionProvider {
  const ConnectionProvider({
    required this.type,
    required this.label,
    required this.icon,
    required this.category,
    required this.fields,
  });

  final String type;
  final String label;
  final String icon;
  final String category;
  final List<ProviderField> fields;

  factory ConnectionProvider.fromJson(Map<String, dynamic> json) {
    final fieldsJson = json['fields'];
    final fields = <ProviderField>[];
    if (fieldsJson is List) {
      for (final item in fieldsJson) {
        if (item is Map<String, dynamic>) {
          fields.add(ProviderField.fromJson(item));
        }
      }
    }

    return ConnectionProvider(
      type: json['type'] as String? ?? '',
      label: json['label'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      category: json['category'] as String? ?? 'llm',
      fields: fields,
    );
  }
}

class ConnectionTestResult {
  const ConnectionTestResult({
    required this.id,
    required this.ok,
    required this.message,
    this.detail,
    this.latencyMs,
  });

  final String id;
  final bool ok;
  final String message;
  final String? detail;
  final int? latencyMs;

  factory ConnectionTestResult.fromJson(Map<String, dynamic> json) {
    return ConnectionTestResult(
      id: json['id'] as String? ?? '',
      ok: json['ok'] == true,
      message: json['message'] as String? ?? '',
      detail: json['detail'] as String?,
      latencyMs: json['latency_ms'] as int?,
    );
  }
}
