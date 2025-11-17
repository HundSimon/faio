import '../../../domain/models/content_item.dart';
import '../../../domain/models/content_tag.dart';
import '../../../domain/utils/content_tag_builder.dart';
import '../../e621/models/e621_post.dart';
import '../../furrynovel/models/furry_novel_models.dart';
import '../../pixiv/models/pixiv_models.dart';

class ContentMapper {
  const ContentMapper._();

  static FaioContent? fromE621(E621Post post) {
    final normalizedSummary = post.description.trim().isNotEmpty
        ? post.description.trim()
        : '';

    final primaryImage = post.preview.url ?? post.sample.url ?? post.file.url;
    if (primaryImage == null) {
      return null;
    }

    final sample = post.sample.url;
    final original = post.file.url;
    final aspectRatio = _resolveAspectRatio(post);
    final tagCategories = _mapE621TagCategories(post.tagCategories);

    return FaioContent(
      id: 'e621:${post.id}',
      source: 'e621',
      title: post.tags.isNotEmpty ? post.tags.first : 'Untitled',
      summary: normalizedSummary,
      type: _inferType(post),
      previewUrl: primaryImage,
      originalUrl: original,
      sampleUrl: sample,
      previewAspectRatio: aspectRatio,
      publishedAt: post.createdAt,
      updatedAt: post.updatedAt,
      rating: post.rating.toNormalizedRating(),
      authorName: null,
      tags: _buildStringTags(post.tags, categoryOverrides: tagCategories),
      favoriteCount: post.favCount,
      sourceLinks: post.sources,
    );
  }

  static double? _resolveAspectRatio(E621Post post) {
    if (post.preview.width > 0 && post.preview.height > 0) {
      return post.preview.width / post.preview.height;
    }
    if (post.sample.width > 0 && post.sample.height > 0) {
      return post.sample.width / post.sample.height;
    }
    if (post.file.width > 0 && post.file.height > 0) {
      return post.file.width / post.file.height;
    }
    return null;
  }

  static ContentType _inferType(E621Post post) {
    if (post.tags.contains('comic')) {
      return ContentType.comic;
    }
    if (post.tags.any(
      (tag) => tag.contains('story') || tag.contains('novel'),
    )) {
      return ContentType.novel;
    }
    return ContentType.illustration;
  }

  static FaioContent? fromPixivIllust(PixivIllust illust) {
    final previewImage =
        illust.imageUrls.medium ??
        illust.imageUrls.large ??
        illust.metaPages.firstOrNull?.imageUrls.medium ??
        illust.imageUrls.squareMedium;
    final sampleImage =
        illust.imageUrls.large ??
        illust.metaPages.firstOrNull?.imageUrls.large ??
        illust.imageUrls.medium;
    final originalImage =
        illust.originalImageUrl ??
        illust.imageUrls.original ??
        illust.metaPages.firstOrNull?.imageUrls.original;

    if (previewImage == null && sampleImage == null) {
      return null;
    }

    final aspectRatio = _pixivAspectRatio(illust);
    final rating = _pixivRating(illust.xRestrict, illust.sanityLevel);
    final tags = _pixivTags(illust.tags);
    final summary = illust.caption.trim();
    final type = switch (illust.type) {
      PixivIllustType.manga => ContentType.comic,
      _ => ContentType.illustration,
    };

    return FaioContent(
      id: 'pixiv:${illust.id}',
      source: 'pixiv',
      title: illust.title.trim().isEmpty ? 'Untitled' : illust.title.trim(),
      summary: summary,
      type: type,
      previewUrl: previewImage ?? sampleImage,
      sampleUrl: sampleImage,
      originalUrl: originalImage,
      previewAspectRatio: aspectRatio,
      publishedAt: illust.createDate,
      updatedAt: illust.updateDate,
      rating: rating,
      authorName: illust.user.name.isEmpty ? null : illust.user.name,
      tags: tags,
      favoriteCount: illust.totalBookmarks,
      sourceLinks: [Uri.parse('https://www.pixiv.net/artworks/${illust.id}')],
    );
  }

  static FaioContent? fromPixivNovel(PixivNovel novel) {
    final previewImage =
        novel.coverImageUrls.medium ??
        novel.coverImageUrls.large ??
        novel.coverImageUrls.squareMedium;

    final summary = novel.caption.trim();
    final tags = _pixivTags(novel.tags);

    return FaioContent(
      id: 'pixiv_novel:${novel.id}',
      source: 'pixiv',
      title: novel.title.trim().isEmpty ? 'Untitled' : novel.title.trim(),
      summary: summary,
      type: ContentType.novel,
      previewUrl: previewImage,
      sampleUrl: novel.coverImageUrls.large ?? previewImage,
      originalUrl: novel.coverImageUrls.original ?? novel.coverImageUrls.large,
      previewAspectRatio: null,
      publishedAt: novel.createDate,
      updatedAt: novel.updateDate,
      rating: 'General',
      authorName: novel.user.name.isEmpty ? null : novel.user.name,
      tags: tags,
      favoriteCount: novel.totalBookmarks,
      sourceLinks: [
        Uri.parse('https://www.pixiv.net/novel/show.php?id=${novel.id}'),
      ],
    );
  }

