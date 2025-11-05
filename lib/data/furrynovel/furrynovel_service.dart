import 'package:dio/dio.dart';

import 'models/furry_novel_models.dart';

class FurryNovelService {
  FurryNovelService({
    Dio? dio,
  }) : _dio = dio ?? Dio(_defaultOptions);

  static final BaseOptions _defaultOptions = BaseOptions(
    baseUrl: 'https://api.furrynovel.ink',
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    responseType: ResponseType.json,
    headers: {
      'Referer': 'https://furrynovel.ink/',
      'Accept': 'application/json',
    },
  );

  final Dio _dio;

  Future<FurryNovelPage> fetchLatestNovels({
    int page = 1,
    int limit = 30,
  }) async {
    final safePage = page <= 0 ? 1 : page;
    final queryParameters = <String, dynamic>{'page': safePage};

    final response = await _dio.get<dynamic>(
      '/pixiv/novels/recent/cache',
      queryParameters: queryParameters,
    );
    return FurryNovelPage.fromResponse(
      response.data,
      page: safePage,
      pageSizeHint: limit,
    );
  }

  Future<FurryNovel?> fetchNovel(int id) async {
    if (id <= 0) {
      return null;
    }
    final response = await _dio.get<dynamic>(
      '/pixiv/novel/$id/cache',
    );
    return FurryNovelPage.parseNovel(response.data);
  }
}
