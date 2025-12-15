import 'dart:async';
import 'dart:convert';

import 'package:rhttp/rhttp.dart';

import '../../core/network/rate_limiter.dart';
import 'models/pixiv_models.dart';
import 'pixiv_credentials.dart';
import 'pixiv_oauth_client.dart';
import 'pixiv_service.dart';

class PixivAuthenticationRequiredException implements Exception {
  const PixivAuthenticationRequiredException();

  @override
  String toString() =>
      'PixivAuthenticationRequiredException: Pixiv credentials are missing.';
}

/// Talks to Pixiv's public API using OAuth tokens obtained on-device.
class PixivHttpService implements PixivService {
  PixivHttpService({
    required RhttpClient client,
    required PixivOAuthClient oauthClient,
    required RateLimiter rateLimiter,
    required String appVersion,
    PixivCredentials? credentials,
    void Function(PixivCredentials credentials)? onCredentialsRefreshed,
  }) : _client = client,
       _oauthClient = oauthClient,
       _rateLimiter = rateLimiter,
       _appVersion = appVersion,
       _credentials = credentials,
       _onCredentialsRefreshed = onCredentialsRefreshed;

  static const _baseUrl = 'https://app-api.pixiv.net';
  static final RegExp _webviewNovelRegex = RegExp(
    r'novel:\s*(\{.+?\}),\s*isOwnWork',
    dotAll: true,
  );

  final RhttpClient _client;
  final PixivOAuthClient _oauthClient;
  final RateLimiter _rateLimiter;
  final String _appVersion;
  PixivCredentials? _credentials;
  Future<PixivCredentials>? _refreshingCredentials;
  final void Function(PixivCredentials credentials)? _onCredentialsRefreshed;

  @override
  Future<PixivPage<PixivIllust>> fetchIllustrations({
    int offset = 0,
    int limit = 30,
  }) async {
    final response = await _getJson(
      path: '/v2/illust/follow',
      queryParameters: {'restrict': 'all', 'offset': offset},
    );
    final illusts = parsePixivIllustList(response['illusts']);
    final nextUrl = response['next_url'] as String?;
    return PixivPage<PixivIllust>(
      items: illusts.take(limit).toList(),
      nextUrl: nextUrl,
    );
  }

  @override
  Future<PixivPage<PixivIllust>> fetchManga({
    int offset = 0,
    int limit = 30,
  }) async {
    final response = await _getJson(
      path: '/v1/manga/recommended',
      queryParameters: {'filter': 'for_android', 'offset': offset},
    );
    final manga = parsePixivIllustList(response['manga']);
    final nextUrl = response['next_url'] as String?;
    return PixivPage<PixivIllust>(
      items: manga.take(limit).toList(),
      nextUrl: nextUrl,
    );
  }

  @override
  Future<PixivPage<PixivNovel>> fetchNovels({
    int offset = 0,
    int limit = 30,
  }) async {
    final response = await _getJson(
      path: '/v1/novel/recommended',
      queryParameters: {
        'filter': 'for_android',
        'include_ranking_label': 'true',
        'include_privacy_policy': 'true',
        'include_translated_tag_results': 'true',
        'limit': limit,
        'offset': offset,
      },
    );
    final novels = parsePixivNovelList(response['novels']);
    final responseNextUrl = response['next_url'] as String?;
    return PixivPage<PixivNovel>(
      items: novels.take(limit).toList(),
      nextUrl: responseNextUrl,
    );
  }

  @override
  Future<PixivPage<PixivIllust>> searchIllustrations({
    required String query,
    int offset = 0,
    int limit = 30,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const PixivPage<PixivIllust>(items: []);
    }
    final response = await _getJson(
      path: '/v1/search/illust',
      queryParameters: {
        'word': trimmed,
        'search_target': 'partial_match_for_tags',
        'sort': 'date_desc',
        'offset': offset,
        'filter': 'for_android',
      },
    );
    final illusts = parsePixivIllustList(response['illusts']);
    final nextUrl = response['next_url'] as String?;
    return PixivPage<PixivIllust>(
      items: illusts.take(limit).toList(),
      nextUrl: nextUrl,
    );
  }

