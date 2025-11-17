import 'package:lpinyin/lpinyin.dart';

import '../models/content_tag.dart';
import 'tag_normalizer.dart';

/// Provides alphabetical sorting for [ContentTag] collections.
///
/// ASCII tags are sorted using their normalized lowercase value, while
/// Chinese tags are ordered by their pinyin initials to provide predictable
/// grouping alongside non-Chinese labels.
class ContentTagSorter {
  const ContentTagSorter._();

  static final RegExp _chinesePattern = RegExp(r'[\u4e00-\u9fff]');

  static List<ContentTag> sort(Iterable<ContentTag> tags) {
    final sorted = List<ContentTag>.of(tags);
    sorted.sort((a, b) => _sortKey(a).compareTo(_sortKey(b)));
    return sorted;
  }

  static String _sortKey(ContentTag tag) {
    final display = tag.displayName.trim().isEmpty
        ? tag.canonicalName.trim()
        : tag.displayName.trim();
    if (display.isEmpty) {
      return tag.canonicalName;
    }

    final normalized = TagNormalizer.normalize(display);
    if (_chinesePattern.hasMatch(display)) {
      final short = PinyinHelper.getShortPinyin(display).toLowerCase();
      final full = PinyinHelper.getPinyinE(
        display,
        separator: '',
        defPinyin: display,
        format: PinyinFormat.WITHOUT_TONE,
      ).toLowerCase();
      final fallback = normalized.isEmpty ? display.toLowerCase() : normalized;
      final shortKey = short.isEmpty ? fallback : short;
      final fullKey = full.isEmpty ? fallback : full;
      return '$shortKey|$fullKey|$fallback|${tag.canonicalName}';
    }

    if (normalized.isNotEmpty) {
      return '$normalized|${tag.canonicalName}';
    }

    return '${display.toLowerCase()}|${tag.canonicalName}';
  }
}
