import '../../../domain/models/novel_detail.dart';
import '../../furrynovel/models/furry_novel_models.dart';
import '../../pixiv/models/pixiv_models.dart';

class NovelMapper {
  static NovelDetail? fromFurryNovel(FurryNovel novel) {
    final body = (novel.content ?? novel.description).trim();
    final description = novel.description.trim();
    final resolvedBody = body.isNotEmpty ? body : description;
    final resolvedDescription =
        description.isNotEmpty ? description : resolvedBody;
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
      tags: novel.tags,
      series: series,
      coverUrl: novel.coverUrl,
      length: novel.length,
      createdAt: novel.createDate,
      updatedAt: novel.createDate,
      images: images,
      sourceLinks: links,
    );
  }

  static NovelDetail? fromPixivNovel(PixivNovel novel) {
    final summary = novel.caption.trim();
    final title = novel.title.trim().isEmpty ? 'Untitled' : novel.title.trim();
    final image =
        novel.coverImageUrls.large ??
        novel.coverImageUrls.medium ??
        novel.coverImageUrls.squareMedium;

    return NovelDetail(
      novelId: novel.id,
      source: 'pixiv',
      title: title,
      description: summary,
      body: summary,
      authorName:
          novel.user.name.trim().isNotEmpty ? novel.user.name.trim() : null,
      authorId: novel.user.id == 0 ? null : novel.user.id,
      tags: novel.tags.map((tag) => tag.name).toList(),
      series: null,
      coverUrl: image,
      length: novel.textLength,
      createdAt: novel.createDate,
      updatedAt: novel.updateDate,
      images: const {},
      sourceLinks: [
        Uri.parse('https://www.pixiv.net/novel/show.php?id=${novel.id}'),
      ],
    );
  }

  static NovelSeriesDetail? fromFurrySeries(FurryNovelSeriesDetail? detail) {
    if (detail == null) {
      return null;
    }

    return NovelSeriesDetail(
      id: detail.id,
      title: detail.title,
      caption: detail.caption,
      tags: detail.tags,
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
}
