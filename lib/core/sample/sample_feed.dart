import '../../domain/models/content_item.dart';

List<FaioContent> buildSampleFeedItems() {
  final now = DateTime.now();
  return [
    FaioContent(
      id: 'e621:3849201',
      source: 'e621',
      title: 'Morning Flight',
      summary: '高空翱翔的龙族插画，突出清晨光线。',
      type: ContentType.illustration,
      previewUrl: Uri.parse('https://assets.example.com/mock/e621-flight.jpg'),
      publishedAt: now.subtract(const Duration(hours: 2)),
      rating: 'General',
      authorName: 'SkyPainter',
      tags: const ['dragon', 'landscape', 'sunrise'],
    ),
    FaioContent(
      id: 'pixiv:10293847',
      source: 'pixiv',
      title: '星际旅者·第一章',
      summary: '多世界观设定的兽人科幻小说章节摘录。',
      type: ContentType.novel,
      previewUrl: null,
      publishedAt: now.subtract(const Duration(hours: 5)),
      rating: 'Teen',
      authorName: 'NovaTail',
      tags: const ['novel', 'sci-fi', 'furry'],
    ),
    FaioContent(
      id: 'e-hentai:778899',
      source: 'e-hentai',
      title: 'Jungle Expedition (Preview)',
      summary: '彩页漫画预览，记录深林探险冒险。',
      type: ContentType.comic,
      previewUrl: Uri.parse('https://assets.example.com/mock/eh-expo.jpg'),
      publishedAt: now.subtract(const Duration(days: 1)),
      rating: 'Adult',
      authorName: 'WildSketch',
      tags: const ['comic', 'adventure'],
    ),
  ];
}
