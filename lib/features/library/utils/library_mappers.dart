import '../../../domain/models/content_item.dart';
import '../../../domain/models/content_tag.dart';
import '../../../domain/models/novel_detail.dart';
import '../../../domain/utils/content_id.dart';

FaioContent novelDetailToContent(NovelDetail detail, {FaioContent? fallback}) {
  final fallbackSummary = detail.fallbackSummary.trim();
  final summary = fallbackSummary.isNotEmpty
      ? fallbackSummary
      : (fallback?.summary ?? detail.body);
  final previewUrl = detail.coverUrl ?? fallback?.previewUrl;
  final publishedAt =
      detail.createdAt ?? fallback?.publishedAt ?? DateTime.now();

  return FaioContent(
    id: fallback?.id ?? 'novel:${detail.novelId}',
    source: detail.source,
    title: detail.title,
    summary: summary,
    type: ContentType.novel,
    previewUrl: previewUrl,
    originalUrl: fallback?.originalUrl,
    sampleUrl: fallback?.sampleUrl,
    previewAspectRatio: fallback?.previewAspectRatio,
    publishedAt: publishedAt,
    updatedAt: detail.updatedAt ?? fallback?.updatedAt,
    rating: fallback?.rating ?? 'General',
    authorName: detail.authorName ?? fallback?.authorName,
    tags: detail.tags.isNotEmpty
        ? detail.tags
        : (fallback?.tags ?? const <ContentTag>[]),
    favoriteCount: detail.likeCount ?? fallback?.favoriteCount ?? 0,
    sourceLinks: detail.sourceLinks.isNotEmpty
        ? detail.sourceLinks
        : (fallback?.sourceLinks ?? const []),
  );
}

NovelDetail contentToNovelDetail(FaioContent content, {int? novelIdOverride}) {
  final numericId = novelIdOverride ?? parseContentNumericId(content) ?? 0;
  final coverUrl = content.sampleUrl ?? content.previewUrl;
  return NovelDetail(
    novelId: numericId,
    source: content.source,
    title: content.title,
    description: content.summary,
    body: content.summary,
    authorName: content.authorName,
    tags: content.tags,
    coverUrl: coverUrl,
    createdAt: content.publishedAt,
    updatedAt: content.updatedAt,
    sourceLinks: content.sourceLinks,
    likeCount: content.favoriteCount,
  );
}
