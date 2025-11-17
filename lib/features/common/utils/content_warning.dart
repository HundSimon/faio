import 'package:faio/domain/models/content_tag.dart';

enum ContentWarningLevel { none, adult, extreme }

class ContentWarning {
  const ContentWarning({
    required this.level,
    required this.label,
    required this.message,
  });

  final ContentWarningLevel level;
  final String label;
  final String message;

  bool get requiresConfirmation => level != ContentWarningLevel.none;
}

ContentWarning? evaluateContentWarning({
  required String rating,
  Iterable<ContentTag> tags = const [],
}) {
  final normalizedValues = <String>[];
  void add(String? raw) {
    if (raw == null) {
      return;
    }
    final value = raw.trim().toLowerCase();
    if (value.isNotEmpty) {
      normalizedValues.add(value);
    }
  }

  add(rating);
  for (final tag in tags) {
    add(tag.canonicalName);
    add(tag.displayName);
  }

  final hasExtreme = normalizedValues.any(
    (value) => _extremeKeywords.any(value.contains),
  );
  if (hasExtreme) {
    return const ContentWarning(
      level: ContentWarningLevel.extreme,
      label: 'R-18G',
      message: '该作品包含重口或血腥内容，确认已满 18 岁方可查看。',
    );
  }

  final hasAdult = normalizedValues.any(
    (value) => _adultKeywords.any(value.contains),
  );
  if (hasAdult) {
    return const ContentWarning(
      level: ContentWarningLevel.adult,
      label: 'R-18',
      message: '该作品包含成人向内容，请确认您已年满 18 岁。',
    );
  }

  return null;
}

const _adultKeywords = [
  'r18',
  'r-18',
  'r_18',
  'adult',
  'explicit',
  'mature',
  'nsfw',
  '限制级',
  '18禁',
  '成人',
];

const _extremeKeywords = [
  'r18g',
  'r-18g',
  'violence',
  'gore',
  '血腥',
  '猎奇',
  '重口',
  '猎奇向',
];
