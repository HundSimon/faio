import 'dart:io' as io;

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:rhttp/rhttp.dart';

import 'pixiv_dns_resolver.dart';

/// Provides a cache manager that fetches Pixiv CDN images through rhttp with
/// the same DNS and TLS overrides used by the API client.
class PixivImageCacheManager extends CacheManager {
  PixivImageCacheManager._(this._client, this._dnsResolver)
    : super(
        Config(
          'pixivImageCache',
          stalePeriod: const Duration(days: 30),
          maxNrOfCacheObjects: 400,
          fileService: PixivRhttpFileService(client: _client),
        ),
      );

  final RhttpClient _client;
  final PixivDnsResolver _dnsResolver;

  static PixivImageCacheManager? _instance;

  static PixivImageCacheManager get instance {
    return _instance ??= PixivImageCacheManager._create();
  }

  static PixivImageCacheManager _create() {
    final resolver = PixivDnsResolver();
    final client = RhttpClient.createSync(
      settings: ClientSettings(
        timeoutSettings: const TimeoutSettings(
          connectTimeout: Duration(seconds: 20),
          timeout: Duration(seconds: 20),
        ),
        dnsSettings: DnsSettings.dynamic(resolver: resolver.resolve),
        tlsSettings: const TlsSettings(verifyCertificates: false, sni: false),
        throwOnStatusCode: false,
      ),
    );
    return PixivImageCacheManager._(client, resolver);
  }

  @override
  Future<void> dispose() async {
    await super.dispose();
    _client.dispose();
    _dnsResolver.dispose();
    _instance = null;
  }
}

class PixivRhttpFileService extends FileService {
  PixivRhttpFileService({required RhttpClient client}) : _client = client;

  final RhttpClient _client;

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    final response = await _client.requestStream(
      method: HttpMethod.get,
      url: url,
      headers: headers == null || headers.isEmpty
          ? null
          : HttpHeaders.rawMap(headers),
    );
    return _PixivRhttpFileServiceResponse(response);
  }
}

class _PixivRhttpFileServiceResponse implements FileServiceResponse {
  _PixivRhttpFileServiceResponse(this._response) : _receivedAt = DateTime.now();

  final HttpStreamResponse _response;
  final DateTime _receivedAt;

  @override
  Stream<List<int>> get content => _response.body;

  @override
  int? get contentLength {
    final header = _header(io.HttpHeaders.contentLengthHeader);
    if (header == null) {
      return null;
    }
    return int.tryParse(header);
  }

  @override
  int get statusCode => _response.statusCode;

  @override
  DateTime get validTill {
    var maxAge = const Duration(days: 7);
    final cacheControl = _header(io.HttpHeaders.cacheControlHeader);
    if (cacheControl != null) {
      final directives = cacheControl.split(',');
      for (final directive in directives) {
        final value = directive.trim().toLowerCase();
        if (value == 'no-cache') {
          maxAge = Duration.zero;
        } else if (value.startsWith('max-age=')) {
          final seconds = int.tryParse(value.split('=').last);
          if (seconds != null && seconds >= 0) {
            maxAge = Duration(seconds: seconds);
          }
        }
      }
    }
    return _receivedAt.add(maxAge);
  }

  @override
  String? get eTag => _header(io.HttpHeaders.etagHeader);

  @override
  String get fileExtension {
    final contentType = _header(io.HttpHeaders.contentTypeHeader);
    if (contentType == null) {
      return '';
    }
    try {
      final parsed = io.ContentType.parse(contentType);
      final subType = parsed.subType;
      if (subType.isEmpty) {
        return '';
      }
      return '.${subType.toLowerCase()}';
    } on FormatException {
      return '';
    }
  }

  String? _header(String name) {
    final lowerName = name.toLowerCase();
    for (final entry in _response.headers) {
      if (entry.$1.toLowerCase() == lowerName) {
        return entry.$2;
      }
    }
    return null;
  }
}

/// Returns the Pixiv cache manager when the provided [url] targets the Pixiv
/// CDN; otherwise returns `null` so default HTTP loading is used.
BaseCacheManager? pixivImageCacheManagerForUrl(Uri? url) {
  final host = url?.host.toLowerCase();
  if (host == null) {
    return null;
  }
  if (host.endsWith('pximg.net')) {
    return PixivImageCacheManager.instance;
  }
  return null;
}
