import '../models/content_item.dart';
import '../models/content_page.dart';
import '../models/novel_detail.dart';

abstract interface class PixivRepository {
  Future<ContentPageResult> fetchIllustrations({
    required int page,
    int limit = 30,
  });

  Future<ContentPageResult> fetchManga({required int page, int limit = 30});

  Future<ContentPageResult> fetchNovels({required int page, int limit = 30});

  Future<List<FaioContent>> searchIllustrations({
    required String query,
    int limit = 30,
  });

  Future<List<FaioContent>> searchNovels({
    required String query,
    int limit = 30,
    bool includePixiv = true,
    bool includeFurryNovel = true,
  });

  Future<FaioContent?> fetchIllustrationDetail(int illustId);

  Future<NovelDetail?> fetchNovelDetail(int novelId);

  Future<NovelSeriesDetail?> fetchNovelSeries(int seriesId);
}
