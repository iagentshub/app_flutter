import '../../core/network/page_result.dart';

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
  String get category => raw['category']?.toString() ?? 'DIAGNOSTIC';
  String get action => raw['action']?.toString() ?? '';
  String get resourceType => raw['resource_type']?.toString() ?? '';
  String get resourceId => raw['resource_id']?.toString() ?? '';
  String get outcome => raw['outcome']?.toString() ?? '';
  String get detailsJson => raw['details_json']?.toString() ?? '';
}

class LogsPage {
  const LogsPage({
    required this.result,
    required this.page,
    required this.pageSize,
  });

  final PageResult<LogEntry> result;
  final int page;
  final int pageSize;

  List<LogEntry> get items => result.items;
  int get total => result.total ?? items.length;
  int get pages => total == 0 ? 0 : (total + pageSize - 1) ~/ pageSize;
  bool get hasMore => result.hasMore;
  String? get nextCursor => result.nextCursor;
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
  int get audits => _asInt(raw['audits']);
}
