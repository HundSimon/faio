import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sample/sample_feed.dart';
import '../../../domain/models/content_item.dart';

/// Temporary provider delivering mock content until real integrations land.
final mockFeedProvider = Provider<List<FaioContent>>((ref) {
  return buildSampleFeedItems();
});
