import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/e621/e621_providers.dart';
import '../../../data/pixiv/pixiv_providers.dart';
import '../../../data/repositories/mappers/content_mapper.dart';
import '../../../data/repositories/content_repository_impl.dart';
import '../../../domain/models/content_item.dart';
import '../../../domain/models/content_page.dart';
import '../../../core/tagging/tag_preferences_provider.dart';

enum IllustrationSource { mixed, pixiv, e621 }

const _pageSize = 30;

typedef FeedPageFetcher =
    Future<ContentPageResult> Function(int page, int limit);
typedef FeedItemFilter = bool Function(FaioContent item);
typedef FeedItemComparator = int Function(FaioContent a, FaioContent b);

int _compareByPublishedAtDesc(FaioContent a, FaioContent b) {
  final cmp = b.publishedAt.compareTo(a.publishedAt);
  if (cmp != 0) {
    return cmp;
  }
  return a.id.compareTo(b.id);
}

bool _isPixivSource(FaioContent item) {
  final source = item.source.toLowerCase();
  return source == 'pixiv' || source.startsWith('pixiv:');
}

class FeedState {
  const FeedState({
    this.items = const [],
    this.isLoadingInitial = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.currentPage = 0,
    this.lastError,
    this.seenIds = const <String>{},
    this.hiddenTrailingItems = const [],
  });

  final List<FaioContent> items;
  final bool isLoadingInitial;
  final bool isLoadingMore;
  final bool hasMore;
  final int currentPage;
  final Object? lastError;
  final Set<String> seenIds;
  final List<FaioContent> hiddenTrailingItems;

  static const Object _sentinel = Object();

  FeedState copyWith({
    List<FaioContent>? items,
    bool? isLoadingInitial,
    bool? isLoadingMore,
    bool? hasMore,
    int? currentPage,
    Object? lastError = _sentinel,
    Set<String>? seenIds,
    List<FaioContent>? hiddenTrailingItems,
  }) {
    return FeedState(
      items: items ?? this.items,
      isLoadingInitial: isLoadingInitial ?? this.isLoadingInitial,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      lastError: identical(lastError, _sentinel) ? this.lastError : lastError,
      seenIds: seenIds ?? this.seenIds,
      hiddenTrailingItems: hiddenTrailingItems ?? this.hiddenTrailingItems,
    );
  }
}

class FeedController extends StateNotifier<FeedState> {
  FeedController({
    required FeedPageFetcher fetchPage,
    FeedItemFilter? filter,
    FeedItemComparator? sortComparator,
    String? debugLabel,
  }) : _fetchPage = fetchPage,
      _filter = filter ?? _defaultFilter,
      _sortComparator = sortComparator,
      _debugLabel = debugLabel,
      super(const FeedState()) {
    _loadInitial();
  }

  final FeedPageFetcher _fetchPage;
  final FeedItemFilter _filter;
  final FeedItemComparator? _sortComparator;
  final String? _debugLabel;

  static bool _defaultFilter(FaioContent item) => true;

  bool get _shouldBalancePixiv => _debugLabel?.contains('mixed') ?? false;

  void _log(String message) {
    final label = _debugLabel;
    if (label == null) {
      return;
    }
    debugPrint('[$label] $message');
  }

  Future<void> _loadInitial() async {
    state = state.copyWith(isLoadingInitial: true, lastError: null);

    try {
      _log('Loading initial page with limit $_pageSize');
      final firstPage = await _fetchPage(1, _pageSize);
      if (!mounted) return;

      final filtered = firstPage.items.where(_filter).toList();
      final comparator = _sortComparator;
      if (comparator != null) {
        filtered.sort(comparator);
      }
      final seen = filtered.map((item) => item.id).toSet();
      final balanced = _applyTrailingPixivPolicy(
        filtered,
        const [],
      );

      state = state.copyWith(
        items: List.unmodifiable(balanced.visible),
        currentPage: firstPage.page,
        hasMore: firstPage.hasMore || balanced.hidden.isNotEmpty,
        isLoadingInitial: false,
        seenIds: seen,
        hiddenTrailingItems: List.unmodifiable(balanced.hidden),
        lastError: null,
      );
      _log(
        'Loaded ${balanced.visible.length} initial items '
        '(hiddenPixiv=${balanced.hidden.length}, hasMore=${firstPage.hasMore || balanced.hidden.isNotEmpty})',
      );
    } catch (error) {
      if (!mounted) return;
      _log('Initial load failed: $error');
      state = state.copyWith(isLoadingInitial: false, lastError: error);
    }
  }

  Future<void> refresh() async {
    if (state.isLoadingInitial) return;
    _log('Refreshing feed');
    await _loadInitial();
  }

