class NotificationBanner {
  const NotificationBanner({required this.id, required this.message});

  final String id;
  final String message;

  factory NotificationBanner.fromJson(Map<String, dynamic> json) {
    return NotificationBanner(
      id: json['id']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
    );
  }
}
