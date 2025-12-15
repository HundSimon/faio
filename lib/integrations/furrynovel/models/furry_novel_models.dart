int? _parseFlexibleInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  if (value is double) {
    return value.toInt();
  }
  return null;
}

class FurryNovelPage {
  const FurryNovelPage({
    required this.items,
    required this.page,
    required this.pageSize,
  });

  final List<FurryNovel> items;
  final int page;
  final int pageSize;

  bool get hasMore => items.isNotEmpty;

  static FurryNovelPage fromResponse(
    dynamic response, {
    required int page,
    required int pageSizeHint,
  }) {
    final items = <FurryNovel>[];
    if (response is Map<String, dynamic>) {
      final dynamic payload = response['novels'] ?? response['data'];
      if (payload is List) {
        for (final element in payload) {
          if (element is Map<String, dynamic>) {
            items.add(FurryNovel.fromJson(element));
          }
        }
      }
    } else if (response is List) {
      for (final element in response) {
        if (element is Map<String, dynamic>) {
          items.add(FurryNovel.fromJson(element));
        }
      }
    }
    final pageSize = pageSizeHint > 0
        ? pageSizeHint
        : (items.isNotEmpty ? items.length : 30);
    return FurryNovelPage(items: items, page: page, pageSize: pageSize);
  }

  static FurryNovel? parseNovel(dynamic response) {
    if (response is Map<String, dynamic>) {
      if (response.containsKey('id')) {
        return FurryNovel.fromJson(response);
      }
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        return FurryNovel.fromJson(data);
      }
    }
    return null;
  }
}

class FurryNovel {
  const FurryNovel({
    required this.id,
    required this.title,
    required this.description,
    this.content,
    this.userName,
    this.userId,
    required this.tags,
    this.series,
    required this.coverUrl,
    this.createDate,
    this.length,
    this.images = const {},
    this.pixivLikeCount = 0,
    this.pixivReadCount = 0,
  });

  final int id;
  final String title;
  final String description;
  final String? content;
  final String? userName;
  final int? userId;
  final List<String> tags;
  final FurryNovelSeries? series;
  final Uri? coverUrl;
  final DateTime? createDate;
  final int? length;
  final Map<String, FurryNovelImage> images;
  final int pixivLikeCount;
  final int pixivReadCount;

  factory FurryNovel.fromJson(Map<String, dynamic> json) {
    Uri? parseUri(dynamic value) {
      if (value is String && value.trim().isNotEmpty) {
        final trimmed = value.trim();
        if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
          return Uri.tryParse(trimmed);
        }
        return Uri.tryParse('https://$trimmed');
      }
      return null;
    }

    DateTime? parseDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    List<String> parseTags(dynamic value) {
      if (value is List) {
        return value
            .whereType<String>()
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList();
      }
      if (value is String && value.isNotEmpty) {
        return value
            .split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList();
      }
      return const [];
    }

    final images = <String, FurryNovelImage>{};
    final rawImages = json['images'];
    if (rawImages is Map) {
      rawImages.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          images[key.toString()] = FurryNovelImage.fromJson(value);
        }
      });
    }

    return FurryNovel(
      id: _parseFlexibleInt(json['id']) ?? 0,
      title: (json['title'] as String? ?? json['name'] as String? ?? '').trim(),
      description: (json['desc'] as String? ?? '').trim(),
      content: json['content'] as String?,
      userName: json['userName'] as String?,
      userId: _parseFlexibleInt(json['userId']),
      tags: parseTags(json['tags']),
      series: FurryNovelSeries.fromJson(json['series']),
      coverUrl: parseUri(json['coverUrl'] ?? json['cover']),
      createDate: parseDate(json['createDate'] ?? json['create_date']),
      length: _parseFlexibleInt(json['length']),
      images: images,
      pixivLikeCount: _parseFlexibleInt(json['pixivLikeCount']) ?? 0,
      pixivReadCount: _parseFlexibleInt(json['pixivReadCount']) ?? 0,
    );
  }
}

class FurryNovelSeries {
  const FurryNovelSeries({required this.id, required this.title});

  final int id;
  final String title;

  factory FurryNovelSeries.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      return FurryNovelSeries(
        id: _parseFlexibleInt(json['id']) ?? 0,
        title: (json['title'] as String? ?? '').trim(),
      );
    }
    return const FurryNovelSeries(id: 0, title: '');
  }

  bool get isValid => id > 0 || title.isNotEmpty;
}

class FurryNovelImage {
  const FurryNovelImage({this.origin});

  final Uri? origin;

  factory FurryNovelImage.fromJson(Map<String, dynamic> json) {
    Uri? parseUri(dynamic value) {
      if (value is String && value.trim().isNotEmpty) {
        final trimmed = value.trim();
        if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
          return Uri.tryParse(trimmed);
        }
        return Uri.tryParse('https://$trimmed');
      }
      return null;
    }

    return FurryNovelImage(origin: parseUri(json['origin']));
  }
}

class FurryNovelSeriesDetail {
  const FurryNovelSeriesDetail({
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
  final List<FurryNovelSeriesEntry> novels;

  factory FurryNovelSeriesDetail.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const FurryNovelSeriesDetail(id: 0, title: '', caption: '');
    }

    List<String> parseTags(dynamic value) {
      if (value is List) {
        return value
            .whereType<String>()
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList();
      }
      if (value is String && value.isNotEmpty) {
        return value
            .split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList();
      }
      return const [];
    }

    final novelsRaw = json['novels'];
    final novels = <FurryNovelSeriesEntry>[];
    if (novelsRaw is List) {
      for (final element in novelsRaw) {
        if (element is Map<String, dynamic>) {
          novels.add(FurryNovelSeriesEntry.fromJson(element));
        }
      }
    }

    return FurryNovelSeriesDetail(
      id: _parseFlexibleInt(json['id']) ?? 0,
      title: (json['title'] as String? ?? '').trim(),
      caption: (json['caption'] as String? ?? '').trim(),
      tags: parseTags(json['tags']),
      novels: novels,
    );
  }
}

class FurryNovelSeriesEntry {
  const FurryNovelSeriesEntry({
    required this.id,
    required this.title,
    this.coverUrl,
  });

  final int id;
  final String title;
  final Uri? coverUrl;

  factory FurryNovelSeriesEntry.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const FurryNovelSeriesEntry(id: 0, title: '');
    }

    Uri? parseUri(dynamic value) {
      if (value is String && value.trim().isNotEmpty) {
        final trimmed = value.trim();
        if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
          return Uri.tryParse(trimmed);
        }
        return Uri.tryParse('https://$trimmed');
      }
      return null;
    }

    return FurryNovelSeriesEntry(
      id: _parseFlexibleInt(json['id']) ?? 0,
      title: (json['title'] as String? ?? '').trim(),
      coverUrl: parseUri(json['coverUrl'] ?? json['cover_url']),
    );
  }
}
