import 'dart:convert';

import 'package:rhttp/rhttp.dart';

import 'models/furry_novel_models.dart';

class FurryNovelService {
  FurryNovelService({RhttpClient? client})
    : _client = client ?? RhttpClient.createSync(settings: _defaultSettings);

  static const _baseUrl = 'https://api.furrynovel.ink';
  static final ClientSettings _defaultSettings = ClientSettings(
    timeoutSettings: const TimeoutSettings(
      connectTimeout: Duration(seconds: 15),
      timeout: Duration(seconds: 15),
    ),
  );
  static const HttpHeaders _defaultHeaders = HttpHeaders.rawMap({
    'Referer': 'https://furrynovel.ink/',
    'Accept': 'application/json',
  });

  final RhttpClient _client;

  Future<FurryNovelPage> fetchLatestNovels({
    int page = 1,
    int limit = 30,
  }) async {
    final safePage = page <= 0 ? 1 : page;
    final queryParameters = <String, dynamic>{'page': safePage};

    final response = await _getJson(
      '/pixiv/novels/recent/cache',
      queryParameters: queryParameters,
    );
    return FurryNovelPage.fromResponse(
      response,
      page: safePage,
      pageSizeHint: limit,
    );
  }

  Future<FurryNovel?> fetchNovel(int id) async {
    if (id <= 0) {
      return null;
    }
    final response = await _getJson('/pixiv/novel/$id/cache');
    return FurryNovelPage.parseNovel(response);
  }

  Future<FurryNovelSeriesDetail?> fetchSeries(int id) async {
    if (id <= 0) {
      return null;
    }
    final response = await _getJson('/pixiv/series/$id/cache');
    final data = response;
    if (data is Map<String, dynamic>) {
      return FurryNovelSeriesDetail.fromJson(data);
    }
    return null;
  }

  Future<dynamic> _getJson(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _client.requestText(
      method: HttpMethod.get,
      url: '$_baseUrl$path',
      query: _normalizeQuery(queryParameters),
      headers: _defaultHeaders,
    );
    return _decodeJson(response.body);
  }

  Map<String, String>? _normalizeQuery(Map<String, dynamic>? input) {
    if (input == null || input.isEmpty) {
      return null;
    }
    final normalized = <String, String>{};
    input.forEach((key, value) {
      if (value == null) {
        return;
      }
      normalized[key] = value.toString();
    });
    return normalized.isEmpty ? null : normalized;
  }

  dynamic _decodeJson(String body) {
    if (body.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }
}
