import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/pixiv_models.dart';
import 'pixiv_service.dart';

class PixivMockService implements PixivService {
  PixivMockService()
    : _illustrations = _buildIllustrations(),
      _novels = _buildNovels();

  final List<PixivIllust> _illustrations;
  final List<PixivNovel> _novels;

  @override
  Future<PixivPage<PixivIllust>> fetchIllustrations({
    int offset = 0,
    int limit = 30,
  }) async {
    final slice = _slice(_illustrations, offset, limit);
    return PixivPage<PixivIllust>(
      items: slice.items,
      nextUrl: slice.hasNext
          ? 'mock://pixiv/illustrations?offset=${slice.nextOffset}'
          : null,
    );
  }

  @override
  Future<PixivPage<PixivIllust>> fetchManga({
    int offset = 0,
    int limit = 30,
  }) async {
    final manga = _illustrations
        .where((illust) => illust.type == PixivIllustType.manga)
        .toList();
    final slice = _slice(manga, offset, limit);
    return PixivPage<PixivIllust>(
      items: slice.items,
      nextUrl: slice.hasNext
          ? 'mock://pixiv/manga?offset=${slice.nextOffset}'
          : null,
    );
  }

  @override
  Future<PixivPage<PixivNovel>> fetchNovels({
    int offset = 0,
    int limit = 30,
  }) async {
    final slice = _slice(_novels, offset, limit);
    return PixivPage<PixivNovel>(
      items: slice.items,
      nextUrl: slice.hasNext
          ? 'mock://pixiv/novels?offset=${slice.nextOffset}'
          : null,
    );
  }

  @override
  Future<PixivIllust?> fetchIllustrationDetail(int illustId) async {
    for (final element in _illustrations) {
      if (element.id == illustId) {
        return element;
      }
    }
    return null;
  }

  @override
  Future<PixivNovel?> fetchNovelDetail(int novelId) async {
    for (final element in _novels) {
      if (element.id == novelId) {
        return element;
      }
    }
    return null;
  }

  @override
  Future<String?> fetchNovelText(int novelId) async {
    for (final novel in _novels) {
      if (novel.id == novelId) {
        return novel.text ?? novel.caption;
      }
    }
    return null;
  }

  @override
  Future<PixivPage<PixivIllust>> searchIllustrations({
    required String query,
    int offset = 0,
    int limit = 30,
  }) async {
    if (query.trim().isEmpty) {
      return const PixivPage<PixivIllust>(items: []);
    }
    final filtered = _illustrations
        .where((illust) => _matchesIllust(query, illust))
        .toList();
    final slice = _slice(filtered, offset, limit);
    return PixivPage<PixivIllust>(
      items: slice.items,
      nextUrl: slice.hasNext
          ? 'mock://pixiv/search/illust?offset=${slice.nextOffset}'
          : null,
    );
  }

  @override
  Future<PixivPage<PixivNovel>> searchNovels({
    required String query,
    int offset = 0,
    int limit = 30,
  }) async {
    if (query.trim().isEmpty) {
      return const PixivPage<PixivNovel>(items: []);
    }
    final filtered = _novels
        .where((novel) => _matchesNovel(query, novel))
        .toList();
    final slice = _slice(filtered, offset, limit);
    return PixivPage<PixivNovel>(
      items: slice.items,
      nextUrl: slice.hasNext
          ? 'mock://pixiv/search/novel?offset=${slice.nextOffset}'
          : null,
    );
  }
}

class _SliceResult<T> {
  const _SliceResult({
    required this.items,
    required this.hasNext,
    required this.nextOffset,
  });

  final List<T> items;
  final bool hasNext;
  final int nextOffset;
}

_SliceResult<T> _slice<T>(List<T> source, int offset, int limit) {
  if (offset >= source.length) {
    return _SliceResult<T>(items: const [], hasNext: false, nextOffset: offset);
  }
  final end = (offset + limit).clamp(0, source.length);
  final items = source.sublist(offset, end);
  final hasNext = end < source.length;
  return _SliceResult<T>(items: items, hasNext: hasNext, nextOffset: end);
}

bool _matchesIllust(String query, PixivIllust illust) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) {
    return false;
  }
  if (illust.title.toLowerCase().contains(normalized)) {
    return true;
  }
  if (illust.caption.toLowerCase().contains(normalized)) {
    return true;
  }
  return illust.tags.any((tag) => tag.name.toLowerCase().contains(normalized));
}

bool _matchesNovel(String query, PixivNovel novel) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) {
    return false;
  }
  if (novel.title.toLowerCase().contains(normalized)) {
    return true;
  }
  if (novel.caption.toLowerCase().contains(normalized)) {
    return true;
  }
  if (novel.user.name.toLowerCase().contains(normalized)) {
    return true;
  }
  return novel.tags.any((tag) => tag.name.toLowerCase().contains(normalized));
}

