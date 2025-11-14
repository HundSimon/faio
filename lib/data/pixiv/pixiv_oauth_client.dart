import 'dart:convert';

import 'package:rhttp/rhttp.dart';

import 'pixiv_credentials.dart';

/// Handles communicating with Pixiv's OAuth endpoints.
class PixivOAuthClient {
  PixivOAuthClient({required RhttpClient client, required String appVersion})
    : _client = client,
      _appVersion = appVersion;

  static const _clientId = 'MOBrBDS8blbauoSck0ZfDbtuzpyT';
  static const _clientSecret = 'lsACyCD94FhDUtGTXi3QzcFE2uU1hqtDaKeqrdwj';
  static const _redirectUri =
      'https://app-api.pixiv.net/web/v1/users/auth/pixiv/callback';
  static const _baseUrl = 'https://oauth.secure.pixiv.net';

  final RhttpClient _client;
  final String _appVersion;

  Future<PixivCredentials> refreshToken(String refreshToken) async {
    final response = await _client.requestText(
      method: HttpMethod.post,
      url: '$_baseUrl/auth/token',
      body: HttpBody.form({
        'client_id': _clientId,
        'client_secret': _clientSecret,
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'include_policy': 'true',
      }),
      headers: _buildHeaders(
        userAgent: _defaultUserAgent,
        appVersion: _appVersion,
      ),
    );

    return _parseCredentials(_decodeJson(response.body), refreshToken);
  }

  Future<PixivCredentials> authorize({
    required String code,
    required String codeVerifier,
    required String userAgent,
    required String appVersion,
  }) async {
    final response = await _client.requestText(
      method: HttpMethod.post,
      url: '$_baseUrl/auth/token',
      body: HttpBody.form({
        'client_id': _clientId,
        'client_secret': _clientSecret,
        'code': code,
        'code_verifier': codeVerifier,
        'grant_type': 'authorization_code',
        'include_policy': 'true',
        'redirect_uri': _redirectUri,
      }),
      headers: _buildHeaders(userAgent: userAgent, appVersion: appVersion),
    );

    return _parseCredentials(_decodeJson(response.body), null);
  }

  Map<String, dynamic> _decodeJson(String body) {
    if (body.isEmpty) {
      return const {};
    }
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return const {};
  }

  HttpHeaders _buildHeaders({
    required String userAgent,
    required String appVersion,
  }) {
    return HttpHeaders.rawMap({
      'User-Agent': userAgent,
      'App-Version': appVersion,
      'Accept-Language': 'zh-CN',
      'App-OS': 'android',
      'App-OS-Version': '11',
      'Referer': 'https://app-api.pixiv.net/',
    });
  }

  String get _defaultUserAgent =>
      'PixivAndroidApp/$_appVersion (Android 11; Pixel 5)';

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
