import 'package:equatable/equatable.dart';

import 'content_tag.dart';

/// Supported content types across integrated services.
enum ContentType { illustration, comic, novel, audio }

/// Represents a unified piece of content regardless of origin service.
class FaioContent extends Equatable {
  const FaioContent({
    required this.id,
    required this.source,
    required this.title,
    required this.summary,
    required this.type,
    required this.previewUrl,
    this.originalUrl,
    this.sampleUrl,
    this.previewAspectRatio,
    required this.publishedAt,
    this.updatedAt,
    required this.rating,
    this.authorName,
    this.tags = const <ContentTag>[],
    this.favoriteCount = 0,
    this.sourceLinks = const [],
    this.imagePages = const <ContentImageVariant>[],
  });

  /// Unique identifier with source prefix (e.g. `pixiv:123456`).
  final String id;

  /// Service identifier (e.g. `pixiv`, `e621`, `furaffinity`).
  final String source;

  final String title;
  final String summary;
  final ContentType type;
  final Uri? previewUrl;
  final Uri? originalUrl;
  final Uri? sampleUrl;
  final double? previewAspectRatio;
  final DateTime publishedAt;
  final DateTime? updatedAt;

  /// Normalised content rating (General/Mature/Adult).
  final String rating;

  final String? authorName;
  final List<ContentTag> tags;
  final int favoriteCount;
  final List<Uri> sourceLinks;
  final List<ContentImageVariant> imagePages;

  @override
  List<Object?> get props => [
    id,
    source,
    title,
    summary,
    type,
    previewUrl,
    originalUrl,
    sampleUrl,
    previewAspectRatio,
    publishedAt,
    updatedAt,
    rating,
    authorName,
    tags,
    favoriteCount,
    sourceLinks,
    imagePages,
  ];

  FaioContent copyWith({
    String? title,
    String? summary,
    ContentType? type,
    Uri? previewUrl,
    Uri? originalUrl,
    Uri? sampleUrl,
    double? previewAspectRatio,
    DateTime? publishedAt,
    DateTime? updatedAt,
    String? rating,
    String? authorName,
    List<ContentTag>? tags,
    int? favoriteCount,
    List<Uri>? sourceLinks,
    List<ContentImageVariant>? imagePages,
  }) {
    return FaioContent(
      id: id,
      source: source,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      type: type ?? this.type,
      previewUrl: previewUrl ?? this.previewUrl,
      originalUrl: originalUrl ?? this.originalUrl,
      sampleUrl: sampleUrl ?? this.sampleUrl,
      previewAspectRatio: previewAspectRatio ?? this.previewAspectRatio,
      publishedAt: publishedAt ?? this.publishedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rating: rating ?? this.rating,
      authorName: authorName ?? this.authorName,
      tags: tags ?? this.tags,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      sourceLinks: sourceLinks ?? this.sourceLinks,
      imagePages: imagePages ?? this.imagePages,
    );
  }
}

class ContentImageVariant {
  const ContentImageVariant({
    this.previewUrl,
    this.sampleUrl,
    this.originalUrl,
  });

  final Uri? previewUrl;
  final Uri? sampleUrl;
  final Uri? originalUrl;

  bool get hasAny =>
      previewUrl != null || sampleUrl != null || originalUrl != null;
}
