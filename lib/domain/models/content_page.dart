import 'content_item.dart';

class ContentPageResult {
  const ContentPageResult({
    required this.items,
    required this.page,
    required this.hasMore,
    this.nextOffset,
    this.nextUrl,
  });

  final List<FaioContent> items;
  final int page;
  final bool hasMore;
  final int? nextOffset;
  final String? nextUrl;
}
