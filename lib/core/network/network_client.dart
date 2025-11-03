import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'interceptors/user_agent_interceptor.dart';
import 'network_config.dart';

final _dioBaseOptionsProvider = Provider<BaseOptions>((ref) {
  final config = ref.watch(networkConfigProvider);
  return BaseOptions(
    connectTimeout: config.connectTimeout,
    receiveTimeout: config.receiveTimeout,
    sendTimeout: config.sendTimeout,
    headers: {
      'User-Agent': config.userAgent,
      'Accept': 'application/json',
    },
    responseType: ResponseType.json,
  );
});

/// Provides a preconfigured Dio instance with common interceptors.
final dioProvider = Provider<Dio>((ref) {
  final baseOptions = ref.watch(_dioBaseOptionsProvider);
  final config = ref.watch(networkConfigProvider);

  final dio = Dio(baseOptions);

  dio.interceptors.add(UserAgentInterceptor(config.userAgent));

  if (config.logNetworking) {
    dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestBody: false,
        responseBody: false,
        responseHeader: false,
      ),
    );
  }

  return dio;
}, name: 'dioProvider');
