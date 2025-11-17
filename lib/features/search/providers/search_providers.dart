import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/content_repository_impl.dart';
import '../../../domain/models/content_item.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider.autoDispose<List<FaioContent>>((
  ref,
) async {
  final rawQuery = ref.watch(searchQueryProvider);
  final trimmedQuery = rawQuery.trim();
  final tokens = trimmedQuery.isEmpty
      ? const <String>[]
      : trimmedQuery.split(RegExp(r'\s+'));

  final extractedTags = <String>[];
  final keywords = <String>[];
  for (final token in tokens) {
    final normalized = token.trim();
    if (normalized.isEmpty) {
      continue;
    }
    final lower = normalized.toLowerCase();
    if (normalized.startsWith('#')) {
      final tag = normalized.replaceFirst(RegExp(r'^#+'), '').trim();
      if (tag.isNotEmpty) {
        extractedTags.add(tag);
      }
      continue;
    }
    if (lower.startsWith('tag:') || lower.startsWith('tag=')) {
      final tag = normalized.substring(4).trim();
      if (tag.isNotEmpty) {
        extractedTags.add(tag);
      }
      continue;
    }
    keywords.add(normalized);
  }

  final normalizedQuery = keywords.join(' ').trim();
  if (normalizedQuery.isEmpty && extractedTags.isEmpty) {
    return const [];
  }

  final repository = ref.watch(contentRepositoryProvider);
  final effectiveQuery = normalizedQuery.isEmpty
      ? trimmedQuery
      : normalizedQuery;
  return repository.search(query: effectiveQuery, tags: extractedTags);
});
