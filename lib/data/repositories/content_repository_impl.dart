import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/content_item.dart';
import '../../domain/repositories/content_repository.dart';
import '../../domain/repositories/pixiv_repository.dart';
import '../../domain/services/tag_filter.dart';
import '../e621/e621_auth.dart';
import '../e621/e621_credentials.dart';
import '../e621/e621_providers.dart';
import '../e621/e621_service.dart';
import '../pixiv/pixiv_auth.dart';
import '../pixiv/pixiv_credentials.dart';
import '../pixiv/pixiv_providers.dart';
import 'mappers/content_mapper.dart';
import '../../core/tagging/tag_preferences_provider.dart';

class ContentRepositoryImpl implements ContentRepository {
  ContentRepositoryImpl({
    required E621Service e621Service,
    required PixivRepository pixivRepository,
    required TagFilter Function() tagFilterResolver,
  }) : _e621Service = e621Service,
       _pixivRepository = pixivRepository,
       _tagFilterResolver = tagFilterResolver;

  final E621Service _e621Service;
  final PixivRepository _pixivRepository;
  final TagFilter Function() _tagFilterResolver;

  final StreamController<List<FaioContent>> _controller =
      StreamController<List<FaioContent>>.broadcast();
  bool _initialized = false;
  bool _disposed = false;

  @override
  Stream<List<FaioContent>> watchFeed() {
    if (!_initialized) {
      _initialized = true;
      unawaited(_refreshFeed());
    }
    return _controller.stream;
  }

  Future<void> _refreshFeed() async {
    if (_disposed) {
      return;
    }
    try {
      final items = await fetchFeedPage(page: 1);
      if (_disposed) {
        return;
      }
      _controller.add(items);
    } catch (error, stackTrace) {
      if (_disposed) {
        return;
      }
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
      String source,
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
        'e621',
        () => _fetchE621(page: page, limit: limit, tags: normalizedTags),
      ),
    );

    sources.add(
      safeFetch('pixiv', () => _fetchPixiv(page: page, limit: limit)),
    );

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

    final filtered = _filterItems(deduped);

    if (filtered.isEmpty && sourceErrors.isNotEmpty) {
      Error.throwWithStackTrace(sourceErrors.first, sourceStacks.first);
    }

    if (filtered.length > limit) {
      return filtered.sublist(0, limit);
    }
    return filtered;
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
      final filtered = _filterItems(items);
      filtered.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      return filtered;
    }

    final posts = await _e621Service.searchPosts(query: query);
    final items = posts
        .map(ContentMapper.fromE621)
        .whereType<FaioContent>()
        .toList();
    final filtered = _filterItems(items);
    filtered.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return filtered;
  }

  void dispose() {
    _disposed = true;
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

    final items = posts
        .map(ContentMapper.fromE621)
        .whereType<FaioContent>()
        .where((item) => item.type == ContentType.illustration)
        .toList();
    return _filterItems(items);
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

  List<FaioContent> _filterItems(List<FaioContent> items) {
    final filter = _tagFilterResolver();
    if (filter.isInactive) {
      return items;
    }
    return items.where(filter.allows).toList();
  }
}

final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  final e621Service = ref.watch(e621ServiceProvider);
  final pixivRepository = ref.watch(pixivRepositoryProvider);
  final tagFilterResolver = () => ref.read(tagFilterProvider);
  final repository = ContentRepositoryImpl(
    e621Service: e621Service,
    pixivRepository: pixivRepository,
    tagFilterResolver: tagFilterResolver,
  );
  ref.listen<E621Credentials?>(e621AuthProvider, (previous, next) {
    unawaited(repository.refreshFeed());
  });
  ref.listen<PixivCredentials?>(pixivAuthProvider, (previous, next) {
    unawaited(repository.refreshFeed());
  });
  ref.listen(tagPreferencesProvider, (previous, next) {
    if (previous?.valueOrNull != next.valueOrNull) {
      unawaited(repository.refreshFeed());
    }
  });
  ref.onDispose(repository.dispose);
  return repository;
}, name: 'contentRepositoryProvider');
