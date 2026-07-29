class ApiError implements Exception {
  ApiError({required this.statusCode, required this.message, this.code});

  final int statusCode;
  final String message;
  final String? code;

  @override
  String toString() => 'ApiError($statusCode): $message';
}
