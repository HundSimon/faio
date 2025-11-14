import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/e621/e621_providers.dart';
import '../../../data/pixiv/pixiv_providers.dart';
import '../../../data/repositories/mappers/content_mapper.dart';
import '../../../domain/models/content_item.dart';
import '../../../domain/models/content_page.dart';

enum IllustrationSource { pixiv, e621 }

const _pageSize = 30;

typedef FeedPageFetcher =
    Future<ContentPageResult> Function(int page, int limit);
typedef FeedItemFilter = bool Function(FaioContent item);

class FeedState {
  const FeedState({
    this.items = const [],
    this.isLoadingInitial = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.currentPage = 0,
    this.lastError,
    this.seenIds = const <String>{},
  });

  final List<FaioContent> items;
  final bool isLoadingInitial;
  final bool isLoadingMore;
  final bool hasMore;
  final int currentPage;
  final Object? lastError;
  final Set<String> seenIds;

  static const Object _sentinel = Object();

  FeedState copyWith({
    List<FaioContent>? items,
    bool? isLoadingInitial,
    bool? isLoadingMore,
    bool? hasMore,
    int? currentPage,
    Object? lastError = _sentinel,
    Set<String>? seenIds,
  }) {
    return FeedState(
      items: items ?? this.items,
      isLoadingInitial: isLoadingInitial ?? this.isLoadingInitial,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      lastError: identical(lastError, _sentinel) ? this.lastError : lastError,
      seenIds: seenIds ?? this.seenIds,
    );
  }
}

class FeedController extends StateNotifier<FeedState> {
  FeedController({required FeedPageFetcher fetchPage, FeedItemFilter? filter})
    : _fetchPage = fetchPage,
      _filter = filter ?? _defaultFilter,
      super(const FeedState()) {
    _loadInitial();
  }

  final FeedPageFetcher _fetchPage;
  final FeedItemFilter _filter;

  static bool _defaultFilter(FaioContent item) => true;

  Future<void> _loadInitial() async {
    state = state.copyWith(isLoadingInitial: true, lastError: null);

    try {
      final firstPage = await _fetchPage(1, _pageSize);
      if (!mounted) return;

      final filtered = firstPage.items.where(_filter).toList();
      final seen = filtered.map((item) => item.id).toSet();

      state = state.copyWith(
        items: filtered,
        currentPage: firstPage.page,
        hasMore: firstPage.hasMore,
        isLoadingInitial: false,
        seenIds: seen,
        lastError: null,
      );
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(isLoadingInitial: false, lastError: error);
    }
  }

  Future<void> refresh() async {
    if (state.isLoadingInitial) return;
    await _loadInitial();
  }

  Future<void> loadMore() async {
    final current = state;
    if (current.isLoadingMore || !current.hasMore) {
      return;
    }

    state = current.copyWith(isLoadingMore: true, lastError: null);

    try {
      final nextPage = max(current.currentPage, 1) + 1;
      final result = await _fetchPage(nextPage, _pageSize);
      if (!mounted) return;

      final latest = state;
      final filtered = result.items.where(_filter).toList();
      final unique = filtered
          .where((item) => !latest.seenIds.contains(item.id))
          .toList();

      final updatedItems = [...latest.items, ...unique];
      final updatedSeen = {...latest.seenIds, ...unique.map((item) => item.id)};
      final hasNewItems = unique.isNotEmpty;
      // Stop paginating once the backend stops yielding unseen items to avoid endless spinners.
      final nextHasMore = hasNewItems ? result.hasMore : false;

      state = latest.copyWith(
        items: updatedItems,
        currentPage: result.page,
        hasMore: nextHasMore,
        isLoadingMore: false,
        seenIds: updatedSeen,
        lastError: null,
      );
    } catch (error) {
      if (!mounted) return;
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
}

final illustrationFeedControllerProvider =
    StateNotifierProvider.autoDispose
        .family<FeedController, FeedState, IllustrationSource>((ref, source) {
      switch (source) {
        case IllustrationSource.pixiv:
          final repository = ref.watch(pixivRepositoryProvider);
          return FeedController(
            fetchPage: (page, limit) =>
                repository.fetchIllustrations(page: page, limit: limit),
            filter: (item) => item.type == ContentType.illustration,
          );
        case IllustrationSource.e621:
          final service = ref.watch(e621ServiceProvider);
          return FeedController(
            fetchPage: (page, limit) async {
              final posts = await service.fetchPosts(page: page, limit: limit);
              final items = posts
                  .map(ContentMapper.fromE621)
                  .whereType<FaioContent>()
                  .where((item) => item.type == ContentType.illustration)
                  .toList();
              final hasMore = posts.length >= limit;
              return ContentPageResult(
                items: items,
                page: page,
                hasMore: hasMore,
              );
            },
          );
      }
    }, name: 'illustrationFeedControllerProvider');

final pixivMangaFeedControllerProvider =
    StateNotifierProvider.autoDispose<FeedController, FeedState>((ref) {
      final repository = ref.watch(pixivRepositoryProvider);
      return FeedController(
        fetchPage: (page, limit) =>
            repository.fetchManga(page: page, limit: limit),
        filter: (item) => item.type == ContentType.comic,
      );
    }, name: 'pixivMangaFeedControllerProvider');

final pixivNovelFeedControllerProvider =
    StateNotifierProvider.autoDispose<FeedController, FeedState>((ref) {
      final repository = ref.watch(pixivRepositoryProvider);
      return FeedController(
        fetchPage: (page, limit) =>
            repository.fetchNovels(page: page, limit: limit),
        filter: (item) => item.type == ContentType.novel,
      );
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
