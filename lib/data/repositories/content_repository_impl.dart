import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/content_item.dart';
import '../../domain/repositories/content_repository.dart';
import '../e621/e621_mock_service.dart';
import '../e621/e621_service.dart';
import 'mappers/content_mapper.dart';

class ContentRepositoryImpl implements ContentRepository {
  ContentRepositoryImpl({
    required E621Service e621Service,
  }) : _e621Service = e621Service;

  final E621Service _e621Service;

  final StreamController<List<FaioContent>> _controller =
      StreamController<List<FaioContent>>.broadcast();
  bool _initialized = false;

  @override
  Stream<List<FaioContent>> watchFeed() {
    if (!_initialized) {
      _initialized = true;
      unawaited(_refreshFeed());
    }
    return _controller.stream;
  }

  Future<void> _refreshFeed() async {
    final posts = await _e621Service.fetchPosts(limit: 30);
    final items = posts.map(ContentMapper.fromE621).toList(growable: false);
    _controller.add(items);
  }

  @override
  Future<List<FaioContent>> search({
    required String query,
    Iterable<String> tags = const [],
    Iterable<String> sources = const [],
  }) async {
    if (sources.isNotEmpty && !sources.contains('e621')) {
      return const [];
    }

    final normalizedTags = tags.toList();
    if (normalizedTags.isNotEmpty) {
      final posts = await _e621Service.fetchPosts(tags: normalizedTags);
      return posts.map(ContentMapper.fromE621).toList(growable: false);
    }

    final posts = await _e621Service.searchPosts(query: query);
    return posts.map(ContentMapper.fromE621).toList(growable: false);
  }

  void dispose() {
    _controller.close();
  }
}

final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  final e621Service = ref.watch(e621ServiceProvider);
  final repository = ContentRepositoryImpl(e621Service: e621Service);
  ref.onDispose(repository.dispose);
  return repository;
}, name: 'contentRepositoryProvider');
