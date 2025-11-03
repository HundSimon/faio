import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sample/sample_feed.dart';
import '../../domain/models/content_item.dart';
import '../../domain/repositories/content_repository.dart';

/// Simple in-memory repository used for prototyping UI without live services.
class MockContentRepository implements ContentRepository {
  MockContentRepository({
    required List<FaioContent> seedItems,
  }) : _controller = StreamController<List<FaioContent>>.broadcast() {
    _items = List.unmodifiable(seedItems);
    _controller.add(_items);
  }

  late final List<FaioContent> _items;
  final StreamController<List<FaioContent>> _controller;

  @override
  Stream<List<FaioContent>> watchFeed() => _controller.stream;

  @override
  Future<List<FaioContent>> search({
    required String query,
    Iterable<String> tags = const [],
    Iterable<String> sources = const [],
  }) async {
    final lower = query.toLowerCase();
    return _items.where((item) {
      final matchesQuery =
          item.title.toLowerCase().contains(lower) || item.summary.toLowerCase().contains(lower);
      final matchesTags = tags.isEmpty || tags.any(item.tags.contains);
      final matchesSources = sources.isEmpty || sources.contains(item.source);
      return matchesQuery && matchesTags && matchesSources;
    }).toList();
  }

  void dispose() {
    _controller.close();
  }
}

final mockContentRepositoryProvider = Provider<ContentRepository>((ref) {
  final mockItems = buildSampleFeedItems();
  final repository = MockContentRepository(seedItems: mockItems);
  ref.onDispose(repository.dispose);
  return repository;
});
