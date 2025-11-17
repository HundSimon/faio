import '../../domain/models/content_item.dart';
import '../../domain/models/content_page.dart';
import '../../domain/models/novel_detail.dart';
import '../../domain/repositories/pixiv_repository.dart';
import '../../domain/services/tag_filter.dart';
import '../furrynovel/furrynovel_service.dart';
import '../pixiv/models/pixiv_models.dart';
import '../pixiv/pixiv_service.dart';
import 'mappers/content_mapper.dart';
import 'mappers/novel_mapper.dart';

class PixivRepositoryImpl implements PixivRepository {
  PixivRepositoryImpl({
    required PixivService service,
    required FurryNovelService furryNovelService,
    required TagFilter Function() tagFilterResolver,
  }) : _service = service,
       _furryNovelService = furryNovelService,
       _tagFilterResolver = tagFilterResolver;

  final PixivService _service;
  final FurryNovelService _furryNovelService;
  final TagFilter Function() _tagFilterResolver;
  final Map<int, int> _novelLikeCountCache = {};

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
    final rawItems = response.items
        .map(ContentMapper.fromPixivIllust)
        .whereType<FaioContent>()
        .toList();
    final items = _filterItems(rawItems);
    final hasMore = response.hasNextPage || rawItems.length >= limit;
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
    final rawItems = response.items
        .where((illust) => illust.type == PixivIllustType.manga)
        .map(ContentMapper.fromPixivIllust)
        .whereType<FaioContent>()
        .toList();
    final items = _filterItems(rawItems);
    final hasMore = response.hasNextPage || rawItems.length >= limit;
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

    for (final novel in result.items) {
      _novelLikeCountCache[novel.id] = novel.pixivLikeCount;
    }

    final rawItems = result.items
        .map(ContentMapper.fromFurryNovel)
        .whereType<FaioContent>()
        .toList();
    final items = _filterItems(rawItems);
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
  Future<List<FaioContent>> searchIllustrations({
    required String query,
    int limit = 30,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const [];
    }
    final response = await _service.searchIllustrations(
      query: trimmed,
      limit: limit,
    );
    final rawItems = response.items
        .map(ContentMapper.fromPixivIllust)
        .whereType<FaioContent>()
        .toList();
    final items = _filterItems(rawItems)
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    if (items.length > limit) {
      return items.sublist(0, limit);
    }
    return items;
  }

  @override
  Future<List<FaioContent>> searchNovels({
    required String query,
    int limit = 30,
    bool includePixiv = true,
    bool includeFurryNovel = true,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty || (!includePixiv && !includeFurryNovel)) {
      return const [];
    }

    final futures = <Future<List<FaioContent>>>[];
    if (includePixiv) {
      futures.add(_searchPixivNovels(trimmed, limit));
    }
    if (includeFurryNovel) {
      futures.add(_searchFurryNovels(trimmed, limit));
    }
    if (futures.isEmpty) {
      return const [];
    }

    final results = await Future.wait(futures);
    final combined = results.expand((list) => list).toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    if (combined.length > limit) {
      return combined.sublist(0, limit);
    }
    return combined;
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
      final cachedLikeCount =
          _novelLikeCountCache[furryNovel.id] ?? furryNovel.pixivLikeCount;
      _novelLikeCountCache[furryNovel.id] = cachedLikeCount;
      return NovelMapper.fromFurryNovel(
        furryNovel,
        likeCountOverride: cachedLikeCount,
      );
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

  Future<List<FaioContent>> _searchPixivNovels(String query, int limit) async {
    final response = await _service.searchNovels(query: query, limit: limit);
    final rawItems = response.items
        .map(ContentMapper.fromPixivNovel)
        .whereType<FaioContent>()
        .toList();
    return _filterItems(rawItems);
  }

  Future<List<FaioContent>> _searchFurryNovels(String query, int limit) async {
    final page = await _furryNovelService.searchNovels(
      keyword: query,
      limit: limit,
    );
    final rawItems = page.items
        .map(ContentMapper.fromFurryNovel)
        .whereType<FaioContent>()
        .toList();
    return _filterItems(rawItems);
  }

  int _offsetForPage(int page, int limit) {
    final normalizedPage = page <= 0 ? 1 : page;
    return (normalizedPage - 1) * limit;
  }

  List<FaioContent> _filterItems(List<FaioContent> items) {
    final filter = _tagFilterResolver();
    if (filter.isInactive) {
      return items;
    }
    return items.where(filter.allows).toList();
  }
}
