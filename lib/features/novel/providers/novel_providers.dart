import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/pixiv/pixiv_providers.dart';
import '../../../domain/models/novel_detail.dart';
import '../../../domain/models/novel_reader.dart';
import '../data/novel_reading_storage.dart';

final sharedPreferencesFutureProvider =
    Provider<Future<SharedPreferences>>((ref) {
  final future = SharedPreferences.getInstance();
  return future;
}, name: 'sharedPreferencesFutureProvider');

final novelReadingStorageProvider = Provider<NovelReadingStorage>((ref) {
  final prefsFuture = ref.watch(sharedPreferencesFutureProvider);
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