  @override
  Future<PixivPage<PixivNovel>> searchNovels({
    required String query,
    int offset = 0,
    int limit = 30,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const PixivPage<PixivNovel>(items: []);
    }
    final response = await _getJson(
      path: '/v1/search/novel',
      queryParameters: {
        'word': trimmed,
        'search_target': 'partial_match_for_tags',
        'sort': 'date_desc',
        'offset': offset,
        'filter': 'for_android',
        'include_translated_tag_results': 'true',
      },
    );
    final novels = parsePixivNovelList(response['novels']);
    final nextUrl = response['next_url'] as String?;
    return PixivPage<PixivNovel>(
      items: novels.take(limit).toList(),
      nextUrl: nextUrl,
    );
  }

  @override
  Future<PixivIllust?> fetchIllustrationDetail(int illustId) async {
    final response = await _getJson(
      path: '/v1/illust/detail',
      queryParameters: {'illust_id': illustId},
    );
    final illust = response['illust'];
    if (illust is Map<String, dynamic>) {
      return PixivIllust.fromJson(illust);
    }
    return null;
  }

  @override
  Future<PixivNovel?> fetchNovelDetail(int novelId) async {
    final response = await _getJson(
      path: '/v2/novel/detail',
      queryParameters: {'novel_id': novelId},
    );
    final novel = response['novel'];
    if (novel is Map<String, dynamic>) {
      var parsed = PixivNovel.fromJson(novel);
      if (parsed.text == null || parsed.text!.trim().isEmpty) {
        try {
          final text = await fetchNovelText(novelId);
          if (text != null && text.trim().isNotEmpty) {
            parsed = parsed.copyWith(text: text);
          }
        } on PixivAuthenticationRequiredException {
          rethrow;
        } on RhttpStatusCodeException catch (_) {
          // Ignore fallback failures (e.g. 404) and keep existing data.
        }
      }
      return parsed;
    }
    return null;
  }

  @override
  Future<String?> fetchNovelText(int novelId) async {
    if (novelId <= 0) {
      return null;
    }

    try {
      final html = await _getText(
        path: '/webview/v2/novel',
        queryParameters: {'id': novelId, 'viewer_version': '20221031_ai'},
      );
      final text = _parseNovelTextFromHtml(html);
      if (text != null && text.trim().isNotEmpty) {
        return text;
      }
    } on PixivAuthenticationRequiredException {
      rethrow;
    } on RhttpStatusCodeException {
      // Fall back to the legacy text endpoint below.
    } catch (_) {
      // Ignore parsing/network errors and try the legacy endpoint next.
    }

    return _fetchLegacyNovelText(novelId);
  }

  String? _parseNovelTextFromHtml(String? html) {
    if (html == null || html.isEmpty) {
      return null;
    }
    final match = _webviewNovelRegex.firstMatch(html);
    if (match == null) {
      return null;
    }
    final jsonPayload = match.group(1);
    if (jsonPayload == null || jsonPayload.isEmpty) {
      return null;
    }
    try {
      final dynamic decoded = jsonDecode(jsonPayload);
      final text = decoded is Map<String, dynamic> ? decoded['text'] : null;
      if (text is String && text.trim().isNotEmpty) {
        return text;
      }
    } catch (_) {
      // Ignore malformed payloads and fall back to legacy logic.
    }
    return null;
  }

  Future<String?> _fetchLegacyNovelText(int novelId) async {
    final response = await _getJson(
      path: '/v1/novel/text',
      queryParameters: {'novel_id': novelId},
    );
    final text = response['novel_text'];
    if (text is String && text.isNotEmpty) {
      return text;
    }
    return null;
  }

