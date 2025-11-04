import 'dart:convert';

enum PixivIllustType { illustration, manga, ugoira, unknown }

PixivIllustType parsePixivIllustType(String? type) {
  return switch (type) {
    'illust' || 'illustration' => PixivIllustType.illustration,
    'manga' => PixivIllustType.manga,
    'ugoira' => PixivIllustType.ugoira,
    _ => PixivIllustType.unknown,
  };
}

class PixivImageUrls {
  const PixivImageUrls({
    this.squareMedium,
    this.medium,
    this.large,
    this.original,
  });

  final Uri? squareMedium;
  final Uri? medium;
  final Uri? large;
  final Uri? original;

  factory PixivImageUrls.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const PixivImageUrls();
    }
    Uri? parseUrl(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return Uri.tryParse(value);
      }
      return null;
    }

    return PixivImageUrls(
      squareMedium: parseUrl(json['square_medium']),
      medium: parseUrl(json['medium']),
      large: parseUrl(json['large']),
      original: parseUrl(json['original'] ?? json['original_image_url']),
    );
  }

  PixivImageUrls merge(PixivImageUrls override) {
    return PixivImageUrls(
      squareMedium: override.squareMedium ?? squareMedium,
      medium: override.medium ?? medium,
      large: override.large ?? large,
      original: override.original ?? original,
    );
  }
}

class PixivMetaPage {
  const PixivMetaPage({required this.imageUrls, this.width, this.height});

  final PixivImageUrls imageUrls;
  final int? width;
  final int? height;

  factory PixivMetaPage.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const PixivMetaPage(imageUrls: PixivImageUrls());
    }
    return PixivMetaPage(
      imageUrls: PixivImageUrls.fromJson(
        json['image_urls'] as Map<String, dynamic>?,
      ),
      width: json['width'] as int?,
      height: json['height'] as int?,
    );
  }
}

class PixivTag {
  const PixivTag({required this.name, this.translatedName});

  final String name;
  final String? translatedName;

  factory PixivTag.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const PixivTag(name: '');
    }
    return PixivTag(
      name: json['name'] as String? ?? '',
      translatedName: json['translated_name'] as String?,
    );
  }
}

class PixivUserSummary {
  const PixivUserSummary({
    required this.id,
    required this.name,
    this.account,
    this.profileImageUrls = const PixivImageUrls(),
  });

  final int id;
  final String name;
  final String? account;
  final PixivImageUrls profileImageUrls;

  factory PixivUserSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const PixivUserSummary(id: 0, name: '');
    }
    return PixivUserSummary(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      account: json['account'] as String?,
      profileImageUrls: PixivImageUrls.fromJson(
        json['profile_image_urls'] as Map<String, dynamic>?,
      ),
    );
  }
}

class PixivIllust {
  const PixivIllust({
    required this.id,
    required this.title,
    required this.caption,
    required this.type,
    required this.createDate,
    this.updateDate,
    required this.width,
    required this.height,
    required this.pageCount,
    required this.totalBookmarks,
    required this.tags,
    required this.user,
    required this.imageUrls,
    this.metaPages = const [],
    this.originalImageUrl,
    this.sanityLevel,
    this.xRestrict,
    this.aiType,
  });

  final int id;
  final String title;
  final String caption;
  final PixivIllustType type;
  final DateTime createDate;
  final DateTime? updateDate;
  final int width;
  final int height;
  final int pageCount;
  final int totalBookmarks;
  final List<PixivTag> tags;
  final PixivUserSummary user;
  final PixivImageUrls imageUrls;
  final List<PixivMetaPage> metaPages;
  final Uri? originalImageUrl;
  final int? sanityLevel;
  final int? xRestrict;
  final int? aiType;

  factory PixivIllust.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return PixivIllust(
        id: 0,
        title: '',
        caption: '',
        type: PixivIllustType.unknown,
        createDate: DateTime.fromMillisecondsSinceEpoch(0),
        width: 0,
        height: 0,
        pageCount: 0,
        totalBookmarks: 0,
        tags: [],
        user: PixivUserSummary(id: 0, name: ''),
        imageUrls: PixivImageUrls(),
      );
    }

    DateTime parseDate(String? raw) {
      if (raw == null || raw.isEmpty) {
        return DateTime.fromMillisecondsSinceEpoch(0);
      }
      return DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }

    final metaSinglePage = json['meta_single_page'] as Map<String, dynamic>?;
    final original =
        PixivImageUrls.fromJson(metaSinglePage).original ??
        Uri.tryParse((metaSinglePage?['original_image_url'] as String? ?? ''));

    final baseImageUrls = PixivImageUrls.fromJson(
      json['image_urls'] as Map<String, dynamic>?,
    );

    final metaPagesJson = json['meta_pages'];
    final metaPages = switch (metaPagesJson) {
      List list =>
        list
            .whereType<Map<String, dynamic>>()
            .map(PixivMetaPage.fromJson)
            .toList(),
      _ => <PixivMetaPage>[],
    };

    final tagsJson = json['tags'];
    final tags = switch (tagsJson) {
      List list =>
        list
            .whereType<Map<String, dynamic>>()
            .map(PixivTag.fromJson)
            .where((tag) => tag.name.isNotEmpty)
            .toList(),
      _ => <PixivTag>[],
    };

    return PixivIllust(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      caption: json['caption'] as String? ?? '',
      type: parsePixivIllustType(json['type'] as String?),
      createDate: parseDate(json['create_date'] as String?),
      updateDate: (json.containsKey('update_date'))
          ? DateTime.tryParse(json['update_date'] as String? ?? '')
          : null,
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
      pageCount: json['page_count'] as int? ?? 0,
      totalBookmarks: json['total_bookmarks'] as int? ?? 0,
      tags: tags,
      user: PixivUserSummary.fromJson(json['user'] as Map<String, dynamic>?),
      imageUrls: baseImageUrls,
      metaPages: metaPages,
      originalImageUrl: original,
      sanityLevel: json['sanity_level'] as int?,
      xRestrict: json['x_restrict'] as int?,
      aiType: json['ai_type'] as int?,
    );
  }
}

