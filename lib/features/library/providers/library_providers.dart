import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:faio/data/library/library_storage.dart';
import 'package:faio/domain/models/library_entries.dart';

import '../../../core/providers/shared_preferences_provider.dart';
import '../../../data/pixiv/pixiv_providers.dart';
import '../../../domain/models/content_item.dart';
import '../../../domain/repositories/pixiv_repository.dart';

const _maxHistoryEntries = 200;

final libraryStorageProvider = Provider<LibraryStorage>((ref) {
  final prefsFuture = ref.watch(sharedPreferencesProvider);
  return LibraryStorage(prefsFuture: prefsFuture);
}, name: 'libraryStorageProvider');

final libraryFavoritesProvider =
    AsyncNotifierProvider<
      LibraryFavoritesController,
      List<LibraryFavoriteEntry>
    >(LibraryFavoritesController.new, name: 'libraryFavoritesProvider');

class LibraryFavoritesController
    extends AsyncNotifier<List<LibraryFavoriteEntry>> {
  LibraryStorage get _storage => ref.read(libraryStorageProvider);
  PixivRepository get _pixivRepository => ref.read(pixivRepositoryProvider);
  bool _hydrating = false;

  @override
  Future<List<LibraryFavoriteEntry>> build() async {
    final entries = await _storage.loadFavorites();
    _maybeHydrateSeriesFavorites();
    return entries;
  }

  Future<void> _maybeHydrateSeriesFavorites() async {
    if (_hydrating) return;
    _hydrating = true;
    try {
      final current = await _current();
      final next = await _hydrateSeriesFavorites(current);
      if (!identical(next, current)) {
        state = AsyncValue.data(next);
      }
    } catch (_) {
      // Ignore hydration errors; keep cached favorites.
    } finally {
      _hydrating = false;
    }
  }

  Future<List<LibraryFavoriteEntry>> _hydrateSeriesFavorites(
    List<LibraryFavoriteEntry> entries,
  ) async {
    final seriesIndexes = <int>[];
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final series = entry.series;
      if (series == null) continue;
      final needsCover = series.coverUrl == null;
      final needsCaption = series.caption == null || series.caption!.isEmpty;
      final needsSource = series.source == null || series.source!.isEmpty;
      final needsAuthor =
          series.authorName == null || series.authorName!.isEmpty;
      if (needsCover || needsCaption || needsSource || needsAuthor) {
        seriesIndexes.add(i);
      }
    }

    if (seriesIndexes.isEmpty) {
      return entries;
    }

    var changed = false;
    final next = [...entries];
    for (final index in seriesIndexes) {
      final entry = next[index];
      final series = entry.series;
      if (series == null) continue;
      try {
        final detail = await _pixivRepository.fetchNovelSeries(series.seriesId);
        if (detail == null) continue;

        final firstNovelId = detail.novels.isNotEmpty
            ? detail.novels.first.id
            : null;
        final needsSource = series.source == null || series.source!.isEmpty;
        final needsAuthor =
            series.authorName == null || series.authorName!.isEmpty;
        final needsAuthorId = series.authorId == null;
        final shouldFetchNovel =
            firstNovelId != null &&
            (needsSource || needsAuthor || needsAuthorId);

        final novelDetail = shouldFetchNovel
            ? await _pixivRepository.fetchNovelDetail(firstNovelId)
            : null;

        final nextSeries = LibrarySeriesFavorite(
          seriesId: series.seriesId,
          title: detail.title.trim().isNotEmpty
              ? detail.title.trim()
              : series.title,
          caption: detail.caption.trim().isNotEmpty
              ? detail.caption.trim()
              : series.caption,
          coverUrl: detail.novels.isNotEmpty
              ? detail.novels.first.coverUrl
              : series.coverUrl,
          source: (series.source != null && series.source!.trim().isNotEmpty)
              ? series.source!.trim()
              : novelDetail?.source,
          authorName:
              (series.authorName != null &&
                  series.authorName!.trim().isNotEmpty)
              ? series.authorName!.trim()
              : novelDetail?.authorName,
          authorId: series.authorId ?? novelDetail?.authorId,
        );
        next[index] = LibraryFavoriteEntry.series(
          series: nextSeries,
          savedAt: entry.savedAt,
        );
        changed = true;
      } catch (_) {
        continue;
      }
    }

    if (!changed) {
      return entries;
    }
    await _storage.saveFavorites(next);
    return next;
  }

  Future<List<LibraryFavoriteEntry>> _current() async {
    final value = state.valueOrNull;
    if (value != null) {
      return value;
    }
    final loaded = await _storage.loadFavorites();
    state = AsyncValue.data(loaded);
    return loaded;
  }

  Future<void> toggleContentFavorite(FaioContent content) async {
    final current = await _current();
    final index = current.indexWhere(
      (entry) => entry.isContent && entry.content!.id == content.id,
    );
    late final List<LibraryFavoriteEntry> next;
    if (index >= 0) {
      next = [...current]..removeAt(index);
    } else {
      final entry = LibraryFavoriteEntry.content(
        content: content,
        savedAt: DateTime.now(),
      );
      final filtered = current
          .where((existing) => existing.key != entry.key)
          .toList();
      next = [entry, ...filtered];
    }
    state = AsyncValue.data(next);
    await _storage.saveFavorites(next);
  }

  Future<void> toggleSeriesFavorite(LibrarySeriesFavorite series) async {
    final current = await _current();
    final index = current.indexWhere(
      (entry) => entry.isSeries && entry.series!.seriesId == series.seriesId,
    );
    late final List<LibraryFavoriteEntry> next;
    if (index >= 0) {
      next = [...current]..removeAt(index);
    } else {
      final entry = LibraryFavoriteEntry.series(
        series: series,
        savedAt: DateTime.now(),
      );
      final filtered = current
          .where((existing) => existing.key != entry.key)
          .toList();
      next = [entry, ...filtered];
    }
    state = AsyncValue.data(next);
    await _storage.saveFavorites(next);
  }

  bool isContentFavorite(String contentId) {
    final current = state.valueOrNull;
    if (current == null) {
      return false;
    }
    return current.any(
      (entry) => entry.isContent && entry.content!.id == contentId,
    );
  }

  bool isSeriesFavorite(int seriesId) {
    final current = state.valueOrNull;
    if (current == null) {
      return false;
    }
    return current.any(
      (entry) => entry.isSeries && entry.series!.seriesId == seriesId,
    );
  }

  Future<void> removeByKeys(Iterable<String> keys) async {
    final keySet = keys.toSet();
    if (keySet.isEmpty) {
      return;
    }
    final current = await _current();
    final next = current.where((entry) => !keySet.contains(entry.key)).toList();
    state = AsyncValue.data(next);
    await _storage.saveFavorites(next);
  }
}

