import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rhttp/rhttp.dart';

import 'interceptors/logging_interceptor.dart';
import 'interceptors/user_agent_interceptor.dart';
import 'network_config.dart';

final _clientSettingsProvider = Provider<ClientSettings>((ref) {
  final config = ref.watch(networkConfigProvider);
  final timeout = config.receiveTimeout > config.sendTimeout
      ? config.receiveTimeout
      : config.sendTimeout;
  return ClientSettings(
    timeoutSettings: TimeoutSettings(
      connectTimeout: config.connectTimeout,
      timeout: timeout,
    ),
    userAgent: config.userAgent,
    throwOnStatusCode: true,
  );
});

/// Provides a preconfigured RhttpClient instance with common interceptors.
final rhttpClientProvider = Provider<RhttpClient>((ref) {
  final settings = ref.watch(_clientSettingsProvider);
  final config = ref.watch(networkConfigProvider);

  final interceptors = <Interceptor>[
    UserAgentInterceptor(config.userAgent),
    if (config.logNetworking) LoggingInterceptor(),
  ];

  final client = RhttpClient.createSync(
    settings: settings,
    interceptors: interceptors,
  );
  ref.onDispose(client.dispose);
  return client;
}, name: 'rhttpClientProvider');
