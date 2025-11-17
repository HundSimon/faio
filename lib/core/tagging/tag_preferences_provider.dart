import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/content_tag.dart';
import '../../domain/models/tag_preferences.dart';
import '../../domain/services/tag_filter.dart';
import '../providers/shared_preferences_provider.dart';
import 'tag_preferences_storage.dart';

final tagPreferencesStorageProvider = Provider<TagPreferencesStorage>((ref) {
  final prefsFuture = ref.watch(sharedPreferencesProvider);
  return TagPreferencesStorage(prefsFuture: prefsFuture);
}, name: 'tagPreferencesStorageProvider');

final tagPreferencesProvider =
    StateNotifierProvider<TagPreferencesController, AsyncValue<TagPreferences>>(
      (ref) {
        final storage = ref.watch(tagPreferencesStorageProvider);
        return TagPreferencesController(storage: storage);
      },
      name: 'tagPreferencesProvider',
    );

final tagFilterProvider = Provider<TagFilter>((ref) {
  final preferences =
      ref.watch(tagPreferencesProvider).valueOrNull ?? const TagPreferences();
  return TagFilter(preferences: preferences);
}, name: 'tagFilterProvider');

class TagPreferencesController
    extends StateNotifier<AsyncValue<TagPreferences>> {
  TagPreferencesController({required TagPreferencesStorage storage})
    : _storage = storage,
      super(const AsyncValue.loading()) {
    _load();
  }

  final TagPreferencesStorage _storage;

  TagPreferences get _current => state.valueOrNull ?? const TagPreferences();

  Future<void> _load() async {
    try {
      final preferences = await _storage.load();
      if (!mounted) return;
      state = AsyncValue.data(preferences);
    } catch (error, stackTrace) {
      if (!mounted) return;
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> likeTag(ContentTag tag) =>
      _setStatus(tag, ContentTagStatus.liked);

  Future<void> blockTag(ContentTag tag) =>
      _setStatus(tag, ContentTagStatus.blocked);

  Future<void> setStatusForName(String name, ContentTagStatus status) {
    final tag = ContentTag.fromLabels(primary: name);
    return _setStatus(tag, status);
  }

  Future<void> removeTag(ContentTag tag) =>
      _setStatus(tag, ContentTagStatus.neutral);

  Future<void> clearAll() async {
    state = const AsyncValue.data(TagPreferences());
    await _storage.clear();
  }

  Future<void> _setStatus(ContentTag tag, ContentTagStatus status) async {
    final canonical = tag.canonicalName;
    if (canonical.isEmpty) {
      return;
    }

    final current = _current;
    final liked = current.liked
        .where((entry) => entry.canonicalName != canonical)
        .toList();
    final blocked = current.blocked
        .where((entry) => entry.canonicalName != canonical)
        .toList();
    final mergedTag = _mergeWithExisting(tag, current);

    switch (status) {
      case ContentTagStatus.liked:
        liked.add(mergedTag);
        break;
      case ContentTagStatus.blocked:
        blocked.add(mergedTag);
        break;
      case ContentTagStatus.neutral:
        break;
    }

    final next = TagPreferences(liked: liked, blocked: blocked);
    state = AsyncValue.data(next);
    await _storage.save(next);
  }

  ContentTag _mergeWithExisting(ContentTag tag, TagPreferences current) {
    final canonical = tag.canonicalName;
    ContentTag? existing;
    for (final entry in current.liked) {
      if (entry.canonicalName == canonical) {
        existing = entry;
        break;
      }
    }
    if (existing == null) {
      for (final entry in current.blocked) {
        if (entry.canonicalName == canonical) {
          existing = entry;
          break;
        }
      }
    }
    if (existing != null) {
      return existing.merge(tag);
    }
    return tag;
  }
}
