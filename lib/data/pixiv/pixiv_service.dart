import 'models/pixiv_models.dart';

/// Contract for interacting with Pixiv APIs.
abstract interface class PixivService {
  Future<PixivPage<PixivIllust>> fetchIllustrations({
    int offset = 0,
    int limit = 30,
  });

  Future<PixivPage<PixivIllust>> fetchManga({int offset = 0, int limit = 30});

  Future<PixivPage<PixivNovel>> fetchNovels({int offset = 0, int limit = 30});

  Future<PixivPage<PixivIllust>> searchIllustrations({
    required String query,
    int offset = 0,
    int limit = 30,
  });

  Future<PixivPage<PixivNovel>> searchNovels({
    required String query,
    int offset = 0,
    int limit = 30,
  });

  Future<PixivIllust?> fetchIllustrationDetail(int illustId);

  Future<PixivNovel?> fetchNovelDetail(int novelId);
}