  static FaioContent? fromFurryNovel(FurryNovel novel) {
    final preview =
        novel.coverUrl ??
        novel.images.values
            .map((image) => image.origin)
            .firstWhere((uri) => uri != null, orElse: () => null);
    final summary = novel.description.trim().isEmpty && novel.content != null
        ? novel.content!.trim()
        : novel.description.trim();
    final authorName =
        (novel.userName != null && novel.userName!.trim().isNotEmpty)
        ? novel.userName!.trim()
        : null;
    final publishedAt =
        novel.createDate ?? DateTime.fromMillisecondsSinceEpoch(0);
    final tags = _buildStringTags(novel.tags);
    final rating = _furryNovelRating(tags);

    final links = <Uri>[
      Uri.parse('https://furrynovel.ink/pixiv/novel/${novel.id}'),
      Uri.parse('https://www.pixiv.net/novel/show.php?id=${novel.id}'),
    ];

    return FaioContent(
      id: 'furrynovel:${novel.id}',
      source: 'furrynovel',
      title: novel.title.trim().isEmpty ? 'Untitled' : novel.title.trim(),
      summary: summary,
      type: ContentType.novel,
      previewUrl: preview,
      sampleUrl: preview,
      originalUrl: preview,
      previewAspectRatio: null,
      publishedAt: publishedAt,
      updatedAt: publishedAt,
      rating: rating,
      authorName: authorName,
      tags: tags,
      favoriteCount: novel.pixivLikeCount,
      sourceLinks: links,
    );
  }

  static double? _pixivAspectRatio(PixivIllust illust) {
    if (illust.width > 0 && illust.height > 0) {
      return illust.width / illust.height;
    }
    final firstPage = illust.metaPages.firstOrNull;
    final width = firstPage?.width ?? 0;
    final height = firstPage?.height ?? 0;
    if (width > 0 && height > 0) {
      return width / height;
    }
    return null;
  }

  static String _pixivRating(int? xRestrict, int? sanityLevel) {
    if (xRestrict != null) {
      if (xRestrict <= 0) {
        return 'General';
      }
      if (xRestrict == 1) {
        return 'Mature';
      }
      return 'Adult';
    }
    if (sanityLevel != null) {
      if (sanityLevel <= 2) {
        return 'General';
      }
      if (sanityLevel <= 4) {
        return 'Mature';
      }
      return 'Adult';
    }
    return 'General';
  }

  static List<ContentTag> _pixivTags(List<PixivTag> tags) {
    final builder = ContentTagBuilder();
    for (final tag in tags) {
      final primary = tag.name.trim();
      if (primary.isEmpty) {
        continue;
      }
      final translated = tag.translatedName?.trim();
      builder.addLabel(
        primary,
        display: translated?.isNotEmpty == true ? translated : primary,
        aliases: [if (translated != null && translated.isNotEmpty) translated],
      );
    }
    return builder.build();
  }

  static List<ContentTag> _buildStringTags(
    List<String> tags, {
    Map<String, ContentTagCategory>? categoryOverrides,
  }) {
    final builder = ContentTagBuilder();
    for (final tag in tags) {
      final normalized = tag.trim();
      if (normalized.isEmpty) {
        continue;
      }
      builder.addLabel(normalized, category: categoryOverrides?[normalized]);
    }
    return builder.build();
  }

  static Map<String, ContentTagCategory> _mapE621TagCategories(
    Map<String, E621TagCategory> raw,
  ) {
    final mapped = <String, ContentTagCategory>{};
    for (final entry in raw.entries) {
      final tagName = entry.key.trim();
      if (tagName.isEmpty) {
        continue;
      }
      final category = switch (entry.value) {
        E621TagCategory.species => ContentTagCategory.species,
        E621TagCategory.character => ContentTagCategory.character,
        E621TagCategory.copyright => ContentTagCategory.theme,
        E621TagCategory.lore => ContentTagCategory.theme,
        _ => ContentTagCategory.general,
      };
      mapped[tagName] = category;
    }
    return mapped;
  }

  static String _furryNovelRating(List<ContentTag> tags) {
    final lowered = tags.map((tag) => tag.canonicalName).toList();
    if (lowered.any((tag) => tag.contains('r18') || tag.contains('r_18'))) {
      return 'Adult';
    }
    if (lowered.any((tag) => tag.contains('r15') || tag.contains('r_15'))) {
      return 'Mature';
    }
    return 'General';
  }
}

extension on List<PixivMetaPage> {
  PixivMetaPage? get firstOrNull => isEmpty ? null : this[0];
}
