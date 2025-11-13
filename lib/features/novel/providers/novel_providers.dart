import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/pixiv/pixiv_providers.dart';
import '../../../domain/models/novel_detail.dart';
import '../../../domain/models/novel_reader.dart';
import '../../../core/providers/shared_preferences_provider.dart';
import '../data/novel_reading_storage.dart';

class NovelFeedSelectionState {
  const NovelFeedSelectionState({this.selectedIndex, this.pendingScrollIndex});

  final int? selectedIndex;
  final int? pendingScrollIndex;

  NovelFeedSelectionState copyWith({
    int? selectedIndex,
    int? pendingScrollIndex,
    bool clearSelection = false,
    bool clearPendingScroll = false,
  }) {
    return NovelFeedSelectionState(
      selectedIndex: clearSelection
          ? null
          : selectedIndex ?? this.selectedIndex,
      pendingScrollIndex: clearPendingScroll
          ? null
          : pendingScrollIndex ?? this.pendingScrollIndex,
    );
  }
}

class NovelFeedSelectionController
    extends StateNotifier<NovelFeedSelectionState> {
  NovelFeedSelectionController()
      : super(const NovelFeedSelectionState());

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

final novelFeedSelectionProvider = StateNotifierProvider.autoDispose<
    NovelFeedSelectionController,
    NovelFeedSelectionState>((ref) {
  return NovelFeedSelectionController();
}, name: 'novelFeedSelectionProvider');

final novelReadingStorageProvider = Provider<NovelReadingStorage>((ref) {
  final prefsFuture = ref.watch(sharedPreferencesProvider);
  return NovelReadingStorage(prefsFuture: prefsFuture);
}, name: 'novelReadingStorageProvider');

final novelDetailProvider =
    AutoDisposeFutureProvider.family<NovelDetail, int>((ref, novelId) async {
  final repository = ref.watch(pixivRepositoryProvider);
  final detail = await repository.fetchNovelDetail(novelId);
  if (detail == null) {
    throw Exception('未找到小说 $novelId');
  }
  return detail;
}, name: 'novelDetailProvider');

final novelSeriesDetailProvider =
    AutoDisposeFutureProvider.family<NovelSeriesDetail?, int>(
      (ref, seriesId) async {
        final repository = ref.watch(pixivRepositoryProvider);
        return repository.fetchNovelSeries(seriesId);
      },
      name: 'novelSeriesDetailProvider',
    );

final novelReadingProgressProvider =
    AutoDisposeFutureProvider.family<NovelReadingProgress?, int>(
      (ref, novelId) async {
        final storage = ref.watch(novelReadingStorageProvider);
        return storage.loadProgress(novelId);
      },
      name: 'novelReadingProgressProvider',
    );

final novelReaderSettingsProvider = StateNotifierProvider<
    NovelReaderSettingsController,
    AsyncValue<NovelReaderSettings>>((ref) {
  final storage = ref.watch(novelReadingStorageProvider);
  return NovelReaderSettingsController(storage: storage);
}, name: 'novelReaderSettingsProvider');

class NovelReaderSettingsController
    extends StateNotifier<AsyncValue<NovelReaderSettings>> {
  NovelReaderSettingsController({required NovelReadingStorage storage})
      : _storage = storage,
        super(const AsyncValue.loading()) {
    _load();
  }

  final NovelReadingStorage _storage;

  Future<void> _load() async {
    try {
      final settings = await _storage.loadSettings();
      if (!mounted) return;
      state = AsyncValue.data(settings);
    } catch (error, stackTrace) {
      if (!mounted) return;
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> update(NovelReaderSettings settings) async {
    state = AsyncValue.data(settings);
    await _storage.saveSettings(settings);
  }

  Future<void> updatePartial(
    NovelReaderSettings Function(NovelReaderSettings current) transform,
  ) async {
    final current = state.maybeWhen(
      data: (value) => value,
      orElse: () => const NovelReaderSettings(),
    );
    final next = transform(current);
    await update(next);
  }
}
