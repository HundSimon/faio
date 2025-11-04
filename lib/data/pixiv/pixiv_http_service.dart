import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

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
    required Dio dio,
    required PixivOAuthClient oauthClient,
    required RateLimiter rateLimiter,
    required String appVersion,
    PixivCredentials? credentials,
    void Function(PixivCredentials credentials)? onCredentialsRefreshed,
  }) : _dio = dio,
       _oauthClient = oauthClient,
       _rateLimiter = rateLimiter,
       _appVersion = appVersion,
       _credentials = credentials,
       _onCredentialsRefreshed = onCredentialsRefreshed;

  final Dio _dio;
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
      path: '/v1/illust/recommended',
      queryParameters: {
        'filter': 'for_android',
        'include_ranking_label': 'true',
        'include_privacy_policy': 'true',
        'offset': offset,
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
      queryParameters: {'offset': offset},
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
      return PixivNovel.fromJson(novel);
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

    Response<Map<String, dynamic>> response;
    try {
      final headers = {
        ..._buildBaseHeaders(includeAppHeaders: false),
        'Authorization': 'Bearer ${credentials.accessToken}',
      };
      if (uri != null) {
        response = await _dio.getUri<Map<String, dynamic>>(
          uri,
          options: Options(headers: headers),
        );
      } else {
        response = await _dio.get<Map<String, dynamic>>(
          path!,
          queryParameters: queryParameters,
          options: Options(headers: headers),
        );
      }
    } on DioException catch (error) {
      if (_isAuthFailure(error)) {
        final refreshed = await _refreshCredentials(credentials);
        final retryHeaders = {
          ..._buildBaseHeaders(includeAppHeaders: false),
          'Authorization': 'Bearer ${refreshed.accessToken}',
        };
        if (uri != null) {
          response = await _dio.getUri<Map<String, dynamic>>(
            uri,
            options: Options(headers: retryHeaders),
          );
        } else {
          response = await _dio.get<Map<String, dynamic>>(
            path!,
            queryParameters: queryParameters,
            options: Options(headers: retryHeaders),
          );
        }
      } else {
        rethrow;
      }
    }

    return response.data ?? const {};
  }

  bool _isAuthFailure(DioException error) {
    final status = error.response?.statusCode ?? 0;
    return status == 401 || status == 403;
  }

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
