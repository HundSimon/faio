import 'package:flutter/foundation.dart';
import 'package:rhttp/rhttp.dart';

/// Very small logging interceptor while we wait for DevTools traces.
class LoggingInterceptor extends Interceptor {
  LoggingInterceptor();

  @override
  Future<InterceptorResult<HttpRequest>> beforeRequest(
    HttpRequest request,
  ) async {
    debugPrint(
      '⟶ ${request.method.value} ${request.settings?.baseUrl ?? ''}${request.url}',
    );
    return Interceptor.next(request);
  }

  @override
  Future<InterceptorResult<HttpResponse>> afterResponse(
    HttpResponse response,
  ) async {
    debugPrint(
      '⟵ ${response.statusCode} ${response.request.settings?.baseUrl ?? ''}${response.request.url}',
    );
    return Interceptor.next(response);
  }

  @override
  Future<InterceptorResult<RhttpException>> onError(
    RhttpException exception,
  ) async {
    debugPrint(
      '⟡ ${exception.runtimeType} ${exception.request.settings?.baseUrl ?? ''}${exception.request.url}',
    );
    return Interceptor.next(exception);
  }
}
