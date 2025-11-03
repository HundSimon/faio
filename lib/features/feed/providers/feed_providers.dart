import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/content_repository_impl.dart';
import '../../../domain/models/content_item.dart';
import '../../../domain/repositories/content_repository.dart';

const _pageSize = 30;

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
  FeedController({required ContentRepository repository, required this.ref})
    : _repository = repository,
      super(const FeedState()) {
    _loadInitial();
  }

  final ContentRepository _repository;
  final Ref ref;

  Future<void> _loadInitial() async {
    state = state.copyWith(isLoadingInitial: true, lastError: null);

    try {
      final firstPage = await _fetchPage(1);
      if (!mounted) return;

      final seen = firstPage.map((item) => item.id).toSet();

      state = state.copyWith(
        items: firstPage,
        currentPage: firstPage.isEmpty ? 0 : 1,
        hasMore: firstPage.length >= _pageSize,
        isLoadingInitial: false,
        seenIds: seen,
        lastError: null,
      );
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(isLoadingInitial: false, lastError: error);
    }
  }

  Future<List<FaioContent>> _fetchPage(int page) async {
    final items = await _repository.fetchFeedPage(page: page, limit: _pageSize);
    return items
        .where((item) => item.type == ContentType.illustration)
        .toList();
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
      final newItems = await _fetchPage(nextPage);
      if (!mounted) return;

      final latest = state;
      final unique = newItems
          .where((item) => !latest.seenIds.contains(item.id))
          .toList();

      final updatedItems = [...latest.items, ...unique];
      final updatedSeen = {...latest.seenIds, ...unique.map((item) => item.id)};

      state = latest.copyWith(
        items: updatedItems,
        currentPage: nextPage,
        hasMore: newItems.length >= _pageSize,
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
        // Prevent potential infinite loop if no new illustrations are found.
        if (attempts >= 3) {
          break;
        }
      } else {
        attempts = 0;
      }
    }
  }
}

final feedControllerProvider =
    StateNotifierProvider.autoDispose<FeedController, FeedState>((ref) {
      final repository = ref.watch(contentRepositoryProvider);
      return FeedController(repository: repository, ref: ref);
    });

final feedSelectionProvider =
    StateNotifierProvider.autoDispose<
      FeedSelectionController,
      FeedSelectionState
    >((ref) {
      return FeedSelectionController();
    });

class FeedSelectionState {
  const FeedSelectionState({this.selectedIndex, this.pendingScrollIndex});

  final int? selectedIndex;
  final int? pendingScrollIndex;

  FeedSelectionState copyWith({
    int? selectedIndex,
    bool clearPendingScroll = false,
    int? pendingScrollIndex,
    bool clearSelection = false,
  }) {
    return FeedSelectionState(
      selectedIndex: clearSelection
          ? null
          : selectedIndex ?? this.selectedIndex,
      pendingScrollIndex: clearPendingScroll
          ? null
          : pendingScrollIndex ?? this.pendingScrollIndex,
    );
  }
}

class FeedSelectionController extends StateNotifier<FeedSelectionState> {
  FeedSelectionController() : super(const FeedSelectionState());

  void select(int index) {
    state = state.copyWith(selectedIndex: index);
  }

  void requestScrollTo(int index) {
    state = state.copyWith(pendingScrollIndex: index);
  }

  void clearScrollRequest() {
    state = state.copyWith(clearPendingScroll: true);
  }

  void clearSelection() {
    state = state.copyWith(clearSelection: true);
  }
}