  Future<Map<String, dynamic>> _getJson({
    String? path,
    Map<String, dynamic>? queryParameters,
    Uri? uri,
  }) async {
    final credentials = await _ensureCredentials();
    await _rateLimiter.acquire();

    try {
      final response = await _performRequest(
        credentials: credentials,
        path: path,
        queryParameters: queryParameters,
        uri: uri,
      );
      return _decodeJson(response.body);
    } on RhttpStatusCodeException catch (error) {
      if (_isAuthFailure(error.statusCode)) {
        final refreshed = await _refreshCredentials(credentials);
        final retryResponse = await _performRequest(
          credentials: refreshed,
          path: path,
          queryParameters: queryParameters,
          uri: uri,
        );
        return _decodeJson(retryResponse.body);
      }
      rethrow;
    }
  }

  Future<String> _getText({
    String? path,
    Map<String, dynamic>? queryParameters,
    Uri? uri,
  }) async {
    final credentials = await _ensureCredentials();
    await _rateLimiter.acquire();

    try {
      final response = await _performRequest(
        credentials: credentials,
        path: path,
        queryParameters: queryParameters,
        uri: uri,
      );
      return response.body;
    } on RhttpStatusCodeException catch (error) {
      if (_isAuthFailure(error.statusCode)) {
        final refreshed = await _refreshCredentials(credentials);
        final retryResponse = await _performRequest(
          credentials: refreshed,
          path: path,
          queryParameters: queryParameters,
          uri: uri,
        );
        return retryResponse.body;
      }
      rethrow;
    }
  }

  Future<HttpTextResponse> _performRequest({
    required PixivCredentials credentials,
    String? path,
    Map<String, dynamic>? queryParameters,
    Uri? uri,
  }) {
    final headers = HttpHeaders.rawMap({
      ..._buildBaseHeaders(includeAppHeaders: true),
      'Authorization': 'Bearer ${credentials.accessToken}',
    });
    final url = uri?.toString() ?? _resolveUrl(path);
    return _client.requestText(
      method: HttpMethod.get,
      url: url,
      query: uri == null ? _normalizeQuery(queryParameters) : null,
      headers: headers,
    );
  }

  Map<String, String>? _normalizeQuery(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final normalized = <String, String>{};
    raw.forEach((key, value) {
      if (value == null) {
        return;
      }
      normalized[key] = value.toString();
    });
    return normalized.isEmpty ? null : normalized;
  }

  String _resolveUrl(String? path) {
    if (path == null || path.isEmpty) {
      throw ArgumentError('Either a path or uri must be provided.');
    }
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    return '$_baseUrl$path';
  }

  Map<String, dynamic> _decodeJson(String body) {
    if (body.isEmpty) {
      return const {};
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Ignore parsing failures, return empty map for consistency.
    }
    return const {};
  }

  bool _isAuthFailure(int statusCode) => statusCode == 401 || statusCode == 403;

  Future<PixivCredentials> _ensureCredentials() async {
    final current = _credentials;
    if (current == null || !current.isValid) {
      throw const PixivAuthenticationRequiredException();
    }
    if (!current.isAccessTokenExpired) {
      return current;
    }
    return _refreshCredentials(current);
  }

  Future<PixivCredentials> _refreshCredentials(PixivCredentials current) async {
    if (_refreshingCredentials != null) {
      return _refreshingCredentials!;
    }

    final completer = Completer<PixivCredentials>();
    _refreshingCredentials = completer.future;

    try {
      final refreshed = await _oauthClient.refreshToken(current.refreshToken);
      _credentials = refreshed;
      _onCredentialsRefreshed?.call(refreshed);
      completer.complete(refreshed);
      return refreshed;
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
      rethrow;
    } finally {
      _refreshingCredentials = null;
    }
  }

  Map<String, String> _buildBaseHeaders({bool includeAppHeaders = true}) {
    final headers = <String, String>{
      'Accept-Language': 'zh-CN',
      'Referer': 'https://app-api.pixiv.net/',
    };
    if (includeAppHeaders) {
      final userAgent = 'PixivAndroidApp/$_appVersion (Android 11; Pixel 5)';
      headers.addAll({
        'User-Agent': userAgent,
        'App-OS': 'android',
        'App-OS-Version': '11',
        'App-Version': _appVersion,
      });
    }
    return headers;
  }
}
