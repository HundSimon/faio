import 'models/e621_post.dart';

/// Contract for interacting with e621. Implementations can be real HTTP
/// clients or local fixtures for development.
abstract interface class E621Service {
  Future<List<E621Post>> fetchPosts({
    int page = 1,
    int limit = 20,
    List<String> tags = const [],
  });

  Future<List<E621Post>> searchPosts({
    required String query,
    int page = 1,
    int limit = 20,
  });
}
