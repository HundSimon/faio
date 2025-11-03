import '../../../domain/models/content_item.dart';
import '../../e621/models/e621_post.dart';

class ContentMapper {
  const ContentMapper._();

  static FaioContent fromE621(E621Post post) {
    final normalizedSummary = post.description.isNotEmpty
        ? post.description
        : post.tags.take(8).join(', ');

    final preview = post.preview.url ?? post.file.url;
    final aspectRatio = _resolveAspectRatio(post);

    return FaioContent(
      id: 'e621:${post.id}',
      source: 'e621',
      title: post.tags.isNotEmpty ? post.tags.first : 'Untitled',
      summary: normalizedSummary,
      type: _inferType(post),
      previewUrl: preview,
      previewAspectRatio: aspectRatio,
      publishedAt: post.createdAt,
      rating: post.rating.toNormalizedRating(),
      authorName: null,
      tags: post.tags,
    );
  }

  static double? _resolveAspectRatio(E621Post post) {
    if (post.preview.width > 0 && post.preview.height > 0) {
      return post.preview.width / post.preview.height;
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
    if (post.tags.any((tag) => tag.contains('story') || tag.contains('novel'))) {
      return ContentType.novel;
    }
    return ContentType.illustration;
  }
}
