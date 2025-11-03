import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/content_repository_impl.dart';
import '../../../domain/models/content_item.dart';

/// Stream of aggregated content for the home feed.
final feedStreamProvider = StreamProvider.autoDispose<List<FaioContent>>((ref) {
  final repository = ref.watch(contentRepositoryProvider);
  return repository.watchFeed();
});
