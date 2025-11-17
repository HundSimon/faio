import '../../../domain/models/content_tag.dart';
import '../../../domain/models/novel_detail.dart';
import '../../../domain/utils/content_tag_builder.dart';
import '../../furrynovel/models/furry_novel_models.dart';
import '../../pixiv/models/pixiv_models.dart';

class NovelMapper {
  static NovelDetail? fromFurryNovel(
    FurryNovel novel, {
    int? likeCountOverride,
  }) {
    final body = (novel.content ?? novel.description).trim();
    final description = novel.description.trim();
    final resolvedBody = body.isNotEmpty ? body : description;
    final resolvedDescription = description.isNotEmpty
        ? description
        : resolvedBody;
    final title = novel.title.trim().isEmpty ? 'Untitled' : novel.title.trim();
    final authorName = novel.userName?.trim();
    final outline = novel.series?.isValid ?? false ? novel.series : null;
    final images = <String, Uri>{};
    novel.images.forEach((key, value) {
      final origin = value.origin;
      if (origin != null) {
        images[key] = origin;
      }
    });

    final series = outline != null
        ? NovelSeriesOutline(id: outline.id, title: outline.title)
        : null;

    final links = <Uri>[
      Uri.parse('https://furrynovel.ink/pixiv/novel/${novel.id}'),
      Uri.parse('https://www.pixiv.net/novel/show.php?id=${novel.id}'),
    ];

    final tags = _stringTags(novel.tags);
    return NovelDetail(
      novelId: novel.id,
      source: 'furrynovel',
      title: title,
      description: resolvedDescription,
      body: resolvedBody,
      authorName: (authorName != null && authorName.isNotEmpty)
          ? authorName
          : null,
      authorId: novel.userId,
      tags: tags,
      series: series,
      coverUrl: novel.coverUrl,
      length: novel.length,
      createdAt: novel.createDate,
      updatedAt: novel.createDate,
      images: images,
      sourceLinks: links,
      likeCount: likeCountOverride ?? novel.pixivLikeCount,
      readCount: novel.pixivReadCount,
    );
  }

  static NovelDetail? fromPixivNovel(PixivNovel novel) {
    final summary = novel.caption.trim();
    final title = novel.title.trim().isEmpty ? 'Untitled' : novel.title.trim();
    final image =
        novel.coverImageUrls.large ??
        novel.coverImageUrls.medium ??
        novel.coverImageUrls.squareMedium;

    final tags = _pixivTags(novel.tags);
    final body = (() {
      final text = novel.text?.trim();
      if (text != null && text.isNotEmpty) {
        return text;
      }
      return summary;
    })();
    final description = summary.isNotEmpty ? summary : body;

    NovelSeriesOutline? series;
    final hasSeriesId = (novel.seriesId ?? 0) > 0;
    final hasSeriesTitle = (novel.seriesTitle?.trim().isNotEmpty ?? false);
    if (hasSeriesId || hasSeriesTitle) {
      series = NovelSeriesOutline(
        id: novel.seriesId ?? 0,
        title: novel.seriesTitle?.trim() ?? '',
      );
    }

    return NovelDetail(
      novelId: novel.id,
      source: 'pixiv',
      title: title,
      description: description,
      body: body,
      authorName: novel.user.name.trim().isNotEmpty
          ? novel.user.name.trim()
          : null,
      authorId: novel.user.id == 0 ? null : novel.user.id,
      tags: tags,
      series: series,
      coverUrl: image,
      length: novel.textLength ?? novel.text?.length,
      createdAt: novel.createDate,
      updatedAt: novel.updateDate,
      images: const {},
      sourceLinks: [
        Uri.parse('https://www.pixiv.net/novel/show.php?id=${novel.id}'),
      ],
      likeCount: novel.totalBookmarks,
    );
  }

  static NovelSeriesDetail? fromFurrySeries(FurryNovelSeriesDetail? detail) {
    if (detail == null) {
      return null;
    }

    final tags = _stringTags(detail.tags);
    return NovelSeriesDetail(
      id: detail.id,
      title: detail.title,
      caption: detail.caption,
      tags: tags,
      novels: detail.novels
          .map(
            (entry) => NovelSeriesEntry(
              id: entry.id,
              title: entry.title,
              coverUrl: entry.coverUrl,
            ),
          )
          .toList(),
    );
  }

  static List<ContentTag> _stringTags(List<String> tags) {
    final builder = ContentTagBuilder();
    for (final tag in tags) {
      if (tag.trim().isEmpty) continue;
      builder.addLabel(tag);
    }
    return builder.build();
  }

  static List<ContentTag> _pixivTags(List<PixivTag> tags) {
    final builder = ContentTagBuilder();
    for (final tag in tags) {
      final primary = tag.name.trim();
      if (primary.isEmpty) continue;
      final translated = tag.translatedName?.trim();
      builder.addLabel(
        primary,
        display: translated?.isNotEmpty == true ? translated : primary,
        aliases: [if (translated != null && translated.isNotEmpty) translated],
      );
    }
    return builder.build();
  }
}
