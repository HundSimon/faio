import 'package:equatable/equatable.dart';

import '../../../domain/models/content_item.dart';

enum LibraryFavoriteKind { content, series }

class LibraryHistoryEntry extends Equatable {
  const LibraryHistoryEntry({required this.content, required this.viewedAt});

  final FaioContent content;
  final DateTime viewedAt;

  String get key => content.id;

  @override
  List<Object?> get props => [content, viewedAt];
}

class LibrarySeriesFavorite extends Equatable {
  const LibrarySeriesFavorite({
    required this.seriesId,
    required this.title,
    this.caption,
    this.coverUrl,
  });

  final int seriesId;
  final String title;
  final String? caption;
  final Uri? coverUrl;

  String get key => 'series:$seriesId';

  @override
  List<Object?> get props => [seriesId, title, caption, coverUrl];
}

class LibraryFavoriteEntry extends Equatable {
  const LibraryFavoriteEntry.content({
    required FaioContent content,
    required DateTime savedAt,
  }) : kind = LibraryFavoriteKind.content,
       content = content,
       series = null,
       savedAt = savedAt;

  const LibraryFavoriteEntry.series({
    required LibrarySeriesFavorite series,
    required DateTime savedAt,
  }) : kind = LibraryFavoriteKind.series,
       content = null,
       series = series,
       savedAt = savedAt;

  final LibraryFavoriteKind kind;
  final FaioContent? content;
  final LibrarySeriesFavorite? series;
  final DateTime savedAt;

  bool get isContent => kind == LibraryFavoriteKind.content;
  bool get isSeries => kind == LibraryFavoriteKind.series;

  String get key => isContent ? content!.id : series!.key;

  @override
  List<Object?> get props => [kind, content, series, savedAt];
}
