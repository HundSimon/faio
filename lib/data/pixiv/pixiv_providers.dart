import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rhttp/rhttp.dart';

import '../../core/network/rate_limiter.dart';
import '../../domain/repositories/pixiv_repository.dart';
import '../furrynovel/furrynovel_providers.dart';
import '../repositories/pixiv_repository_impl.dart';
import 'pixiv_app_version.dart';
import 'pixiv_auth.dart';
import 'pixiv_auth_flow.dart';
import 'pixiv_dns_resolver.dart';
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

final pixivHttpClientProvider = Provider<RhttpClient>((ref) {
  final version = ref.watch(pixivAppVersionProvider);
  final dnsResolver = PixivDnsResolver();
  final client = RhttpClient.createSync(
    settings: ClientSettings(
      timeoutSettings: const TimeoutSettings(
        connectTimeout: Duration(seconds: 20),
        timeout: Duration(seconds: 20),
      ),
      userAgent: 'PixivAndroidApp/$version (Android 11; Pixel 5)',
      dnsSettings: DnsSettings.dynamic(resolver: dnsResolver.resolve),
      tlsSettings: const TlsSettings(verifyCertificates: false, sni: false),
    ),
  );
  ref.onDispose(dnsResolver.dispose);
  ref.onDispose(client.dispose);
  return client;
}, name: 'pixivHttpClientProvider');

final pixivOAuthClientProvider = Provider<PixivOAuthClient>((ref) {
  final version = ref.watch(pixivAppVersionProvider);
  final client = ref.watch(pixivHttpClientProvider);
  return PixivOAuthClient(client: client, appVersion: version);
}, name: 'pixivOAuthClientProvider');

final pixivHttpServiceProvider = Provider<PixivService>((ref) {
  final client = ref.watch(pixivHttpClientProvider);
  final credentials = ref.watch(pixivAuthProvider);
  final rateLimiter = ref.watch(pixivRateLimiterProvider);
  final oauthClient = ref.watch(pixivOAuthClientProvider);
  final notifier = ref.read(pixivAuthProvider.notifier);
  final appVersion = ref.watch(pixivAppVersionProvider);
  return PixivHttpService(
    client: client,
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
  final furryNovelService = ref.watch(furryNovelServiceProvider);
  return PixivRepositoryImpl(
    service: service,
    furryNovelService: furryNovelService,
  );
}, name: 'pixivRepositoryProvider');

final pixivAuthFlowProvider = Provider<PixivAuthFlow>((ref) {
  final client = ref.watch(pixivHttpClientProvider);
  final oauthClient = ref.watch(pixivOAuthClientProvider);
  final appVersionNotifier = ref.read(pixivAppVersionProvider.notifier);
  final appVersion = ref.watch(pixivAppVersionProvider);
  return PixivAuthFlow(
    client: client,
    oauthClient: oauthClient,
    appVersion: appVersion,
    onVersionDetected: appVersionNotifier.update,
  );
}, name: 'pixivAuthFlowProvider');
