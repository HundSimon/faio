import 'dart:convert';

import 'package:rhttp/rhttp.dart';

import '../../core/network/rate_limiter.dart';
import 'e621_credentials.dart';
import 'e621_service.dart';
import 'models/e621_post.dart';

class E621HttpService implements E621Service {
  E621HttpService({
    required RhttpClient client,
    required RateLimiter rateLimiter,
    E621Credentials? credentials,
  }) : _client = client,
       _rateLimiter = rateLimiter,
       _credentials = credentials;

  static const _baseUrl = 'https://e621.net';
  final RhttpClient _client;
  final RateLimiter _rateLimiter;
  final E621Credentials? _credentials;

  @override
  Future<List<E621Post>> fetchPosts({
    int page = 1,
    int limit = 20,
    List<String> tags = const [],
  }) async {
    return _request(page: page, limit: limit, tags: tags);
  }

  @override
  Future<List<E621Post>> searchPosts({
    required String query,
    int page = 1,
    int limit = 20,
  }) async {
    final composedTags = query.trim().isEmpty
        ? <String>[]
        : query.trim().split(RegExp(r'\s+'));
    return _request(page: page, limit: limit, tags: composedTags);
  }

  Future<List<E621Post>> _request({
    required int page,
    required int limit,
    List<String> tags = const [],
  }) async {
    await _rateLimiter.acquire();

    final normalizedTags = tags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);
    final queryTags = <String>[
      if (!normalizedTags.any((tag) => tag.startsWith('order:')))
        'order:id_desc',
      ...normalizedTags,
    ];

    final authHeaders = <String, String>{};
    final credentials = _credentials;
    if (credentials != null && credentials.isComplete) {
      final raw = '${credentials.username}:${credentials.apiKey}';
      final encoded = base64Encode(utf8.encode(raw));
      authHeaders['Authorization'] = 'Basic $encoded';
    }

    final clampedLimit = limit.clamp(1, 320);
    final response = await _client.requestText(
      method: HttpMethod.get,
      url: '$_baseUrl/posts.json',
      query: {
        'page': '$page',
        'limit': '$clampedLimit',
        if (queryTags.isNotEmpty) 'tags': queryTags.join(' '),
      },
      headers: authHeaders.isEmpty ? null : HttpHeaders.rawMap(authHeaders),
    );

    final data = _decodeJson(response.body);
    if (data == null) {
      return const [];
    }

    final posts = data['posts'];
    if (posts is! List) {
      return const [];
    }

    final parsed = posts
        .whereType<Map<String, dynamic>>()
        .map(E621Post.fromJson)
        .toList();
    parsed.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return parsed;
  }

  Map<String, dynamic>? _decodeJson(String body) {
    if (body.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
