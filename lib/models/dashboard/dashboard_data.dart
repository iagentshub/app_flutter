class TokenDailyPoint {
  const TokenDailyPoint({required this.day, required this.tokens});

  final String day;
  final int tokens;

  factory TokenDailyPoint.fromJson(Map<String, dynamic> json) {
    final day = json['day'] ?? json['date'] ?? '';
    final tokensRaw = json['tokens'] ?? json['SUM(tokens)'];
    return TokenDailyPoint(
      day: day.toString(),
      tokens: tokensRaw is num
          ? tokensRaw.toInt()
          : int.tryParse('$tokensRaw') ?? 0,
    );
  }
}

class ConnectionTestResult {
  const ConnectionTestResult({
    required this.id,
    required this.ok,
    this.message,
    this.latencyMs,
  });

  final String id;
  final bool ok;
  final String? message;
  final int? latencyMs;

  factory ConnectionTestResult.fromJson(Map<String, dynamic> json) {
    return ConnectionTestResult(
      id: json['id']?.toString() ?? '',
      ok: json['ok'] == true,
      message: json['message']?.toString(),
      latencyMs: (json['latency_ms'] as num?)?.toInt(),
    );
  }
}

class DashboardData {
  const DashboardData({
    required this.agents,
    required this.connections,
    required this.knowledge,
    required this.workflows,
    required this.skills,
    required this.memory,
    required this.tokenDaily,
    this.agentTotalOverride,
    this.skillTotalOverride,
    this.toolTotalOverride,
    this.groups = const [],
    this.invitations = const [],
    this.conversations = const [],
    this.tools = const [],
  });

  final List<Map<String, dynamic>> agents;
  final List<Map<String, dynamic>> connections;
  final List<Map<String, dynamic>> knowledge;
  final List<Map<String, dynamic>> workflows;
  final List<Map<String, dynamic>> skills;
  final List<Map<String, dynamic>> memory;
  final List<Map<String, dynamic>> tools;
  final List<TokenDailyPoint> tokenDaily;
  final List<Map<String, dynamic>> groups;
  final List<Map<String, dynamic>> invitations;
  final List<Map<String, dynamic>> conversations;
  final int? agentTotalOverride;
  final int? skillTotalOverride;
  final int? toolTotalOverride;

  int get agentTotal => agentTotalOverride ?? agents.length;
  int get skillTotal => skillTotalOverride ?? skills.length;
  int get toolTotal => toolTotalOverride ?? tools.length;
  bool get agentsAreComplete => agentTotal == agents.length;

  List<MapEntry<Map<String, dynamic>, int>> get connectionsByTokens {
    final rows = connections
        .map((c) {
          final tokensIn = (c['tokens_in'] as num?)?.toInt() ?? 0;
          final tokensOut = (c['tokens_out'] as num?)?.toInt() ?? 0;
          return MapEntry(c, tokensIn + tokensOut);
        })
        .where((entry) => entry.value > 0)
        .toList();
    rows.sort((a, b) => b.value.compareTo(a.value));
    return rows;
  }
}
