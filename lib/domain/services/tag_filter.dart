import '../models/content_item.dart';
import '../models/content_tag.dart';
import '../models/tag_preferences.dart';

class TagFilter {
  const TagFilter({required this.preferences});

  final TagPreferences preferences;

  bool get isInactive => preferences.isEmpty;

  bool allows(FaioContent content) {
    if (isInactive) {
      return true;
    }
    for (final tag in content.tags) {
      if (preferences.isBlockedTag(tag)) {
        return false;
      }
    }
    return true;
  }

  ContentTagStatus statusForTag(ContentTag tag) =>
      preferences.statusForTag(tag);

  ContentTagStatus statusForName(String name) =>
      preferences.statusForName(name);

  List<ContentTag> blockedMatches(FaioContent content) {
    if (preferences.isEmpty) {
      return const [];
    }
    return content.tags.where((tag) => preferences.isBlockedTag(tag)).toList();
  }
}
