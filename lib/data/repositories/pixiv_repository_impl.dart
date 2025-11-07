import '../../domain/models/content_item.dart';
import '../../domain/models/content_page.dart';
import '../../domain/models/novel_detail.dart';
import '../../domain/repositories/pixiv_repository.dart';
import '../furrynovel/furrynovel_service.dart';
import '../pixiv/models/pixiv_models.dart';
import '../pixiv/pixiv_service.dart';
import 'mappers/content_mapper.dart';
import 'mappers/novel_mapper.dart';

class PixivRepositoryImpl implements PixivRepository {
  PixivRepositoryImpl({
    required PixivService service,
    required FurryNovelService furryNovelService,
  })  : _service = service,
        _furryNovelService = furryNovelService;

  final PixivService _service;
  final FurryNovelService _furryNovelService;

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
    final result = await _furryNovelService.fetchLatestNovels(
      page: page,
      limit: limit,
    );

    final items = result.items
        .map(ContentMapper.fromFurryNovel)
        .whereType<FaioContent>()
        .toList();
    final hasMore = result.hasMore;
    return ContentPageResult(
      items: items,
      page: page,
      hasMore: hasMore,
      nextOffset: hasMore ? (page + 1) * limit : null,
      nextUrl: null,
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
  Future<NovelDetail?> fetchNovelDetail(int novelId) async {
    final furryNovel = await _furryNovelService.fetchNovel(novelId);
    if (furryNovel != null) {
      return NovelMapper.fromFurryNovel(furryNovel);
    }

    final pixivNovel = await _service.fetchNovelDetail(novelId);
    if (pixivNovel == null) {
      return null;
    }
    return NovelMapper.fromPixivNovel(pixivNovel);
  }

  @override
  Future<NovelSeriesDetail?> fetchNovelSeries(int seriesId) async {
    final series = await _furryNovelService.fetchSeries(seriesId);
    return NovelMapper.fromFurrySeries(series);
  }

  int _offsetForPage(int page, int limit) {
    final normalizedPage = page <= 0 ? 1 : page;
    return (normalizedPage - 1) * limit;
  }
}
