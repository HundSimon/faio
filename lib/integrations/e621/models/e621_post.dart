import 'package:equatable/equatable.dart';

enum E621Rating {
  safe,
  questionable,
  explicit;

  factory E621Rating.fromString(String value) {
    switch (value) {
      case 's':
        return E621Rating.safe;
      case 'q':
        return E621Rating.questionable;
      case 'e':
        return E621Rating.explicit;
      default:
        return E621Rating.safe;
    }
  }

  String toNormalizedRating() {
    switch (this) {
      case E621Rating.safe:
        return 'General';
      case E621Rating.questionable:
        return 'Mature';
      case E621Rating.explicit:
        return 'Adult';
    }
  }
}

enum E621TagCategory {
  general,
  artist,
  copyright,
  character,
  species,
  invalid,
  meta,
  lore,
  contributor;

  static E621TagCategory? fromKey(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    switch (value) {
      case 'general':
        return E621TagCategory.general;
      case 'artist':
        return E621TagCategory.artist;
      case 'copyright':
        return E621TagCategory.copyright;
      case 'character':
        return E621TagCategory.character;
      case 'species':
        return E621TagCategory.species;
      case 'invalid':
        return E621TagCategory.invalid;
      case 'meta':
        return E621TagCategory.meta;
      case 'lore':
        return E621TagCategory.lore;
      case 'contributor':
        return E621TagCategory.contributor;
      default:
        return null;
    }
  }
}

class E621FileInfo extends Equatable {
  const E621FileInfo({
    required this.url,
    required this.width,
    required this.height,
  });

  final Uri? url;
  final int width;
  final int height;

  factory E621FileInfo.fromJson(Map<String, dynamic> json) {
    final urlString = json['url'] as String?;
    return E621FileInfo(
      url: urlString != null ? Uri.tryParse(urlString) : null,
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [url, width, height];
}

class E621PreviewInfo extends Equatable {
  const E621PreviewInfo({
    required this.url,
    required this.width,
    required this.height,
  });

  final Uri? url;
  final int width;
  final int height;

  factory E621PreviewInfo.fromJson(Map<String, dynamic> json) {
    final urlString = json['url'] as String?;
    return E621PreviewInfo(
      url: urlString != null ? Uri.tryParse(urlString) : null,
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [url, width, height];
}

class E621Post extends Equatable {
  const E621Post({
    required this.id,
    required this.createdAt,
    this.updatedAt,
    required this.rating,
    required this.tags,
    required this.tagCategories,
    required this.description,
    required this.file,
    required this.preview,
    required this.sample,
    required this.sources,
    this.favCount = 0,
  });

  final int id;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final E621Rating rating;
  final List<String> tags;
  final Map<String, E621TagCategory> tagCategories;
  final String description;
  final E621FileInfo file;
  final E621PreviewInfo preview;
  final E621FileInfo sample;
  final List<Uri> sources;
  final int favCount;

  factory E621Post.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String? raw) {
      if (raw == null || raw.isEmpty) {
        return null;
      }
      return DateTime.tryParse(raw);
    }

    final createdAt =
        parseDate(json['created_at'] as String?) ??
        DateTime.fromMillisecondsSinceEpoch(0);

    final parsedTags = _parseTags(json['tags']);
    return E621Post(
      id: json['id'] as int,
      createdAt: createdAt,
      updatedAt: parseDate(json['updated_at'] as String?),
      rating: E621Rating.fromString(json['rating'] as String? ?? 's'),
      tags: parsedTags.all,
      tagCategories: parsedTags.categoryMap,
      description: json['description'] as String? ?? '',
      file: E621FileInfo.fromJson(
        json['file'] as Map<String, dynamic>? ?? const {},
      ),
      preview: E621PreviewInfo.fromJson(
        json['preview'] as Map<String, dynamic>? ?? const {},
      ),
      sample: E621FileInfo.fromJson(
        json['sample'] as Map<String, dynamic>? ?? const {},
      ),
      sources: _parseSources(json['sources']),
      favCount: json['fav_count'] as int? ?? 0,
    );
  }

  static _ParsedTags _parseTags(dynamic value) {
    if (value is Map<String, dynamic>) {
      final all = <String>[];
      final categoryMap = <String, E621TagCategory>{};
      for (final entry in value.entries) {
        final category = E621TagCategory.fromKey(entry.key);
        final rawList = entry.value;
        if (rawList is List) {
          for (final raw in rawList) {
            if (raw is! String) {
              continue;
            }
            all.add(raw);
            if (category != null) {
              categoryMap[raw] = category;
            }
          }
        }
      }
      return _ParsedTags(all: all, categoryMap: categoryMap);
    }
    if (value is List) {
      return _ParsedTags(
        all: value.whereType<String>().toList(growable: false),
        categoryMap: const <String, E621TagCategory>{},
      );
    }
    return const _ParsedTags(
      all: <String>[],
      categoryMap: <String, E621TagCategory>{},
    );
  }

  static List<Uri> _parseSources(dynamic value) {
    if (value is List) {
      return value
          .whereType<String>()
          .map((e) => Uri.tryParse(e))
          .whereType<Uri>()
          .toList(growable: false);
    }
    return const [];
  }

  @override
  List<Object?> get props => [
    id,
    createdAt,
    updatedAt,
    rating,
    tags,
    tagCategories.entries
        .map((entry) => '${entry.key}:${entry.value.name}')
        .toList(growable: false),
    description,
    file,
    sample,
    preview,
    sources,
    favCount,
  ];
}

class _ParsedTags {
  const _ParsedTags({required this.all, required this.categoryMap});

  final List<String> all;
  final Map<String, E621TagCategory> categoryMap;
}