final libraryHistoryProvider =
    AsyncNotifierProvider<LibraryHistoryController, List<LibraryHistoryEntry>>(
      LibraryHistoryController.new,
      name: 'libraryHistoryProvider',
    );

class LibraryHistoryController
    extends AsyncNotifier<List<LibraryHistoryEntry>> {
  LibraryStorage get _storage => ref.read(libraryStorageProvider);

  @override
  Future<List<LibraryHistoryEntry>> build() async {
    return _storage.loadHistory();
  }

  Future<List<LibraryHistoryEntry>> _current() async {
    final value = state.valueOrNull;
    if (value != null) {
      return value;
    }
    final loaded = await _storage.loadHistory();
    state = AsyncValue.data(loaded);
    return loaded;
  }

  Future<void> recordView(FaioContent content) async {
    final current = await _current();
    final filtered = current
        .where((entry) => entry.content.id != content.id)
        .toList();
    final entry = LibraryHistoryEntry(
      content: content,
      viewedAt: DateTime.now(),
    );
    final next = [entry, ...filtered];
    if (next.length > _maxHistoryEntries) {
      next.removeRange(_maxHistoryEntries, next.length);
    }
    state = AsyncValue.data(next);
    await _storage.saveHistory(next);
  }

  Future<void> clearHistory() async {
    state = const AsyncValue.data([]);
    await _storage.saveHistory(const []);
  }

  Future<void> removeByKeys(Iterable<String> keys) async {
    final keySet = keys.toSet();
    if (keySet.isEmpty) {
      return;
    }
    final current = await _current();
    final next = current.where((entry) => !keySet.contains(entry.key)).toList();
    state = AsyncValue.data(next);
    await _storage.saveHistory(next);
  }
}
