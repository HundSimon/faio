import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/mock/mock_content_repository.dart';
import '../../../domain/models/content_item.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider =
    FutureProvider.autoDispose<List<FaioContent>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) {
    return const [];
  }

  final repository = ref.watch(mockContentRepositoryProvider);
  return repository.search(query: query.trim());
});
