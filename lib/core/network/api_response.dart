class ApiResponse {
  const ApiResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
  });

  final int statusCode;
  final Map<String, String> headers;
  final Object? body;

  bool get isOk => statusCode >= 200 && statusCode < 300;

  Map<String, dynamic> get json {
    if (body is Map<String, dynamic>) return body as Map<String, dynamic>;
    return <String, dynamic>{'data': body};
  }
}