  Future<void> loadMore() async {
    final current = state;
    if (current.isLoadingMore || !current.hasMore) {
      _log(
        'Skipping loadMore (isLoadingMore=${current.isLoadingMore}, hasMore=${current.hasMore})',
      );
      return;
    }

    state = current.copyWith(isLoadingMore: true, lastError: null);

    try {
      final nextPage = max(current.currentPage, 1) + 1;
      _log('Loading page $nextPage with limit $_pageSize');
      final result = await _fetchPage(nextPage, _pageSize);
      if (!mounted) return;

      final latest = state;
      final filtered = result.items.where(_filter).toList();
      final unique = filtered
          .where((item) => !latest.seenIds.contains(item.id))
          .toList();

      final updatedItems = [...latest.items, ...unique];
      final comparator = _sortComparator;
      if (comparator != null) {
        updatedItems.sort(comparator);
      }
      final balanced = _applyTrailingPixivPolicy(
        updatedItems,
        latest.hiddenTrailingItems,
      );
      final updatedSeen = {...latest.seenIds, ...unique.map((item) => item.id)};
      // Keep paginating while backend has more data or we still have hidden Pixiv items waiting.
      final nextHasMore = result.hasMore || balanced.hidden.isNotEmpty;

      state = latest.copyWith(
        items: List.unmodifiable(balanced.visible),
        currentPage: result.page,
        hasMore: nextHasMore,
        isLoadingMore: false,
        seenIds: updatedSeen,
        hiddenTrailingItems: List.unmodifiable(balanced.hidden),
        lastError: null,
      );
      _log(
        'Loaded page $nextPage: received ${filtered.length} items, appended ${unique.length} new '
        '(hiddenPixiv=${balanced.hidden.length}, hasMore=${result.hasMore}, nextHasMore=$nextHasMore)',
      );
    } catch (error) {
      if (!mounted) return;
      _log('loadMore failed: $error');
      state = state.copyWith(isLoadingMore: false, lastError: error);
    }
  }

  Future<void> ensureIndexLoaded(int index) async {
    var attempts = 0;
    while (index >= state.items.length && state.hasMore) {
      final previousLength = state.items.length;
      await loadMore();
      attempts += 1;
      if (!state.hasMore) {
        break;
      }
      if (state.items.length == previousLength) {
        if (attempts >= 3) {
          break;
        }
      } else {
        attempts = 0;
      }
    }
  }

  _TrailingPixivBalance _applyTrailingPixivPolicy(
    List<FaioContent> items,
    List<FaioContent> previousHidden,
  ) {
    if (!_shouldBalancePixiv) {
      final sorted = _sort(items);
      return _TrailingPixivBalance(visible: sorted, hidden: const []);
    }
    final combined = [...items, ...previousHidden];
    if (combined.isEmpty) {
      return const _TrailingPixivBalance(
        visible: [],
        hidden: [],
      );
    }
    final sorted = _sort(combined);
    final firstPixivIndex = sorted.indexWhere(_isPixivSource);
    if (firstPixivIndex <= 0) {
      return _TrailingPixivBalance(visible: sorted, hidden: const []);
    }
    final hasNonPixivAfterFirstPixiv = sorted
        .skip(firstPixivIndex)
        .any((item) => !_isPixivSource(item));
    if (hasNonPixivAfterFirstPixiv) {
      return _TrailingPixivBalance(visible: sorted, hidden: const []);
    }
    final visible = sorted.sublist(0, firstPixivIndex);
    final hidden = sorted.sublist(firstPixivIndex);
    return _TrailingPixivBalance(
      visible: List.unmodifiable(visible),
      hidden: List.unmodifiable(hidden),
    );
  }

  List<FaioContent> _sort(List<FaioContent> items) {
    final comparator = _sortComparator ?? _compareByPublishedAtDesc;
    final sorted = [...items];
    sorted.sort(comparator);
    return sorted;
  }
}

class _TrailingPixivBalance {
  const _TrailingPixivBalance({
    required this.visible,
    required this.hidden,
  });

  final List<FaioContent> visible;
  final List<FaioContent> hidden;
}

