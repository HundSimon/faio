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

    return E621Post(
      id: json['id'] as int,
      createdAt: createdAt,
      updatedAt: parseDate(json['updated_at'] as String?),
      rating: E621Rating.fromString(json['rating'] as String? ?? 's'),
      tags: _parseTags(json['tags']),
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

  static List<String> _parseTags(dynamic value) {
    if (value is Map<String, dynamic>) {
      final all = <String>[];
      for (final entry in value.entries) {
        if (entry.value is List) {
          all.addAll(List<String>.from(entry.value as List));
        }
      }
      return all;
    }
    if (value is List) {
      return List<String>.from(value);
    }
    return const [];
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
    description,
    file,
    sample,
    preview,
    sources,
    favCount,
  ];
}
