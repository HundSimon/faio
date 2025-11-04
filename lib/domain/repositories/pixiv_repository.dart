import '../models/content_page.dart';
import '../models/content_item.dart';

abstract interface class PixivRepository {
  Future<ContentPageResult> fetchIllustrations({
    required int page,
    int limit = 30,
  });

  Future<ContentPageResult> fetchManga({required int page, int limit = 30});

  Future<ContentPageResult> fetchNovels({required int page, int limit = 30});

  Future<FaioContent?> fetchIllustrationDetail(int illustId);

  Future<FaioContent?> fetchNovelDetail(int novelId);
}
