import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/models/content_item.dart';
import '../../../domain/models/content_tag.dart';
import '../domain/library_entries.dart';

class LibraryStorage {
  LibraryStorage({Future<SharedPreferences>? prefsFuture})
    : _prefsFuture = prefsFuture ?? SharedPreferences.getInstance();

  final Future<SharedPreferences> _prefsFuture;

  static const _favoritesKey = 'library_favorites_v1';
  static const _historyKey = 'library_history_v1';

  Future<List<LibraryFavoriteEntry>> loadFavorites() async {
    final prefs = await _prefsFuture;
    final rawList = prefs.getStringList(_favoritesKey);
    if (rawList == null || rawList.isEmpty) {
      return const [];
    }

    final entries = <LibraryFavoriteEntry>[];
    for (final raw in rawList) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>?;
        final entry = _decodeFavorite(decoded);
        if (entry != null) {
          entries.add(entry);
        }
      } catch (_) {
        continue;
      }
    }
    entries.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return entries;
  }

  Future<void> saveFavorites(List<LibraryFavoriteEntry> entries) async {
    final prefs = await _prefsFuture;
    final encoded = entries
        .map(_encodeFavorite)
        .whereType<Map<String, dynamic>>()
        .map(jsonEncode)
        .toList();
    await prefs.setStringList(_favoritesKey, encoded);
  }

  Future<List<LibraryHistoryEntry>> loadHistory() async {
    final prefs = await _prefsFuture;
    final rawList = prefs.getStringList(_historyKey);
    if (rawList == null || rawList.isEmpty) {
      return const [];
    }

    final entries = <LibraryHistoryEntry>[];
    for (final raw in rawList) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>?;
        final entry = _decodeHistory(decoded);
        if (entry != null) {
          entries.add(entry);
        }
      } catch (_) {
        continue;
      }
    }
    entries.sort((a, b) => b.viewedAt.compareTo(a.viewedAt));
    return entries;
  }

  Future<void> saveHistory(List<LibraryHistoryEntry> entries) async {
    final prefs = await _prefsFuture;
    final encoded = entries
        .map(_encodeHistory)
        .whereType<Map<String, dynamic>>()
        .map(jsonEncode)
        .toList();
    await prefs.setStringList(_historyKey, encoded);
  }
}

Map<String, dynamic>? _encodeFavorite(LibraryFavoriteEntry entry) {
  final map = <String, dynamic>{
    'kind': entry.kind.name,
    'savedAt': entry.savedAt.toIso8601String(),
  };
  if (entry.content != null) {
    map['content'] = _encodeContent(entry.content!);
  } else if (entry.series != null) {
    map['series'] = _encodeSeries(entry.series!);
  } else {
    return null;
  }
  return map;
}

LibraryFavoriteEntry? _decodeFavorite(Map<String, dynamic>? json) {
  if (json == null) {
    return null;
  }
  final savedAtRaw = json['savedAt'] as String?;
  final savedAt = savedAtRaw != null ? DateTime.tryParse(savedAtRaw) : null;
  if (savedAt == null) {
    return null;
  }

  final kindRaw = json['kind'] as String? ?? LibraryFavoriteKind.content.name;
  final kind = LibraryFavoriteKind.values.firstWhere(
    (value) => value.name == kindRaw,
    orElse: () => LibraryFavoriteKind.content,
  );

  switch (kind) {
    case LibraryFavoriteKind.content:
      final content = _decodeContent(json['content'] as Map<String, dynamic>?);
      if (content == null) {
        return null;
      }
      return LibraryFavoriteEntry.content(content: content, savedAt: savedAt);
    case LibraryFavoriteKind.series:
      final series = _decodeSeries(json['series'] as Map<String, dynamic>?);
      if (series == null) {
        return null;
      }
      return LibraryFavoriteEntry.series(series: series, savedAt: savedAt);
  }
}

Map<String, dynamic>? _encodeHistory(LibraryHistoryEntry entry) {
  return {
    'viewedAt': entry.viewedAt.toIso8601String(),
    'content': _encodeContent(entry.content),
  };
}

LibraryHistoryEntry? _decodeHistory(Map<String, dynamic>? json) {
  if (json == null) {
    return null;
  }
  final viewedAtRaw = json['viewedAt'] as String?;
  final viewedAt = viewedAtRaw != null ? DateTime.tryParse(viewedAtRaw) : null;
  if (viewedAt == null) {
    return null;
  }
  final content = _decodeContent(json['content'] as Map<String, dynamic>?);
  if (content == null) {
    return null;
  }
  return LibraryHistoryEntry(content: content, viewedAt: viewedAt);
}

