import 'package:equatable/equatable.dart';

/// Supported content types across integrated services.
enum ContentType {
  illustration,
  comic,
  novel,
  audio,
}

/// Represents a unified piece of content regardless of origin service.
class FaioContent extends Equatable {
  const FaioContent({
    required this.id,
    required this.source,
    required this.title,
    required this.summary,
    required this.type,
    required this.previewUrl,
    required this.publishedAt,
    required this.rating,
    this.authorName,
    this.tags = const [],
  });

  /// Unique identifier with source prefix (e.g. `pixiv:123456`).
  final String id;

  /// Service identifier (e.g. `pixiv`, `e621`, `furaffinity`).
  final String source;

  final String title;
  final String summary;
  final ContentType type;
  final Uri? previewUrl;
  final DateTime publishedAt;

  /// Normalised content rating (General/Mature/Adult).
  final String rating;

  final String? authorName;
  final List<String> tags;

  @override
  List<Object?> get props => [
        id,
        source,
        title,
        summary,
        type,
        previewUrl,
        publishedAt,
        rating,
        authorName,
        tags,
      ];

  FaioContent copyWith({
    String? title,
    String? summary,
    ContentType? type,
    Uri? previewUrl,
    DateTime? publishedAt,
    String? rating,
    String? authorName,
    List<String>? tags,
  }) {
    return FaioContent(
      id: id,
      source: source,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      type: type ?? this.type,
      previewUrl: previewUrl ?? this.previewUrl,
      publishedAt: publishedAt ?? this.publishedAt,
      rating: rating ?? this.rating,
      authorName: authorName ?? this.authorName,
      tags: tags ?? this.tags,
    );
  }
}
