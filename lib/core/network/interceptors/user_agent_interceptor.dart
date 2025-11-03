import 'package:dio/dio.dart';

/// Ensures every request carries the expected User-Agent header unless
/// overridden manually.
class UserAgentInterceptor extends Interceptor {
  UserAgentInterceptor(this.userAgent);

  final String userAgent;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers.putIfAbsent('User-Agent', () => userAgent);
    handler.next(options);
  }
}
