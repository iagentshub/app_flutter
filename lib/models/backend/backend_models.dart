class BackendPingResult {
  const BackendPingResult({required this.ok, this.statusCode, this.error});

  final bool ok;
  final int? statusCode;
  final String? error;
}

class SavedBackend {
  const SavedBackend({required this.id, required this.name, required this.url});

  final String id;
  final String name;
  final String url;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'url': url};

  factory SavedBackend.fromJson(Map<String, dynamic> json) => SavedBackend(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    url: json['url']?.toString() ?? '',
  );
}
