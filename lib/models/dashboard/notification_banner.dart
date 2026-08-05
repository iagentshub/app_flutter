class NotificationBanner {
  const NotificationBanner({required this.id, required this.message});

  final String id;
  final String message;

  factory NotificationBanner.fromJson(Map<String, dynamic> json) {
    final message = json['message'];
    if (message != null && message is! String) {
      throw const FormatException(
        'NotificationBanner.message must be a String',
      );
    }
    return NotificationBanner(
      id: json['id']?.toString() ?? '',
      message: message as String? ?? '',
    );
  }
}
