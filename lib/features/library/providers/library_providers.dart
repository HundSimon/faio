import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/shared_preferences_provider.dart';
import '../../../domain/models/content_item.dart';
import '../data/library_storage.dart';
import '../domain/library_entries.dart';

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

  @override
  Future<List<LibraryFavoriteEntry>> build() async {
    return _storage.loadFavorites();
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
