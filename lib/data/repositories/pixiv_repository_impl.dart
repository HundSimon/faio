import '../../domain/models/content_item.dart';
import '../../domain/models/content_page.dart';
import '../../domain/repositories/pixiv_repository.dart';
import '../pixiv/models/pixiv_models.dart';
import '../pixiv/pixiv_service.dart';
import 'mappers/content_mapper.dart';

class PixivRepositoryImpl implements PixivRepository {
  PixivRepositoryImpl({required PixivService service}) : _service = service;

  final PixivService _service;

  @override
  Future<ContentPageResult> fetchIllustrations({
    required int page,
    int limit = 30,
  }) async {
    final offset = _offsetForPage(page, limit);
    final response = await _service.fetchIllustrations(
      offset: offset,
      limit: limit,
    );
    final items = response.items
        .map(ContentMapper.fromPixivIllust)
        .whereType<FaioContent>()
        .toList();
    final hasMore = response.hasNextPage || items.length >= limit;
    return ContentPageResult(
      items: items,
      page: page,
      hasMore: hasMore,
      nextOffset: response.nextOffset,
      nextUrl: response.nextUrl,
    );
  }

  @override
  Future<ContentPageResult> fetchManga({
    required int page,
    int limit = 30,
  }) async {
    final offset = _offsetForPage(page, limit);
    final response = await _service.fetchManga(offset: offset, limit: limit);
    final items = response.items
        .where((illust) => illust.type == PixivIllustType.manga)
        .map(ContentMapper.fromPixivIllust)
        .whereType<FaioContent>()
        .toList();
    final hasMore = response.hasNextPage || items.length >= limit;
    return ContentPageResult(
      items: items,
      page: page,
      hasMore: hasMore,
      nextOffset: response.nextOffset,
      nextUrl: response.nextUrl,
    );
  }

  @override
  Future<ContentPageResult> fetchNovels({
    required int page,
    int limit = 30,
  }) async {
    final offset = _offsetForPage(page, limit);
    final response = await _service.fetchNovels(offset: offset, limit: limit);
    final items = response.items
        .map(ContentMapper.fromPixivNovel)
        .whereType<FaioContent>()
        .toList();
    final hasMore = response.hasNextPage || items.length >= limit;
    return ContentPageResult(
      items: items,
      page: page,
      hasMore: hasMore,
      nextOffset: response.nextOffset,
      nextUrl: response.nextUrl,
    );
  }

  @override
  Future<FaioContent?> fetchIllustrationDetail(int illustId) async {
    final illust = await _service.fetchIllustrationDetail(illustId);
    if (illust == null) {
      return null;
    }
    return ContentMapper.fromPixivIllust(illust);
  }

  @override
  Future<FaioContent?> fetchNovelDetail(int novelId) async {
    final novel = await _service.fetchNovelDetail(novelId);
    if (novel == null) {
      return null;
    }
    return ContentMapper.fromPixivNovel(novel);
  }

  int _offsetForPage(int page, int limit) {
    final normalizedPage = page <= 0 ? 1 : page;
    return (normalizedPage - 1) * limit;
  }
}
