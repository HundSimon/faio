import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/content_item.dart';
import '../../domain/repositories/content_repository.dart';
import '../../domain/repositories/pixiv_repository.dart';
import '../e621/e621_auth.dart';
import '../e621/e621_credentials.dart';
import '../e621/e621_providers.dart';
import '../e621/e621_service.dart';
import '../pixiv/pixiv_auth.dart';
import '../pixiv/pixiv_credentials.dart';
import '../pixiv/pixiv_providers.dart';
import 'mappers/content_mapper.dart';

class ContentRepositoryImpl implements ContentRepository {
  ContentRepositoryImpl({
    required E621Service e621Service,
    required PixivRepository pixivRepository,
  }) : _e621Service = e621Service,
       _pixivRepository = pixivRepository;

  final E621Service _e621Service;
  final PixivRepository _pixivRepository;

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
    try {
      final items = await fetchFeedPage(page: 1);
      _controller.add(items);
    } catch (error, stackTrace) {
      _controller.addError(error, stackTrace);
    }
  }

  Future<void> refreshFeed() => _refreshFeed();

  @override
  Future<List<FaioContent>> fetchFeedPage({
    required int page,
    int limit = 30,
    Iterable<String> tags = const [],
  }) async {
    final normalizedTags = tags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);

    final sources = <Future<List<FaioContent>>>[];
    final sourceErrors = <Object>[];
    final sourceStacks = <StackTrace>[];

    Future<List<FaioContent>> safeFetch(
      Future<List<FaioContent>> Function() fetch,
    ) async {
      try {
        return await fetch();
      } catch (error, stackTrace) {
        sourceErrors.add(error);
        sourceStacks.add(stackTrace);
        return const [];
      }
    }

    sources.add(
      safeFetch(
        () => _fetchE621(page: page, limit: limit, tags: normalizedTags),
      ),
    );

    sources.add(safeFetch(() => _fetchPixiv(page: page, limit: limit)));

    final results = await Future.wait(sources);

    final combined = results.expand((list) => list).toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    final deduped = <FaioContent>[];
    final seenIds = <String>{};
    for (final item in combined) {
      if (item.type != ContentType.illustration) {
        continue;
      }
      if (seenIds.add(item.id)) {
        deduped.add(item);
      }
    }

    if (deduped.isEmpty && sourceErrors.isNotEmpty) {
      Error.throwWithStackTrace(sourceErrors.first, sourceStacks.first);
    }

    if (deduped.length > limit) {
      return deduped.sublist(0, limit);
    }
    return deduped;
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
      final items = posts
          .map(ContentMapper.fromE621)
          .whereType<FaioContent>()
          .toList();
      items.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      return items;
    }

    final posts = await _e621Service.searchPosts(query: query);
    final items = posts
        .map(ContentMapper.fromE621)
        .whereType<FaioContent>()
        .toList();
    items.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return items;
  }

  void dispose() {
    _controller.close();
  }

  Future<List<FaioContent>> _fetchE621({
    required int page,
    required int limit,
    required List<String> tags,
  }) async {
    final posts = await _e621Service.fetchPosts(
      page: page,
      limit: limit,
      tags: tags,
    );

    return posts
        .map(ContentMapper.fromE621)
        .whereType<FaioContent>()
        .where((item) => item.type == ContentType.illustration)
        .toList();
  }

  Future<List<FaioContent>> _fetchPixiv({
    required int page,
    required int limit,
  }) async {
    final result = await _pixivRepository.fetchIllustrations(
      page: page,
      limit: limit,
    );
    return result.items
        .where((item) => item.type == ContentType.illustration)
        .toList();
  }
}

final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  final e621Service = ref.watch(e621ServiceProvider);
  final pixivRepository = ref.watch(pixivRepositoryProvider);
  final repository = ContentRepositoryImpl(
    e621Service: e621Service,
    pixivRepository: pixivRepository,
  );
  ref.listen<E621Credentials?>(e621AuthProvider, (previous, next) {
    unawaited(repository.refreshFeed());
  });
  ref.listen<PixivCredentials?>(pixivAuthProvider, (previous, next) {
    unawaited(repository.refreshFeed());
  });
  ref.onDispose(repository.dispose);
  return repository;
}, name: 'contentRepositoryProvider');
