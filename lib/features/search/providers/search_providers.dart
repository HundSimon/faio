import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/content_repository_impl.dart';
import '../../../domain/models/content_item.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider.autoDispose<List<FaioContent>>((
  ref,
) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) {
    return const [];
  }

  final repository = ref.watch(contentRepositoryProvider);
  return repository.search(query: query.trim());
});
