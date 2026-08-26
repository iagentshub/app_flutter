class ApiError implements Exception {
  ApiError({
    required this.statusCode,
    required this.message,
    this.code,
    this.extra = const {},
  });

  final int statusCode;
  final String message;
  final String? code;
  final Map<String, dynamic> extra;

  @override
  String toString() => 'ApiError($statusCode): $message';
}
