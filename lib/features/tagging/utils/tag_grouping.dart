import 'package:flutter/material.dart';

import 'package:faio/domain/models/content_tag.dart';
import 'package:faio/domain/utils/tag_normalizer.dart';
import 'package:faio/domain/utils/tag_sorter.dart';

enum TagCategoryType {
  contentRating,
  theme,
  species,
  character,
  trait,
  general,
}

class TagCategoryGroup {
  const TagCategoryGroup({
    required this.category,
    required this.title,
    required this.icon,
    required this.tags,
  });

  final TagCategoryType category;
  final String title;
  final IconData icon;
  final List<ContentTag> tags;
}

List<TagCategoryGroup> buildTagCategoryGroups(Iterable<ContentTag> tags) {
  if (tags.isEmpty) {
    return const [];
  }
  final buckets = {
    for (final category in TagCategoryType.values) category: <ContentTag>[],
  };
  final seen = <String>{};
  for (final tag in tags) {
    if (!seen.add(tag.canonicalName)) {
      continue;
    }
    final category = _categorize(tag);
    buckets[category]!.add(tag);
  }

  final groups = <TagCategoryGroup>[];
  for (final category in TagCategoryType.values) {
    final bucket = buckets[category]!;
    if (bucket.isEmpty) {
      continue;
    }
    final processed = _postProcess(category, bucket);
    if (processed.isEmpty) {
      continue;
    }
    groups.add(
      TagCategoryGroup(
        category: category,
        title: _titleFor(category),
        icon: _iconFor(category),
        tags: ContentTagSorter.sort(processed),
      ),
    );
  }
  return groups;
}

TagCategoryType _categorize(ContentTag tag) {
  final canonical = tag.canonicalName.toLowerCase();
  final display = tag.displayName.toLowerCase();
  if (_matchesAny(canonical, display, _ratingKeywords)) {
    return TagCategoryType.contentRating;
  }
  if (_matchesAny(canonical, display, _themeKeywords)) {
    return TagCategoryType.theme;
  }
  if (_matchesAny(canonical, display, _speciesKeywords)) {
    return TagCategoryType.species;
  }
  if (_matchesAny(canonical, display, _characterKeywords)) {
    return TagCategoryType.character;
  }
  if (_matchesAny(canonical, display, _traitKeywords)) {
    return TagCategoryType.trait;
  }
  return TagCategoryType.general;
}

bool _matchesAny(String canonical, String display, List<String> keywords) {
  for (final keyword in keywords) {
    if (canonical.contains(keyword) || display.contains(keyword)) {
      return true;
    }
  }
  return false;
}

List<ContentTag> _postProcess(TagCategoryType category, List<ContentTag> tags) {
  if (category == TagCategoryType.species) {
    return _deduplicateByBase(tags);
  }
  return tags;
}

List<ContentTag> _deduplicateByBase(List<ContentTag> tags) {
  final result = <String, ContentTag>{};
  for (final tag in tags) {
    final base = _genderNeutralBase(tag.canonicalName);
    final existing = result[base];
    if (existing == null) {
      result[base] = tag;
      continue;
    }
    if (_specificityScore(tag) > _specificityScore(existing)) {
      result[base] = tag;
    }
  }
  return result.values.toList();
}

String _genderNeutralBase(String canonical) {
  var base = canonical;
  for (final marker in _genderMarkers) {
    base = base.replaceAll(marker, '');
  }
  base = base.replaceAll('__', '_');
  base = base.replaceAll(RegExp(r'^_+'), '');
  base = base.replaceAll(RegExp(r'_+$'), '');
  final normalized = TagNormalizer.normalize(base);
  return normalized.isEmpty ? canonical : normalized;
}

int _specificityScore(ContentTag tag) {
  final source = tag.displayName.trim().isEmpty
      ? tag.canonicalName
      : tag.displayName;
  final lettersOnly = source.replaceAll(RegExp(r'[\s_]+'), '');
  return lettersOnly.length;
}

String _titleFor(TagCategoryType category) {
  switch (category) {
    case TagCategoryType.contentRating:
      return '分级与警告';
    case TagCategoryType.theme:
      return '题材与风格';
    case TagCategoryType.species:
      return '种族与特征';
    case TagCategoryType.character:
      return '角色与阵营';
    case TagCategoryType.trait:
      return '角色特质';
    case TagCategoryType.general:
      return '其他标签';
  }
}

IconData _iconFor(TagCategoryType category) {
  switch (category) {
    case TagCategoryType.contentRating:
      return Icons.shield_moon_outlined;
    case TagCategoryType.theme:
      return Icons.style_outlined;
    case TagCategoryType.species:
      return Icons.pets_outlined;
    case TagCategoryType.character:
      return Icons.groups_2_outlined;
    case TagCategoryType.trait:
      return Icons.person_pin_circle_outlined;
    case TagCategoryType.general:
      return Icons.sell_outlined;
  }
}

const _ratingKeywords = [
  'r18',
  'r-18',
  'r_18',
  'r18g',
  'r-18g',
  'adult',
  'explicit',
  'mature',
  'nsfw',
  'gore',
  '血腥',
  '18禁',
];

const _themeKeywords = [
  'adventure',
  'romance',
  'fantasy',
  'sci_fi',
  'science_fiction',
  'horror',
  'drama',
  'slice_of_life',
  'mystery',
  '都市',
  '奇幻',
  '科幻',
  '冒险',
  '恋爱',
  '爱情',
  '悬疑',
  '恐怖',
  '日常',
  '治愈',
  '动作',
];

const _speciesKeywords = [
  'fur',
  'beast',
  'beastman',
  'anthro',
  'dragon',
  'wolf',
  'fox',
  'cat',
  'dog',
  'lion',
  'tiger',
  'bear',
  'horse',
  'deer',
  'otter',
  'shark',
  'bird',
  'avian',
  'reptile',
  'lizard',
  '牛',
  '羊',
  '龙',
  '狐',
  '狼',
  '虎',
  '豹',
  '狮',
  '猫',
  '犬',
  '狗',
  '熊',
  '马',
  '兔',
  '鸟',
  '兽',
  '兽人',
];

const _characterKeywords = [
  'character',
  'oc',
  '主角',
  '角色',
  '人物',
  '配角',
  '反派',
  '英雄',
];

const _traitKeywords = [
  'female',
  'male',
  'futa',
  'androgynous',
  '少年',
  '少女',
  '青年',
  '成年',
  '女性',
  '男性',
  '雌性',
  '雄性',
  '女孩',
  '男孩',
];

const _genderMarkers = [
  'female',
  'male',
  'fem',
  'masc',
  'girl',
  'boy',
  'futa',
  'woman',
  'man',
  '女性',
  '男性',
  '雌性',
  '雄性',
  '少女',
  '少年',
];
