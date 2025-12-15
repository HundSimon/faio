import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:rhttp/rhttp.dart';

import 'pixiv_credentials.dart';
import 'pixiv_oauth_client.dart';

class PixivLoginSession {
  const PixivLoginSession({
    required this.loginUri,
    required this.codeVerifier,
    required this.userAgent,
    required this.appVersion,
  });

  final Uri loginUri;
  final String codeVerifier;
  final String userAgent;
  final String appVersion;

  String get loginUrl => loginUri.toString();
}

class PixivAuthFlow {
  PixivAuthFlow({
    required RhttpClient client,
    required PixivOAuthClient oauthClient,
    required String appVersion,
    void Function(String version)? onVersionDetected,
  }) : _client = client,
       _oauthClient = oauthClient,
       _appVersion = appVersion,
       _onVersionDetected = onVersionDetected;

  final RhttpClient _client;
  final PixivOAuthClient _oauthClient;
  final String _appVersion;
  final void Function(String version)? _onVersionDetected;

  static const _loginPath = 'https://app-api.pixiv.net/web/v1/login';
  static const _applicationInfoUrl =
      'https://app-api.pixiv.net/v1/application-info/android';
  static const redirectUri =
      'https://app-api.pixiv.net/web/v1/users/auth/pixiv/callback';
  static const _defaultVersion = '5.0.234';

  static final Random _random = Random.secure();
  static const _codeChars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

  Future<PixivLoginSession> createSession() async {
    final version = await _fetchLatestVersion();
    _onVersionDetected?.call(version);

    final codeVerifier = _generateCodeVerifier();
    final codeChallenge = _generateCodeChallenge(codeVerifier);
    final loginUri = Uri.parse(_loginPath).replace(
      queryParameters: {
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
        'client': 'pixiv-android',
      },
    );

    final userAgent = 'PixivAndroidApp/$version (Android 11; Pixel 5)';

    return PixivLoginSession(
      loginUri: loginUri,
      codeVerifier: codeVerifier,
      userAgent: userAgent,
      appVersion: version,
    );
  }

  Future<PixivCredentials> exchange({
    required String code,
    required PixivLoginSession session,
  }) {
    return _oauthClient.authorize(
      code: code,
      codeVerifier: session.codeVerifier,
      userAgent: session.userAgent,
      appVersion: session.appVersion,
    );
  }

  Future<String> _fetchLatestVersion() async {
    try {
      final response = await _client.requestText(
        method: HttpMethod.get,
        url: _applicationInfoUrl,
        headers: HttpHeaders.rawMap(_buildBaseHeaders()),
      );
      final data = jsonDecode(response.body);
      if (data == null) {
        return _defaultVersion;
      }
      final info = data['application_info'];
      if (info is Map<String, dynamic>) {
        final version = info['latest_version'];
        if (version is String && version.trim().isNotEmpty) {
          return version.trim();
        }
      }
      return _defaultVersion;
    } on RhttpException {
      return _defaultVersion;
    }
  }

  Map<String, String> _buildBaseHeaders() {
    return {
      'User-Agent': 'PixivAndroidApp/$_appVersion (Android 11; Pixel 5)',
      'Accept-Language': 'zh-CN',
      'App-OS': 'android',
      'App-OS-Version': '11',
      'App-Version': _appVersion,
      'Referer': 'https://app-api.pixiv.net/',
    };
  }

  String _generateCodeVerifier() {
    final length = 64;
    final buffer = StringBuffer();
    for (var i = 0; i < length; i += 1) {
      final index = _random.nextInt(_codeChars.length);
      buffer.write(_codeChars[index]);
    }
    return buffer.toString();
  }

  String _generateCodeChallenge(String verifier) {
    final bytes = verifier.codeUnits;
    final digest = sha256.convert(bytes);
    final base64 = base64UrlEncode(digest.bytes);
    return base64.replaceAll('=', '');
  }
}
