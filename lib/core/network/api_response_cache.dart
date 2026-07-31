import 'api_response.dart';

typedef ApiCacheKey = ({String baseUrl, String? gaToken, String path});

class ApiResponseCache {
  final Map<ApiCacheKey, ({DateTime expiresAt, ApiResponse response})>
  _entries = {};
  final Map<ApiCacheKey, Future<ApiResponse>> _inFlight = {};
  static const defaultTtl = Duration(seconds: 60);
  static const _maxEntries = 200;
  int _generation = 0;

  int get entryCount => _entries.length;
  int get inFlightCount => _inFlight.length;
  int get generation => _generation;

  ApiResponse? read(ApiCacheKey key, DateTime now) {
    final cached = _entries[key];
    if (cached == null) return null;
    if (now.isBefore(cached.expiresAt)) return cached.response;
    _entries.remove(key);
    return null;
  }

  Future<ApiResponse>? inFlight(ApiCacheKey key) => _inFlight[key];

  void track(ApiCacheKey key, Future<ApiResponse> request) {
    _inFlight[key] = request;
  }

  void untrack(ApiCacheKey key, Future<ApiResponse> request) {
    if (identical(_inFlight[key], request)) _inFlight.remove(key);
  }

  void store(
    ApiCacheKey key,
    ApiResponse response, {
    required int requestGeneration,
    required DateTime now,
    required Duration ttl,
  }) {
    if (requestGeneration != _generation) return;
    _entries.removeWhere((_, entry) => !now.isBefore(entry.expiresAt));
    _entries[key] = (expiresAt: now.add(ttl), response: response);
    while (_entries.length > _maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  void invalidate([String? pathPrefix]) {
    _generation += 1;
    if (pathPrefix == null) {
      _entries.clear();
      return;
    }
    _entries.removeWhere((key, _) => key.path.startsWith(pathPrefix));
  }

  void invalidateForMutation(String path) {
    final withoutQuery = path.split('?').first;
    final segments = withoutQuery
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();
    final root = segments.length >= 2 ? '/${segments[0]}/${segments[1]}' : path;
    invalidate(root);
  }

  void clear() {
    _generation += 1;
    _entries.clear();
    _inFlight.clear();
  }
}
