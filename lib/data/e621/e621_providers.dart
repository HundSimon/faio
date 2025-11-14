import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/network_client.dart';
import '../../core/network/rate_limiter.dart';
import 'e621_auth.dart';
import 'e621_fallback_service.dart';
import 'e621_http_service.dart';
import 'e621_mock_service.dart';
import 'e621_service.dart';

final e621RateLimiterProvider = Provider<RateLimiter>((ref) {
  return RateLimiter(const Duration(milliseconds: 500));
}, name: 'e621RateLimiterProvider');

final e621HttpServiceProvider = Provider<E621Service>((ref) {
  final client = ref.watch(rhttpClientProvider);
  final credentials = ref.watch(e621AuthProvider);
  final rateLimiter = ref.watch(e621RateLimiterProvider);
  return E621HttpService(
    client: client,
    rateLimiter: rateLimiter,
    credentials: credentials,
  );
}, name: 'e621HttpServiceProvider');

final e621ServiceProvider = Provider<E621Service>((ref) {
  final primary = ref.watch(e621HttpServiceProvider);
  final fallback = ref.watch(e621MockServiceProvider);
  return E621FallbackService(primary: primary, fallback: fallback);
}, name: 'e621ServiceProvider');
