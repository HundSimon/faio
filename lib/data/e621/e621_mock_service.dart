import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'e621_service.dart';
import 'models/e621_post.dart';

class E621MockService implements E621Service {
  E621MockService() : _posts = _buildSamplePosts();

  final List<E621Post> _posts;

  @override
  Future<List<E621Post>> fetchPosts({
    int page = 1,
    int limit = 20,
    List<String> tags = const [],
  }) async {
    final filtered = tags.isEmpty
        ? _posts
        : _posts.where((post) => tags.every(post.tags.contains)).toList();
    final start = (page - 1) * limit;
    if (start >= filtered.length) {
      return [];
    }
    var end = start + limit;
    if (end > filtered.length) {
      end = filtered.length;
    }
    return filtered.sublist(start, end);
  }

  @override
  Future<List<E621Post>> searchPosts({
    required String query,
    int page = 1,
    int limit = 20,
  }) async {
    final lower = query.toLowerCase();
    final matches = _posts.where((post) {
      final inDescription = post.description.toLowerCase().contains(lower);
      final inTags = post.tags.any((tag) => tag.toLowerCase().contains(lower));
      return inDescription || inTags;
    }).toList();

    final start = (page - 1) * limit;
    if (start >= matches.length) {
      return [];
    }
    var end = start + limit;
    if (end > matches.length) {
      end = matches.length;
    }
    return matches.sublist(start, end);
  }
}

/// Provides a mock service for development environments.
final e621ServiceProvider = Provider<E621Service>(
  (ref) => E621MockService(),
  name: 'e621ServiceProvider',
);

List<E621Post> _buildSamplePosts() {
  final now = DateTime.now();
  return [
    E621Post(
      id: 3849201,
      createdAt: now.subtract(const Duration(hours: 2)),
      rating: E621Rating.safe,
      tags: const [
        'dragon',
        'landscape',
        'sunrise',
        'flying',
        'aerial',
      ],
      description: 'A dragon glides across the sunrise-hued clouds.',
      file: const E621FileInfo(
        url: null,
        width: 1920,
        height: 1080,
      ),
      preview: E621PreviewInfo(
        url: Uri.parse('https://assets.example.com/mock/e621-flight.jpg'),
        width: 300,
        height: 200,
      ),
      sources: [
        Uri.parse('https://e621.net/posts/3849201'),
      ],
      favCount: 128,
    ),
    E621Post(
      id: 3849202,
      createdAt: now.subtract(const Duration(hours: 5)),
      rating: E621Rating.questionable,
      tags: const ['novel', 'sci-fi', 'furry', 'story'],
      description: 'Serialized sci-fi novel featuring interstellar traders.',
      file: const E621FileInfo(
        url: null,
        width: 0,
        height: 0,
      ),
      preview: const E621PreviewInfo(
        url: null,
        width: 0,
        height: 0,
      ),
      sources: [
        Uri.parse('https://e621.net/posts/3849202'),
      ],
      favCount: 86,
    ),
    E621Post(
      id: 3849203,
      createdAt: now.subtract(const Duration(days: 1)),
      rating: E621Rating.explicit,
      tags: const ['comic', 'adventure', 'jungle', 'anthro'],
      description:
          'Color comic preview showing an expedition team venturing through dense jungle.',
      file: const E621FileInfo(
        url: null,
        width: 2048,
        height: 1536,
      ),
      preview: E621PreviewInfo(
        url: Uri.parse('https://assets.example.com/mock/eh-expo.jpg'),
        width: 400,
        height: 300,
      ),
      sources: [
        Uri.parse('https://e621.net/posts/3849203'),
      ],
      favCount: 64,
    ),
  ];
}
