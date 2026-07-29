class LogEntry {
  const LogEntry({required this.raw});

  final Map<String, dynamic> raw;

  int get id => raw['id'] is num ? (raw['id'] as num).toInt() : 0;
  String get date => raw['date']?.toString() ?? '';
  String get time => raw['time']?.toString() ?? '';
  String get ip => raw['ip']?.toString() ?? '-';
  String get username => raw['username']?.toString() ?? '-';
  String get level => raw['level']?.toString() ?? '';
  String get source => raw['source']?.toString() ?? '';
  String get summary => raw['summary']?.toString() ?? '';
}

class LogsPage {
  const LogsPage({required this.raw});

  final Map<String, dynamic> raw;

  List<LogEntry> get items {
    final value = raw['items'];
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map((item) => LogEntry(raw: item))
        .toList();
  }

  int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  int get total => _asInt(raw['total']);
  int get page => _asInt(raw['page']);
  int get pageSize => _asInt(raw['page_size']);
  int get pages => _asInt(raw['pages']);
}

class LogsSummaryDay {
  const LogsSummaryDay({required this.raw});

  final Map<String, dynamic> raw;

  String get date => raw['date']?.toString() ?? '';

  int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  int get lines => _asInt(raw['lines']);
  int get beWarnings => _asInt(raw['be_warnings']);
  int get beErrors => _asInt(raw['be_errors']);
  int get feWarnings => _asInt(raw['fe_warnings']);
  int get feErrors => _asInt(raw['fe_errors']);
  int get warnings => _asInt(raw['warnings']);
  int get errors => _asInt(raw['errors']);
}
