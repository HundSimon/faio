import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/rate_limiter.dart';
import '../../domain/repositories/pixiv_repository.dart';
import '../repositories/pixiv_repository_impl.dart';
import 'pixiv_auth.dart';
import 'pixiv_fallback_service.dart';
import 'pixiv_http_service.dart';
import 'pixiv_mock_service.dart';
import 'pixiv_oauth_client.dart';
import 'pixiv_service.dart';

final pixivRateLimiterProvider = Provider<RateLimiter>((ref) {
  return RateLimiter(const Duration(milliseconds: 500));
}, name: 'pixivRateLimiterProvider');

final pixivOAuthClientProvider = Provider<PixivOAuthClient>((ref) {
  return PixivOAuthClient();
}, name: 'pixivOAuthClientProvider');

final pixivDioProvider = Provider<Dio>((ref) {
  final options = BaseOptions(
    baseUrl: 'https://app-api.pixiv.net',
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
    sendTimeout: const Duration(seconds: 20),
  );
  return Dio(options);
}, name: 'pixivDioProvider');

final pixivHttpServiceProvider = Provider<PixivService>((ref) {
  final dio = ref.watch(pixivDioProvider);
  final credentials = ref.watch(pixivAuthProvider);
  final rateLimiter = ref.watch(pixivRateLimiterProvider);
  final oauthClient = ref.watch(pixivOAuthClientProvider);
  final notifier = ref.read(pixivAuthProvider.notifier);
  return PixivHttpService(
    dio: dio,
    oauthClient: oauthClient,
    rateLimiter: rateLimiter,
    credentials: credentials,
    onCredentialsRefreshed: notifier.setCredentials,
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
