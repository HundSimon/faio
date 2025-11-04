import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:faio/domain/models/content_item.dart';

import '../providers/feed_providers.dart';
import 'illustration_gallery_screen.dart';

Map<String, String>? _imageHeadersFor(FaioContent content) {
  final source = content.source.toLowerCase();
  if (source.startsWith('pixiv')) {
    return const {
      'Referer': 'https://app-api.pixiv.net/',
      'User-Agent': 'PixivAndroidApp/5.0.234 (Android 11; Pixel 5)',
    };
  }
  return null;
}

class IllustrationDetailScreen extends ConsumerStatefulWidget {
  const IllustrationDetailScreen({required this.initialIndex, super.key});

  final int initialIndex;

  @override
  ConsumerState<IllustrationDetailScreen> createState() =>
      _IllustrationDetailScreenState();
}

class _IllustrationDetailScreenState
    extends ConsumerState<IllustrationDetailScreen> {
  late int _currentIndex;
  bool _ensurePending = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(feedSelectionProvider.notifier).select(_currentIndex);
      ref
          .read(feedControllerProvider.notifier)
          .ensureIndexLoaded(_currentIndex);
    });
  }

  void _ensureIndexLoaded() {
    if (!mounted) return;
    if (_ensurePending) return;
    _ensurePending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await ref
          .read(feedControllerProvider.notifier)
          .ensureIndexLoaded(_currentIndex);
      _ensurePending = false;
    });
  }

  Future<void> _openGallery() async {
    final result = await Navigator.of(context, rootNavigator: true).push<int>(
      PageRouteBuilder(
        pageBuilder: (context, _, __) =>
            IllustrationGalleryScreen(initialIndex: _currentIndex),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );

    if (!mounted) return;

    if (result != null && result != _currentIndex) {
      setState(() {
        _currentIndex = result;
      });
      ref.read(feedSelectionProvider.notifier).select(result);
      ref.read(feedControllerProvider.notifier).ensureIndexLoaded(result);
    }
  }

  void _requestScrollBack() {
    if (!mounted) return;
    ref.read(feedSelectionProvider.notifier).requestScrollTo(_currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedControllerProvider);

    ref.listen<FeedSelectionState>(feedSelectionProvider, (prev, next) {
      if (!mounted) return;
      final selected = next.selectedIndex;
      if (selected != null && selected != _currentIndex) {
        setState(() {
          _currentIndex = selected;
        });
      }
    });

    final theme = Theme.of(context);

    if (_currentIndex < 0) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('未找到内容')),
      );
    }

    FaioContent? maybeContent;
    if (_currentIndex < feedState.items.length) {
      maybeContent = feedState.items[_currentIndex];
    } else if (feedState.hasMore) {
      _ensureIndexLoaded();
    }

    if (maybeContent == null) {
      final isLoading = feedState.isLoadingInitial || feedState.isLoadingMore;
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: isLoading
              ? const CircularProgressIndicator()
              : const Text('正在加载更多内容…'),
        ),
      );
    }

    final content = maybeContent;
    final aspectRatio = content.previewAspectRatio ?? 1;
    final hasSummary = content.summary.trim().isNotEmpty;
    final detailImageUrl = content.sampleUrl ?? content.previewUrl;
    final fallbackPreviewUrl = content.previewUrl;

    String formatDateTime(DateTime? dateTime) {
      if (dateTime == null) {
        return '未知';
      }
      final local = dateTime.toLocal();
      return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
          '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }

    final formattedCreatedAt = formatDateTime(content.publishedAt);

    Widget placeholder(IconData icon) {
      return Container(
        height: 240,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        _requestScrollBack();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (detailImageUrl != null)
                GestureDetector(
                  onTap: _openGallery,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: aspectRatio > 0 ? aspectRatio : 1,
                      child: Image.network(
                        detailImageUrl.toString(),
                        fit: BoxFit.cover,
                        headers: _imageHeadersFor(content),
                        errorBuilder: (_, __, ___) =>
                            placeholder(Icons.broken_image),
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) {
                            return child;
                          }
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              if (fallbackPreviewUrl != null)
                                Image.network(
                                  fallbackPreviewUrl.toString(),
                                  fit: BoxFit.cover,
                                  headers: _imageHeadersFor(content),
                                  errorBuilder: (_, __, ___) =>
                                      placeholder(Icons.broken_image),
                                ),
                              const Center(child: CircularProgressIndicator()),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                )
              else
                placeholder(Icons.image),
              const SizedBox(height: 16),
              Text('来源：${content.source}', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
              Text(
                '作者：${content.authorName ?? '未知'}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text('评级：${content.rating}', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
              Text(
                '创建时间：$formattedCreatedAt',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '更新时间：${formatDateTime(content.updatedAt)}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '收藏数：${content.favoriteCount}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Text(
                '简介',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hasSummary ? content.summary : '暂无简介',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: hasSummary
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              if (content.sourceLinks.isNotEmpty) ...[
                Text(
                  '来源链接',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: content.sourceLinks
                      .map(
                        (uri) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SelectableText(
                            uri.toString(),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
              ],
              if (content.tags.isNotEmpty) ...[
                Text(
                  '标签',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: content.tags
                      .map(
                        (tag) => Chip(
                          label: Text(tag),
                          backgroundColor: theme.colorScheme.surfaceVariant,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
