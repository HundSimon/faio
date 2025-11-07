import 'package:equatable/equatable.dart';

class NovelDetail extends Equatable {
  const NovelDetail({
    required this.novelId,
    required this.source,
    required this.title,
    required this.description,
    required this.body,
    this.authorName,
    this.authorId,
    this.tags = const [],
    this.series,
    this.coverUrl,
    this.length,
    this.createdAt,
    this.updatedAt,
    this.images = const {},
    this.sourceLinks = const [],
  });

  final int novelId;
  final String source;
  final String title;
  final String description;
  final String body;
  final String? authorName;
  final int? authorId;
  final List<String> tags;
  final NovelSeriesOutline? series;
  final Uri? coverUrl;
  final int? length;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, Uri> images;
  final List<Uri> sourceLinks;

  bool get hasBody => body.trim().isNotEmpty;

  String get fallbackSummary =>
      description.trim().isNotEmpty ? description : body;

  @override
  List<Object?> get props => [
        novelId,
        source,
        title,
        description,
        body,
        authorName,
        authorId,
        tags,
        series,
        coverUrl,
        length,
        createdAt,
        updatedAt,
        images,
        sourceLinks,
      ];

  NovelDetail copyWith({
    String? source,
    String? title,
    String? description,
    String? body,
    String? authorName,
    int? authorId,
    List<String>? tags,
    NovelSeriesOutline? series,
    Uri? coverUrl,
    int? length,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, Uri>? images,
    List<Uri>? sourceLinks,
  }) {
    return NovelDetail(
      novelId: novelId,
      source: source ?? this.source,
      title: title ?? this.title,
      description: description ?? this.description,
      body: body ?? this.body,
      authorName: authorName ?? this.authorName,
      authorId: authorId ?? this.authorId,
      tags: tags ?? this.tags,
      series: series ?? this.series,
      coverUrl: coverUrl ?? this.coverUrl,
      length: length ?? this.length,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      images: images ?? this.images,
      sourceLinks: sourceLinks ?? this.sourceLinks,
    );
  }
}

class NovelSeriesOutline extends Equatable {
  const NovelSeriesOutline({required this.id, required this.title});

  final int id;
  final String title;

  bool get isValid => id > 0 || title.trim().isNotEmpty;

  @override
  List<Object?> get props => [id, title];
}

class NovelSeriesDetail extends Equatable {
  const NovelSeriesDetail({
    required this.id,
    required this.title,
    required this.caption,
    this.tags = const [],
    this.novels = const [],
  });

  final int id;
  final String title;
  final String caption;
  final List<String> tags;
  final List<NovelSeriesEntry> novels;

  @override
  List<Object?> get props => [id, title, caption, tags, novels];
}

class NovelSeriesEntry extends Equatable {
  const NovelSeriesEntry({
    required this.id,
    required this.title,
    this.coverUrl,
  });

  final int id;
  final String title;
  final Uri? coverUrl;

  @override
  List<Object?> get props => [id, title, coverUrl];
}
