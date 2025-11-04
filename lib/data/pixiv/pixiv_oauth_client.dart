import 'package:dio/dio.dart';

import 'pixiv_credentials.dart';

/// Handles communicating with Pixiv's OAuth endpoints.
class PixivOAuthClient {
  PixivOAuthClient({Dio? dio}) : _dio = dio ?? Dio(_defaultOptions);

  static final BaseOptions _defaultOptions = BaseOptions(
    baseUrl: 'https://oauth.secure.pixiv.net',
    headers: const {
      'User-Agent': 'PixivAndroidApp/5.0.234 (Android 11; Pixel 5)',
      'Accept-Language': 'zh-CN',
      'App-OS': 'android',
      'App-OS-Version': '11',
      'App-Version': '5.0.234',
    },
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
  );

  static const _clientId = 'MOBrBDS8blbauoSck0ZfDbtuzpyT';
  static const _clientSecret = 'lsACyCD94FhDUtqbr1PW4eB6YQWA';

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

    final data = response.data ?? const {};
    final accessToken = data['access_token'] as String? ?? '';
    final newRefreshToken = data['refresh_token'] as String? ?? refreshToken;
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
      refreshToken: newRefreshToken,
      expiresAt: expiresAt,
      tokenType: tokenType,
      scope: scope,
    );
  }
}
