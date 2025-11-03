import '../models/content_item.dart';

/// Abstraction for retrieving aggregated content from multiple services.
abstract interface class ContentRepository {
  Stream<List<FaioContent>> watchFeed();

  Future<List<FaioContent>> fetchFeedPage({
    required int page,
    int limit = 30,
    Iterable<String> tags = const [],
  });

  Future<List<FaioContent>> search({
    required String query,
    Iterable<String> tags = const [],
    Iterable<String> sources = const [],
  });
}
