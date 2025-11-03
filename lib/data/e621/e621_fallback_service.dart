import 'e621_service.dart';
import 'models/e621_post.dart';

/// Wraps two services and falls back to the secondary one when the primary
/// fails or returns empty results.
class E621FallbackService implements E621Service {
  E621FallbackService({
    required E621Service primary,
    required E621Service fallback,
  })  : _primary = primary,
        _fallback = fallback;

  final E621Service _primary;
  final E621Service _fallback;

  @override
  Future<List<E621Post>> fetchPosts({
    int page = 1,
    int limit = 20,
    List<String> tags = const [],
  }) async {
    return _execute(
      () => _primary.fetchPosts(page: page, limit: limit, tags: tags),
      () => _fallback.fetchPosts(page: page, limit: limit, tags: tags),
    );
  }

  @override
  Future<List<E621Post>> searchPosts({
    required String query,
    int page = 1,
    int limit = 20,
  }) async {
    return _execute(
      () => _primary.searchPosts(query: query, page: page, limit: limit),
      () => _fallback.searchPosts(query: query, page: page, limit: limit),
    );
  }

  Future<List<E621Post>> _execute(
    Future<List<E621Post>> Function() primary,
    Future<List<E621Post>> Function() fallback,
  ) async {
    try {
      final result = await primary();
      if (result.isNotEmpty) {
        return result;
      }
    } catch (_) {
      // swallow and fallback
    }
    return fallback();
  }
}
