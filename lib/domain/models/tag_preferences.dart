import 'package:equatable/equatable.dart';

import '../utils/tag_normalizer.dart';
import 'content_tag.dart';

enum ContentTagStatus { neutral, liked, blocked }

class TagPreferences extends Equatable {
  const TagPreferences({
    this.liked = const <ContentTag>[],
    this.blocked = const <ContentTag>[],
  });

  final List<ContentTag> liked;
  final List<ContentTag> blocked;

  bool get isEmpty => liked.isEmpty && blocked.isEmpty;

  Map<String, ContentTag> get _likedMap => {
    for (final tag in liked) tag.canonicalName: tag,
  };

  Map<String, ContentTag> get _blockedMap => {
    for (final tag in blocked) tag.canonicalName: tag,
  };

  ContentTagStatus statusForTag(ContentTag tag) =>
      statusForCanonical(tag.canonicalName);

  ContentTagStatus statusForName(String raw) {
    final canonical = TagNormalizer.normalize(raw);
    return statusForCanonical(canonical);
  }

  ContentTagStatus statusForCanonical(String canonical) {
    if (canonical.isEmpty) {
      return ContentTagStatus.neutral;
    }
    if (_blockedMap.containsKey(canonical)) {
      return ContentTagStatus.blocked;
    }
    if (_likedMap.containsKey(canonical)) {
      return ContentTagStatus.liked;
    }
    return ContentTagStatus.neutral;
  }

  bool isBlockedTag(ContentTag tag) =>
      _blockedMap.containsKey(tag.canonicalName);

  bool isBlockedName(String raw) =>
      _blockedMap.containsKey(TagNormalizer.normalize(raw));

  TagPreferences copyWith({
    List<ContentTag>? liked,
    List<ContentTag>? blocked,
  }) {
    return TagPreferences(
      liked: liked ?? this.liked,
      blocked: blocked ?? this.blocked,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'liked': liked.map((tag) => tag.toJson()).toList(),
      'blocked': blocked.map((tag) => tag.toJson()).toList(),
    };
  }

  factory TagPreferences.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const TagPreferences();
    }
    List<ContentTag> parseList(dynamic input) {
      if (input is List) {
        final map = <String, ContentTag>{};
        for (final entry in input.whereType<Map<String, dynamic>>()) {
          final tag = ContentTag.fromJson(entry);
          if (tag.canonicalName.isEmpty) {
            continue;
          }
          final existing = map[tag.canonicalName];
          map[tag.canonicalName] = existing != null ? existing.merge(tag) : tag;
        }
        return map.values.toList();
      }
      return const <ContentTag>[];
    }

    return TagPreferences(
      liked: parseList(json['liked']),
      blocked: parseList(json['blocked']),
    );
  }

  @override
  List<Object?> get props => [liked, blocked];
}
