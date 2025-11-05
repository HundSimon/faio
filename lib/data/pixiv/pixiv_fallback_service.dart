import 'models/pixiv_models.dart';
import 'pixiv_service.dart';

/// Wraps a primary Pixiv service with a fallback implementation.
class PixivFallbackService implements PixivService {
  PixivFallbackService({
    required PixivService primary,
    required PixivService fallback,
  }) : _primary = primary,
       _fallback = fallback;

  final PixivService _primary;
  final PixivService _fallback;

  @override
  Future<PixivPage<PixivIllust>> fetchIllustrations({
    int offset = 0,
    int limit = 30,
  }) async {
    try {
      return await _primary.fetchIllustrations(offset: offset, limit: limit);
    } catch (_) {
      return _fallback.fetchIllustrations(offset: offset, limit: limit);
    }
  }

  @override
  Future<PixivPage<PixivIllust>> fetchManga({
    int offset = 0,
    int limit = 30,
  }) async {
    try {
      return await _primary.fetchManga(offset: offset, limit: limit);
    } catch (_) {
      return _fallback.fetchManga(offset: offset, limit: limit);
    }
  }

  @override
  Future<PixivPage<PixivNovel>> fetchNovels({
    int offset = 0,
    int limit = 30,
  }) async {
    try {
      return await _primary.fetchNovels(
        offset: offset,
        limit: limit,
      );
    } catch (_) {
      return _fallback.fetchNovels(
        offset: offset,
        limit: limit,
      );
    }
  }

  @override
  Future<PixivIllust?> fetchIllustrationDetail(int illustId) async {
    try {
      final result = await _primary.fetchIllustrationDetail(illustId);
      return result ?? await _fallback.fetchIllustrationDetail(illustId);
    } catch (_) {
      return _fallback.fetchIllustrationDetail(illustId);
    }
  }

  @override
  Future<PixivNovel?> fetchNovelDetail(int novelId) async {
    try {
      final result = await _primary.fetchNovelDetail(novelId);
      return result ?? await _fallback.fetchNovelDetail(novelId);
    } catch (_) {
      return _fallback.fetchNovelDetail(novelId);
    }
  }
}