final illustrationFeedControllerProvider = StateNotifierProvider.autoDispose
    .family<FeedController, FeedState, IllustrationSource>((ref, source) {
      switch (source) {
        case IllustrationSource.mixed:
          final repository = ref.watch(contentRepositoryProvider);
          final controller = FeedController(
            fetchPage: (page, limit) async {
              debugPrint(
                '[mixed-feed] Requesting combined page=$page limit=$limit',
              );
              final items = await repository.fetchFeedPage(
                page: page,
                limit: limit,
              );
              final limited = items.take(limit).toList();
              final hasMore = limited.length >= limit;
              debugPrint(
                '[mixed-feed] Received ${limited.length} items for page=$page (hasMore=$hasMore)',
              );
              return ContentPageResult(
                items: limited,
                page: page,
                hasMore: hasMore,
              );
            },
            filter: (item) => item.type == ContentType.illustration,
            sortComparator: _compareByPublishedAtDesc,
            debugLabel: 'mixed-feed',
          );
          ref.listen(tagPreferencesProvider, (previous, next) {
            if (previous?.valueOrNull != next.valueOrNull) {
              controller.refresh();
            }
          });
          return controller;
        case IllustrationSource.pixiv:
          final repository = ref.watch(pixivRepositoryProvider);
          final controller = FeedController(
            fetchPage: (page, limit) =>
                repository.fetchIllustrations(page: page, limit: limit),
            filter: (item) => item.type == ContentType.illustration,
          );
          ref.listen(tagPreferencesProvider, (previous, next) {
            if (previous?.valueOrNull != next.valueOrNull) {
              controller.refresh();
            }
          });
          return controller;
        case IllustrationSource.e621:
          final service = ref.watch(e621ServiceProvider);
          final filterResolver = () => ref.read(tagFilterProvider);
          final controller = FeedController(
            fetchPage: (page, limit) async {
              final posts = await service.fetchPosts(page: page, limit: limit);
              final items = posts
                  .map(ContentMapper.fromE621)
                  .whereType<FaioContent>()
                  .where((item) => item.type == ContentType.illustration)
                  .toList();
              final filter = filterResolver();
              final filtered = filter.isInactive
                  ? items
                  : items.where(filter.allows).toList();
              final hasMore = posts.length >= limit;
              return ContentPageResult(
                items: filtered,
                page: page,
                hasMore: hasMore,
              );
            },
          );
          ref.listen(tagPreferencesProvider, (previous, next) {
            if (previous?.valueOrNull != next.valueOrNull) {
              controller.refresh();
            }
          });
          return controller;
      }
    }, name: 'illustrationFeedControllerProvider');

final pixivMangaFeedControllerProvider =
    StateNotifierProvider.autoDispose<FeedController, FeedState>((ref) {
      final repository = ref.watch(pixivRepositoryProvider);
      final controller = FeedController(
        fetchPage: (page, limit) =>
            repository.fetchManga(page: page, limit: limit),
        filter: (item) => item.type == ContentType.comic,
      );
      ref.listen(tagPreferencesProvider, (previous, next) {
        if (previous?.valueOrNull != next.valueOrNull) {
          controller.refresh();
        }
      });
      return controller;
    }, name: 'pixivMangaFeedControllerProvider');

final pixivNovelFeedControllerProvider =
    StateNotifierProvider.autoDispose<FeedController, FeedState>((ref) {
      final repository = ref.watch(pixivRepositoryProvider);
      final controller = FeedController(
        fetchPage: (page, limit) =>
            repository.fetchNovels(page: page, limit: limit),
        filter: (item) => item.type == ContentType.novel,
      );
      ref.listen(tagPreferencesProvider, (previous, next) {
        if (previous?.valueOrNull != next.valueOrNull) {
          controller.refresh();
        }
      });
      return controller;
    }, name: 'pixivNovelFeedControllerProvider');

final feedSelectionProvider =
    StateNotifierProvider.autoDispose<
      FeedSelectionController,
      FeedSelectionState
    >((ref) {
      return FeedSelectionController();
    }, name: 'feedSelectionProvider');

class FeedSelectionState {
  const FeedSelectionState({
    this.selectedSource,
    this.selectedIndex,
    this.pendingScrollSource,
    this.pendingScrollIndex,
  });

  final IllustrationSource? selectedSource;
  final int? selectedIndex;
  final IllustrationSource? pendingScrollSource;
  final int? pendingScrollIndex;

  FeedSelectionState copyWith({
    IllustrationSource? selectedSource,
    int? selectedIndex,
    IllustrationSource? pendingScrollSource,
    int? pendingScrollIndex,
    bool clearPendingScroll = false,
    bool clearSelection = false,
  }) {
    return FeedSelectionState(
      selectedSource: clearSelection
          ? null
          : selectedSource ?? this.selectedSource,
      selectedIndex: clearSelection
          ? null
          : selectedIndex ?? this.selectedIndex,
      pendingScrollSource: clearPendingScroll
          ? null
          : pendingScrollSource ?? this.pendingScrollSource,
      pendingScrollIndex: clearPendingScroll
          ? null
          : pendingScrollIndex ?? this.pendingScrollIndex,
    );
  }
}

class FeedSelectionController extends StateNotifier<FeedSelectionState> {
  FeedSelectionController() : super(const FeedSelectionState());

  void select(IllustrationSource source, int index) {
    state = state.copyWith(selectedSource: source, selectedIndex: index);
  }

  void requestScrollTo(IllustrationSource source, int index) {
    state = state.copyWith(
      pendingScrollSource: source,
      pendingScrollIndex: index,
    );
  }

  void clearScrollRequest() {
    state = state.copyWith(clearPendingScroll: true);
  }

  void clearSelection() {
    state = state.copyWith(clearSelection: true);
  }
}
