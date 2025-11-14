import 'dart:convert';
import 'package:rhttp/rhttp.dart';

/// Resolves Pixiv hosts via Cloudflare's 1.1.1.1 resolver with static
/// overrides for known endpoints.
class PixivDnsResolver {
  PixivDnsResolver({RhttpClient? client})
    : _client =
          client ?? RhttpClient.createSync(settings: const ClientSettings());

  static const Map<String, List<String>> _hostOverrides = {
    'app-api.pixiv.net': ['210.140.139.155'],
    'oauth.secure.pixiv.net': ['210.140.139.155'],
    'i.pximg.net': ['210.140.139.133'],
    's.pximg.net': ['210.140.139.133'],
  };

  final Map<String, List<String>> _cache = {};
  final RhttpClient _client;

  void dispose() => _client.dispose();

  Future<List<String>> resolve(String host) async {
    final normalizedHost = host.toLowerCase();
    final override = _hostOverrides[normalizedHost];
    if (override != null) {
      return override;
    }
    final cached = _cache[normalizedHost];
    if (cached != null) {
      return cached;
    }
    final resolved = await _resolveViaCloudflare(normalizedHost);
    if (resolved.isNotEmpty) {
      _cache[normalizedHost] = resolved;
    }
    return resolved;
  }

  Future<List<String>> _resolveViaCloudflare(String host) async {
    try {
      final response = await _client.requestText(
        method: HttpMethod.get,
        url: 'https://1.1.1.1/dns-query',
        query: {'name': host, 'type': 'A'},
        headers: HttpHeaders.rawMap({
          'Accept': 'application/dns-json',
          'User-Agent': 'faio/1.0',
        }),
      );
      final decoded = jsonDecode(response.body);
      final answers = decoded is Map<String, dynamic>
          ? decoded['Answer']
          : null;
      if (answers is! List) {
        return const [];
      }
      final results = <String>[];
      for (final answer in answers) {
        if (answer is! Map) {
          continue;
        }
        final type = answer['type'];
        final data = answer['data'];
        if (type == 1 && data is String && data.isNotEmpty) {
          results.add(data);
        }
      }
      return results;
    } on RhttpException {
      return const [];
    }
  }
}
