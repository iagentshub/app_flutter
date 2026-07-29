import '../../../core/network/api_client.dart';
import '../../../models/explore/explore_models.dart';

class PublicFollowStatus {
  const PublicFollowStatus({
    required this.following,
    required this.followersCount,
    required this.followingCount,
  });

  final bool following;
  final int followersCount;
  final int followingCount;

  factory PublicFollowStatus.fromJson(Map<String, dynamic> json) {
    int asInt(Object? value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return 0;
    }

    return PublicFollowStatus(
      following: json['following'] == true,
      followersCount: asInt(json['followers_count']),
      followingCount: asInt(json['following_count']),
    );
  }
}

class PublicProfileRepository {
  PublicProfileRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<List<ExploreItem>> listResources(
    String token, {
    required String username,
    String type = 'all',
  }) async {
    final response = await apiClient.get(
      '/api/users/${Uri.encodeComponent(username)}/resources?type=${Uri.encodeQueryComponent(type)}',
      gaToken: token,
      cache: true,
    );
    final payload = response.body;
    if (payload is! List) return const [];
    return payload
        .whereType<Map<String, dynamic>>()
        .map((item) => ExploreItem(raw: item))
        .toList();
  }

  Future<PublicFollowStatus> getFollowStatus(
    String token,
    String username,
  ) async {
    final response = await apiClient.get(
      '/api/users/${Uri.encodeComponent(username)}/follow-status',
      gaToken: token,
      cache: true,
    );
    return PublicFollowStatus.fromJson(response.json);
  }

  Future<void> follow(String token, String username) async {
    await apiClient.post(
      '/api/users/${Uri.encodeComponent(username)}/follow',
      gaToken: token,
    );
  }

  Future<void> unfollow(String token, String username) async {
    await apiClient.delete(
      '/api/users/${Uri.encodeComponent(username)}/follow',
      gaToken: token,
    );
  }
}
