import '../models/content_tag.dart';

/// Helper for constructing unique [ContentTag] collections from raw labels.
class ContentTagBuilder {
  final Map<String, ContentTag> _tags = {};

  void addLabel(
    String label, {
    String? display,
    Iterable<String> aliases = const [],
    ContentTagCategory? category,
  }) {
    final tag = ContentTag.fromLabels(
      primary: label,
      display: display,
      alternatives: aliases,
      category: category,
    );
    if (tag.canonicalName.isEmpty) {
      return;
    }
    addTag(tag);
  }

  void addTag(ContentTag tag) {
    if (tag.canonicalName.isEmpty) {
      return;
    }
    final existing = _tags[tag.canonicalName];
    if (existing != null) {
      _tags[tag.canonicalName] = existing.merge(tag);
    } else {
      _tags[tag.canonicalName] = tag;
    }
  }

  List<ContentTag> build() => _tags.values.toList();
}