class PixivNovel {
  const PixivNovel({
    required this.id,
    required this.title,
    required this.caption,
    required this.createDate,
    this.updateDate,
    required this.user,
    required this.tags,
    required this.totalBookmarks,
    this.coverImageUrls = const PixivImageUrls(),
    this.textLength,
    this.seriesTitle,
  });

  final int id;
  final String title;
  final String caption;
  final DateTime createDate;
  final DateTime? updateDate;
  final PixivUserSummary user;
  final List<PixivTag> tags;
  final int totalBookmarks;
  final PixivImageUrls coverImageUrls;
  final int? textLength;
  final String? seriesTitle;

  factory PixivNovel.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return PixivNovel(
        id: 0,
        title: '',
        caption: '',
        createDate: DateTime.fromMillisecondsSinceEpoch(0),
        user: PixivUserSummary(id: 0, name: ''),
        tags: [],
        totalBookmarks: 0,
      );
    }

    DateTime parseDate(String? raw) {
      if (raw == null || raw.isEmpty) {
        return DateTime.fromMillisecondsSinceEpoch(0);
      }
      return DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }

    final tagsJson = json['tags'];
    final tags = switch (tagsJson) {
      List list =>
        list
            .whereType<Map<String, dynamic>>()
            .map(PixivTag.fromJson)
            .where((tag) => tag.name.isNotEmpty)
            .toList(),
      _ => <PixivTag>[],
    };

    final imageUrls = PixivImageUrls.fromJson(
      json['image_urls'] as Map<String, dynamic>?,
    );

    return PixivNovel(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      caption: json['caption'] as String? ?? '',
      createDate: parseDate(json['create_date'] as String?),
      updateDate: (json.containsKey('update_date'))
          ? DateTime.tryParse(json['update_date'] as String? ?? '')
          : null,
      user: PixivUserSummary.fromJson(json['user'] as Map<String, dynamic>?),
      tags: tags,
      totalBookmarks: json['total_bookmarks'] as int? ?? 0,
      coverImageUrls: imageUrls,
      textLength: json['text_length'] as int?,
      seriesTitle:
          (json['series'] as Map<String, dynamic>?)?['title'] as String?,
    );
  }
}

class PixivPage<T> {
  const PixivPage({required this.items, this.nextUrl});

  final List<T> items;
  final String? nextUrl;

  bool get hasNextPage => nextUrl != null && nextUrl!.isNotEmpty;

  int? get nextOffset {
    if (nextUrl == null || nextUrl!.isEmpty) {
      return null;
    }
    try {
      final uri = Uri.parse(nextUrl!);
      final offsetString = uri.queryParameters['offset'];
      if (offsetString == null) {
        return null;
      }
      return int.tryParse(offsetString);
    } catch (_) {
      return null;
    }
  }

  Uri? get nextUri {
    if (nextUrl == null || nextUrl!.isEmpty) {
      return null;
    }
    return Uri.tryParse(nextUrl!);
  }

  Map<String, dynamic> toJson(Object Function(T value) toJsonT) {
    return {'items': items.map(toJsonT).toList(), 'nextUrl': nextUrl};
  }

  static PixivPage<T> fromJson<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> json) fromJsonT,
  ) {
    final items = (json['items'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(fromJsonT)
        .toList();
    return PixivPage<T>(items: items, nextUrl: json['nextUrl'] as String?);
  }
}

List<PixivIllust> parsePixivIllustList(dynamic data) {
  if (data is List) {
    return data
        .whereType<Map<String, dynamic>>()
        .map(PixivIllust.fromJson)
        .toList();
  }
  if (data is String && data.isNotEmpty) {
    try {
      final parsed = jsonDecode(data);
      return parsePixivIllustList(parsed);
    } catch (_) {
      return const [];
    }
  }
  return const [];
}

List<PixivNovel> parsePixivNovelList(dynamic data) {
  if (data is List) {
    return data
        .whereType<Map<String, dynamic>>()
        .map(PixivNovel.fromJson)
        .toList();
  }
  if (data is String && data.isNotEmpty) {
    try {
      final parsed = jsonDecode(data);
      return parsePixivNovelList(parsed);
    } catch (_) {
      return const [];
    }
  }
  return const [];
}
