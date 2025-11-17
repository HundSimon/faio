import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global network configuration for Dio clients.
class AppNetworkConfig extends Equatable {
  const AppNetworkConfig({
    this.userAgent = 'FAIO/0.1 (+https://faio.app)',
    this.connectTimeout = const Duration(seconds: 20),
    this.receiveTimeout = const Duration(seconds: 20),
    this.sendTimeout = const Duration(seconds: 20),
    this.logNetworking = true,
  });

  final String userAgent;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Duration sendTimeout;
  final bool logNetworking;

  @override
  List<Object?> get props => [
    userAgent,
    connectTimeout,
    receiveTimeout,
    sendTimeout,
    logNetworking,
  ];

  AppNetworkConfig copyWith({
    String? userAgent,
    Duration? connectTimeout,
    Duration? receiveTimeout,
    Duration? sendTimeout,
    bool? logNetworking,
  }) {
    return AppNetworkConfig(
      userAgent: userAgent ?? this.userAgent,
      connectTimeout: connectTimeout ?? this.connectTimeout,
      receiveTimeout: receiveTimeout ?? this.receiveTimeout,
      sendTimeout: sendTimeout ?? this.sendTimeout,
      logNetworking: logNetworking ?? this.logNetworking,
    );
  }
}

/// Exposes the default network configuration. Later this can be overridden by
/// settings or environment-specific providers.
final networkConfigProvider = Provider<AppNetworkConfig>(
  (ref) => const AppNetworkConfig(),
  name: 'networkConfigProvider',
);
