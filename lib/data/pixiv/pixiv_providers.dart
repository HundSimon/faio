import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/rate_limiter.dart';
import '../../domain/repositories/pixiv_repository.dart';
import '../repositories/pixiv_repository_impl.dart';
import 'pixiv_app_version.dart';
import 'pixiv_auth.dart';
import 'pixiv_auth_flow.dart';
import 'pixiv_fallback_service.dart';
import 'pixiv_http_service.dart';
import 'pixiv_mock_service.dart';
import 'pixiv_oauth_client.dart';
import 'pixiv_service.dart';

final pixivRateLimiterProvider = Provider<RateLimiter>((ref) {
  return RateLimiter(const Duration(milliseconds: 500));
}, name: 'pixivRateLimiterProvider');

final pixivAppVersionProvider =
    StateNotifierProvider<PixivAppVersionNotifier, String>((ref) {
      return PixivAppVersionNotifier();
    }, name: 'pixivAppVersionProvider');

final pixivOAuthClientProvider = Provider<PixivOAuthClient>((ref) {
  final version = ref.watch(pixivAppVersionProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://oauth.secure.pixiv.net',
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'User-Agent': 'PixivAndroidApp/$version (Android 11; Pixel 5)',
        'Accept-Language': 'zh-CN',
        'App-OS': 'android',
        'App-OS-Version': '11',
        'App-Version': version,
      },
    ),
  );
  return PixivOAuthClient(dio: dio);
}, name: 'pixivOAuthClientProvider');

final pixivDioProvider = Provider<Dio>((ref) {
  final version = ref.watch(pixivAppVersionProvider);
  final options = BaseOptions(
    baseUrl: 'https://app-api.pixiv.net',
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
    sendTimeout: const Duration(seconds: 20),
    headers: {
      'User-Agent': 'PixivAndroidApp/$version (Android 11; Pixel 5)',
      'App-OS': 'android',
      'App-OS-Version': '11',
      'App-Version': version,
      'Accept-Language': 'zh-CN',
    },
  );
  return Dio(options);
}, name: 'pixivDioProvider');

final pixivHttpServiceProvider = Provider<PixivService>((ref) {
  final dio = ref.watch(pixivDioProvider);
  final credentials = ref.watch(pixivAuthProvider);
  final rateLimiter = ref.watch(pixivRateLimiterProvider);
  final oauthClient = ref.watch(pixivOAuthClientProvider);
  final notifier = ref.read(pixivAuthProvider.notifier);
  final appVersion = ref.watch(pixivAppVersionProvider);
  return PixivHttpService(
    dio: dio,
    oauthClient: oauthClient,
    rateLimiter: rateLimiter,
    credentials: credentials,
    onCredentialsRefreshed: notifier.setCredentials,
    appVersion: appVersion,
  );
}, name: 'pixivHttpServiceProvider');

final pixivServiceProvider = Provider<PixivService>((ref) {
  final primary = ref.watch(pixivHttpServiceProvider);
  final fallback = ref.watch(pixivMockServiceProvider);
  return PixivFallbackService(primary: primary, fallback: fallback);
}, name: 'pixivServiceProvider');

final pixivRepositoryProvider = Provider<PixivRepository>((ref) {
  final service = ref.watch(pixivServiceProvider);
  return PixivRepositoryImpl(service: service);
}, name: 'pixivRepositoryProvider');

final pixivAuthFlowProvider = Provider<PixivAuthFlow>((ref) {
  final dio = ref.watch(pixivDioProvider);
  final oauthClient = ref.watch(pixivOAuthClientProvider);
  final appVersionNotifier = ref.read(pixivAppVersionProvider.notifier);
  return PixivAuthFlow(
    dio: dio,
    oauthClient: oauthClient,
    onVersionDetected: appVersionNotifier.update,
  );
}, name: 'pixivAuthFlowProvider');
