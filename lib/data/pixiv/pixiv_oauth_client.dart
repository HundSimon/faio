import 'package:dio/dio.dart';

import 'pixiv_credentials.dart';

/// Handles communicating with Pixiv's OAuth endpoints.
class PixivOAuthClient {
  PixivOAuthClient({Dio? dio}) : _dio = dio ?? Dio(_defaultOptions);

  static final BaseOptions _defaultOptions = BaseOptions(
    baseUrl: 'https://oauth.secure.pixiv.net',
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
  );

  static const _clientId = 'MOBrBDS8blbauoSck0ZfDbtuzpyT';
  static const _clientSecret = 'lsACyCD94FhDUtqbr1PW4eB6YQWA';
  static const _redirectUri =
      'https://app-api.pixiv.net/web/v1/users/auth/pixiv/callback';

  final Dio _dio;

  Future<PixivCredentials> refreshToken(String refreshToken) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/token',
      data: {
        'client_id': _clientId,
        'client_secret': _clientSecret,
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'include_policy': 'true',
      },
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );

    return _parseCredentials(response.data ?? const {}, refreshToken);
  }

  Future<PixivCredentials> authorize({
    required String code,
    required String codeVerifier,
    required String userAgent,
    required String appVersion,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/token',
      data: {
        'client_id': _clientId,
        'client_secret': _clientSecret,
        'code': code,
        'code_verifier': codeVerifier,
        'grant_type': 'authorization_code',
        'include_policy': 'true',
        'redirect_uri': _redirectUri,
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {
          'User-Agent': userAgent,
          'App-Version': appVersion,
          'Accept-Language': 'zh-CN',
          'App-OS': 'android',
          'App-OS-Version': '11',
        },
      ),
    );

    return _parseCredentials(response.data ?? const {}, null);
  }

  PixivCredentials _parseCredentials(
    Map<String, dynamic> data,
    String? fallbackRefreshToken,
  ) {
    final accessToken = data['access_token'] as String? ?? '';
    final refreshToken =
        data['refresh_token'] as String? ?? fallbackRefreshToken ?? '';
    if (refreshToken.isEmpty) {
      throw StateError('Pixiv OAuth response missing refresh_token');
    }
    final expiresIn = data['expires_in'] as int? ?? 0;
    final tokenType = data['token_type'] as String? ?? 'Bearer';
    final scopeRaw = data['scope'];
    final scope = switch (scopeRaw) {
      List list => list.whereType<String>().toList(),
      String text when text.isNotEmpty => text.split(' '),
      _ => <String>[],
    };

    final expiresAt = DateTime.now().add(
      Duration(seconds: expiresIn.clamp(0, 86400 * 7)),
    );

    return PixivCredentials(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
      tokenType: tokenType,
      scope: scope,
    );
  }
}