Map<String, dynamic>? _encodeContent(FaioContent content) {
  return {
    'id': content.id,
    'source': content.source,
    'title': content.title,
    'summary': content.summary,
    'type': content.type.name,
    'previewUrl': content.previewUrl?.toString(),
    'originalUrl': content.originalUrl?.toString(),
    'sampleUrl': content.sampleUrl?.toString(),
    'previewAspectRatio': content.previewAspectRatio,
    'publishedAt': content.publishedAt.toIso8601String(),
    'updatedAt': content.updatedAt?.toIso8601String(),
    'rating': content.rating,
    'authorName': content.authorName,
    'tags': content.tags.map((tag) => tag.toJson()).toList(),
    'favoriteCount': content.favoriteCount,
    'sourceLinks': content.sourceLinks.map((uri) => uri.toString()).toList(),
  };
}

FaioContent? _decodeContent(Map<String, dynamic>? json) {
  if (json == null) {
    return null;
  }

  final id = json['id'] as String?;
  final source = json['source'] as String?;
  final title = json['title'] as String?;
  final summary = json['summary'] as String?;
  final typeRaw = json['type'] as String?;
  final publishedAtRaw = json['publishedAt'] as String?;
  final rating = json['rating'] as String?;

  if (id == null ||
      source == null ||
      title == null ||
      summary == null ||
      typeRaw == null ||
      publishedAtRaw == null ||
      rating == null) {
    return null;
  }

  final contentType = ContentType.values.firstWhere(
    (value) => value.name == typeRaw,
    orElse: () => ContentType.illustration,
  );

  final publishedAt = DateTime.tryParse(publishedAtRaw);
  if (publishedAt == null) {
    return null;
  }

  return FaioContent(
    id: id,
    source: source,
    title: title,
    summary: summary,
    type: contentType,
    previewUrl: _tryParseUri(json['previewUrl'] as String?),
    originalUrl: _tryParseUri(json['originalUrl'] as String?),
    sampleUrl: _tryParseUri(json['sampleUrl'] as String?),
    previewAspectRatio: (json['previewAspectRatio'] as num?)?.toDouble(),
    publishedAt: publishedAt,
    updatedAt: _tryParseDate(json['updatedAt'] as String?),
    rating: rating,
    authorName: json['authorName'] as String?,
    tags: _decodeTags(json['tags']),
    favoriteCount: json['favoriteCount'] is num
        ? (json['favoriteCount'] as num).toInt()
        : 0,
    sourceLinks: (json['sourceLinks'] as List<dynamic>? ?? const [])
        .map((e) => _tryParseUri(e as String?))
        .whereType<Uri>()
        .toList(),
  );
}

List<ContentTag> _decodeTags(dynamic raw) {
  if (raw is List) {
    final tags = <ContentTag>[];
    for (final entry in raw) {
      if (entry is Map<String, dynamic>) {
        final tag = ContentTag.fromJson(entry);
        if (tag.canonicalName.isNotEmpty) {
          tags.add(tag);
        }
      } else if (entry is String && entry.trim().isNotEmpty) {
        tags.add(ContentTag.fromLabels(primary: entry));
      } else if (entry != null) {
        tags.add(ContentTag.fromLabels(primary: entry.toString()));
      }
    }
    return tags;
  }
  return const <ContentTag>[];
}

Map<String, dynamic> _encodeSeries(LibrarySeriesFavorite series) {
  return {
    'seriesId': series.seriesId,
    'title': series.title,
    'caption': series.caption,
    'coverUrl': series.coverUrl?.toString(),
  };
}

LibrarySeriesFavorite? _decodeSeries(Map<String, dynamic>? json) {
  if (json == null) {
    return null;
  }
  final id = json['seriesId'] as int?;
  final title = json['title'] as String?;
  if (id == null || title == null) {
    return null;
  }
  return LibrarySeriesFavorite(
    seriesId: id,
    title: title,
    caption: json['caption'] as String?,
    coverUrl: _tryParseUri(json['coverUrl'] as String?),
  );
}

Uri? _tryParseUri(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  return Uri.tryParse(value);
}

DateTime? _tryParseDate(String? raw) {
  if (raw == null || raw.isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw);
}
