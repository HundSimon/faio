import 'package:rhttp/rhttp.dart';

/// Ensures every request carries the expected User-Agent header unless
/// overridden manually.
class UserAgentInterceptor extends Interceptor {
  UserAgentInterceptor(this.userAgent);

  final String userAgent;

  @override
  Future<InterceptorResult<HttpRequest>> beforeRequest(
    HttpRequest request,
  ) async {
    final headers = request.headers ?? HttpHeaders.empty;
    if (headers.containsKey(HttpHeaderName.userAgent)) {
      return Interceptor.next(request);
    }
    return Interceptor.next(
      request.copyWith(
        headers: headers.copyWith(
          name: HttpHeaderName.userAgent,
          value: userAgent,
        ),
      ),
    );
  }
}