List<PixivIllust> _buildIllustrations() {
  final now = DateTime.now();
  return [
    PixivIllust(
      id: 1001,
      title: '月光下的白狼',
      caption: '银色的毛发在森林里闪耀着微光。',
      type: PixivIllustType.illustration,
      createDate: now.subtract(const Duration(hours: 3)),
      width: 2000,
      height: 1400,
      pageCount: 1,
      totalBookmarks: 420,
      tags: const [
        PixivTag(name: '狼'),
        PixivTag(name: '月光'),
        PixivTag(name: '插画'),
      ],
      user: const PixivUserSummary(id: 777, name: 'MoonlitArtist'),
      imageUrls: PixivImageUrls(
        squareMedium: Uri(
          scheme: 'https',
          host: 'assets.example.com',
          path: '/mock/pixiv/wolf_square.jpg',
        ),
        medium: Uri(
          scheme: 'https',
          host: 'assets.example.com',
          path: '/mock/pixiv/wolf_medium.jpg',
        ),
        large: Uri(
          scheme: 'https',
          host: 'assets.example.com',
          path: '/mock/pixiv/wolf_large.jpg',
        ),
        original: Uri(
          scheme: 'https',
          host: 'assets.example.com',
          path: '/mock/pixiv/wolf_original.jpg',
        ),
      ),
      metaPages: const [],
      originalImageUrl: Uri(
        scheme: 'https',
        host: 'assets.example.com',
        path: '/mock/pixiv/wolf_original.jpg',
      ),
      updateDate: now.subtract(const Duration(hours: 2, minutes: 30)),
      sanityLevel: 2,
      xRestrict: 0,
      aiType: 0,
    ),
    PixivIllust(
      id: 1002,
      title: '丛林冒险漫画',
      caption: '探索古老遗迹的二人组，章节预览。',
      type: PixivIllustType.manga,
      createDate: now.subtract(const Duration(hours: 6)),
      width: 1200,
      height: 1800,
      pageCount: 3,
      totalBookmarks: 256,
      tags: const [
        PixivTag(name: '漫画'),
        PixivTag(name: '冒险'),
      ],
      user: const PixivUserSummary(id: 778, name: 'JungleSketch'),
      imageUrls: PixivImageUrls(
        squareMedium: Uri(
          scheme: 'https',
          host: 'assets.example.com',
          path: '/mock/pixiv/manga_thumb.jpg',
        ),
        medium: Uri(
          scheme: 'https',
          host: 'assets.example.com',
          path: '/mock/pixiv/manga_medium.jpg',
        ),
        large: Uri(
          scheme: 'https',
          host: 'assets.example.com',
          path: '/mock/pixiv/manga_large.jpg',
        ),
      ),
      metaPages: [
        PixivMetaPage(
          imageUrls: PixivImageUrls(
            medium: Uri(
              scheme: 'https',
              host: 'assets.example.com',
              path: '/mock/pixiv/manga_page1.jpg',
            ),
            large: Uri(
              scheme: 'https',
              host: 'assets.example.com',
              path: '/mock/pixiv/manga_page1_large.jpg',
            ),
          ),
        ),
      ],
      originalImageUrl: null,
      updateDate: now.subtract(const Duration(hours: 5, minutes: 45)),
      sanityLevel: 2,
      xRestrict: 0,
      aiType: 0,
    ),
  ];
}

List<PixivNovel> _buildNovels() {
  final now = DateTime.now();
  return [
    PixivNovel(
      id: 2001,
      title: '林海旅记',
      caption: '森林旅人和随行狼骑士的轻小说章节预览。',
      createDate: now.subtract(const Duration(days: 1, hours: 2)),
      updateDate: now.subtract(const Duration(days: 1)),
      user: const PixivUserSummary(id: 901, name: 'StoryWeaver'),
      tags: const [
        PixivTag(name: '小说'),
        PixivTag(name: '奇幻'),
      ],
      totalBookmarks: 512,
      coverImageUrls: PixivImageUrls(
        medium: Uri(
          scheme: 'https',
          host: 'assets.example.com',
          path: '/mock/pixiv/novel_cover.jpg',
        ),
        large: Uri(
          scheme: 'https',
          host: 'assets.example.com',
          path: '/mock/pixiv/novel_cover_large.jpg',
        ),
      ),
      textLength: 4500,
      seriesId: 100,
      seriesTitle: '林海旅记系列',
      text: '跨越林海的旅人，携手狼人骑士共同探险。',
    ),
  ];
}

final pixivMockServiceProvider = Provider<PixivMockService>(
  (ref) => PixivMockService(),
  name: 'pixivMockServiceProvider',
);
