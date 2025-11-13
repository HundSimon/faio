import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:faio/domain/models/content_item.dart';
import 'package:faio/domain/models/novel_detail.dart';
import 'package:faio/domain/models/novel_reader.dart';
import 'package:faio/domain/utils/content_id.dart';
import 'package:faio/features/common/widgets/detail_section_card.dart';
import 'package:faio/features/common/widgets/skeleton_theme.dart';
import 'package:faio/features/feed/providers/feed_providers.dart';
import 'package:faio/features/library/domain/library_entries.dart';
import 'package:faio/features/library/providers/library_providers.dart';
import 'package:faio/features/library/utils/library_mappers.dart';
import 'package:faio/features/library/presentation/widgets/favorite_icon_button.dart';
import 'package:faio/features/novel/presentation/novel_hero.dart';

import '../providers/novel_providers.dart';
import 'widgets/novel_image.dart';
import 'widgets/novel_series_sheet.dart';

class NovelDetailRouteExtra {
  const NovelDetailRouteExtra({this.initialContent, this.initialIndex});

  final FaioContent? initialContent;
  final int? initialIndex;
}

class NovelDetailScreen extends ConsumerStatefulWidget {
  const NovelDetailScreen({
    required this.novelId,
    this.initialContent,
    this.initialIndex,
    super.key,
  });

  final int novelId;
  final FaioContent? initialContent;
  final int? initialIndex;

  @override
  ConsumerState<NovelDetailScreen> createState() => _NovelDetailScreenState();
}

class _NovelDetailScreenState extends ConsumerState<NovelDetailScreen> {
  String? _lastRecordedContentId;
  PageController? _pageController;
  int? _currentIndex;

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.initialIndex;
    if (initialIndex != null) {
      _setPagerIndex(initialIndex);
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  void _setPagerIndex(int index, {bool useSetState = false}) {
    void assign() {
      _currentIndex = index;
      _pageController = PageController(initialPage: index);
      _lastRecordedContentId = null;
    }

    if (useSetState) {
      setState(assign);
    } else {
      assign();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(novelFeedSelectionProvider.notifier).select(index);
      ref
          .read(pixivNovelFeedControllerProvider.notifier)
          .ensureIndexLoaded(index);
    });
  }

  Future<void> _animateToIndex(int index) async {
    final controller = _pageController;
    if (controller == null || !controller.hasClients) {
      return;
    }
    await controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
  }

  void _handlePageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _lastRecordedContentId = null;
    });
    ref.read(novelFeedSelectionProvider.notifier).select(index);
    ref.read(pixivNovelFeedControllerProvider.notifier).ensureIndexLoaded(
      index + 1,
    );
  }

  void _recordHistory(FaioContent content, {bool force = false}) {
    if (!force && _lastRecordedContentId == content.id) {
      return;
    }
    _lastRecordedContentId = content.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(libraryHistoryProvider.notifier).recordView(content);
    });
  }

  void _requestScrollBack() {
    final index = _currentIndex;
    if (index == null) {
      return;
    }
    ref.read(novelFeedSelectionProvider.notifier).requestScrollTo(index);
  }

  void _maybeAttachPagerFromFeed(List<FaioContent> items) {
    if (_pageController != null || items.isEmpty) {
      return;
    }
    final targetIndex = _findIndexForCurrent(items);
    if (targetIndex != null) {
      _setPagerIndex(targetIndex, useSetState: true);
    }
  }

  int? _findIndexForCurrent(List<FaioContent> items) {
    final byContentId = widget.initialContent?.id;
    if (byContentId != null) {
      final match = items.indexWhere((item) => item.id == byContentId);
      if (match >= 0) {
        return match;
      }
    }
    final matchByNovelId = items.indexWhere(
      (item) => parseContentNumericId(item) == widget.novelId,
    );
    if (matchByNovelId >= 0) {
      return matchByNovelId;
    }
    return null;
  }


  int _novelIdForIndex(List<FaioContent> items, int index) {
    if (index >= 0 && index < items.length) {
      return parseContentNumericId(items[index]) ?? widget.novelId;
    }
    return widget.novelId;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<NovelFeedSelectionState>(
        novelFeedSelectionProvider, (previous, next) {
      if (!mounted) return;
      final selected = next.selectedIndex;
      if (selected != null &&
          selected != _currentIndex &&
          _pageController != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _animateToIndex(selected);
        });
      }
    });

    final feedState = ref.watch(pixivNovelFeedControllerProvider);
    final items = feedState.items;
    if (_pageController == null) {
      _maybeAttachPagerFromFeed(items);
    }

    final hasPager = _pageController != null && items.isNotEmpty;
    final activeContent = hasPager &&
            _currentIndex != null &&
            _currentIndex! >= 0 &&
            _currentIndex! < items.length
        ? items[_currentIndex!]
        : widget.initialContent;
    final activeIndex = _currentIndex;
    final effectiveNovelId = hasPager && activeIndex != null
        ? _novelIdForIndex(items, activeIndex)
        : widget.novelId;
    final titleAsync = ref.watch(novelDetailProvider(effectiveNovelId));
    final fallbackTitle =
        activeContent?.title ?? widget.initialContent?.title ?? '小说详情';
    final currentTitle = titleAsync.maybeWhen(
      data: (detail) => detail.title,
      orElse: () => fallbackTitle,
    );

    final body = hasPager
        ? _buildPager(feedState, items)
        : _NovelDetailPage(
            novelId: widget.novelId,
            initialContent: widget.initialContent,
            onRecordHistory: _recordHistory,
          );

    return WillPopScope(
      onWillPop: () async {
        _requestScrollBack();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            currentTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: body,
      ),
    );
  }

  Widget _buildPager(FeedState feedState, List<FaioContent> items) {
    final controller = _pageController!;
    final currentIndex = _currentIndex ?? widget.initialIndex ?? 0;
    final baseCount = feedState.hasMore ? items.length + 1 : items.length;
    final minCount = math.max(currentIndex + 1, 1);
    final itemCount = math.max(baseCount, minCount);

    return PageView.builder(
      controller: controller,
      onPageChanged: _handlePageChanged,
      itemCount: math.max(1, itemCount),
      itemBuilder: (context, index) {
        if (index >= items.length) {
          if (feedState.hasMore) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              ref
                  .read(pixivNovelFeedControllerProvider.notifier)
                  .ensureIndexLoaded(index);
            });
            return const _NovelDetailLoadingPlaceholder();
          }
          return const _NovelDetailEndPlaceholder();
        }
        final content = items[index];
        final novelId = parseContentNumericId(content) ?? widget.novelId;
        return _NovelDetailPage(
          key: ValueKey(content.id),
          novelId: novelId,
          initialContent: content,
          onRecordHistory: _recordHistory,
        );
      },
    );
  }
}

class _NovelDetailPage extends ConsumerWidget {
  const _NovelDetailPage({
    super.key,
    required this.novelId,
    this.initialContent,
    required this.onRecordHistory,
  });

  final int novelId;
  final FaioContent? initialContent;
  final void Function(FaioContent content, {bool force}) onRecordHistory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(novelDetailProvider(novelId));
    final progressAsync =
        ref.watch(novelReadingProgressProvider(novelId));
    final detail = detailAsync.valueOrNull;
    final historyContent = detail != null
        ? novelDetailToContent(detail, fallback: initialContent)
        : initialContent;
    if (historyContent != null) {
      onRecordHistory(historyContent, force: detail != null);
    }
    final fallbackDetail = initialContent != null
        ? contentToNovelDetail(
            initialContent!,
            novelIdOverride: novelId,
          )
        : null;

    return detailAsync.when(
      data: (detail) => _NovelDetailContent(
        detail: detail,
        initialContent: initialContent,
        novelId: novelId,
        progressAsync: progressAsync,
        favoriteContent: historyContent,
      ),
      loading: () {
        if (fallbackDetail != null) {
          return _NovelDetailContent(
            detail: fallbackDetail,
            initialContent: initialContent,
            novelId: novelId,
            progressAsync: progressAsync,
            favoriteContent: historyContent,
          );
        }
        return _NovelDetailSkeleton(initialContent: initialContent);
      },
      error: (error, stackTrace) => _NovelDetailError(
        message: error.toString(),
        onRetry: () => ref.invalidate(novelDetailProvider(novelId)),
      ),
    );
  }
}

class _NovelDetailLoadingPlaceholder extends StatelessWidget {
  const _NovelDetailLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _NovelDetailEndPlaceholder extends StatelessWidget {
  const _NovelDetailEndPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Text(
          '已经是最后一篇小说啦',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _NovelDetailSkeleton extends StatelessWidget {
  const _NovelDetailSkeleton({this.initialContent});

  final FaioContent? initialContent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initialCoverUrl =
        initialContent?.sampleUrl ?? initialContent?.previewUrl;
    Widget line({
      double height = 14,
      double? width,
      double radius = 8,
    }) {
      return Skeleton.leaf(
        child: Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: theme.colorScheme.surfaceVariant,
          ),
        ),
      );
    }

    return Skeletonizer(
      effect: kFaioSkeletonEffect,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _NovelHeroImage(
              contentId: initialContent?.id,
              lowRes: initialCoverUrl,
              highRes: initialCoverUrl,
              fallbackColor: theme.colorScheme.surfaceVariant,
            ),
            const SizedBox(height: 24),
            line(height: 30, radius: 10),
            const SizedBox(height: 12),
            line(height: 16, width: 160, radius: 10),
            const SizedBox(height: 24),
            ...List.generate(
              4,
              (index) => Padding(
                padding: EdgeInsets.only(bottom: index == 3 ? 0 : 10),
                child: line(),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: line(height: 44, radius: 999),
                ),
                const SizedBox(width: 12),
                line(height: 44, width: 44, radius: 999),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NovelDetailError extends StatelessWidget {
  const _NovelDetailError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '加载失败：$message',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NovelDetailContent extends ConsumerWidget {
  const _NovelDetailContent({
    required this.detail,
    required this.initialContent,
    required this.novelId,
    required this.progressAsync,
    this.favoriteContent,
  });

  final NovelDetail detail;
  final FaioContent? initialContent;
  final int novelId;
  final AsyncValue<NovelReadingProgress?> progressAsync;
  final FaioContent? favoriteContent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final progress = progressAsync.valueOrNull;
    final coverUrl = detail.coverUrl ??
        initialContent?.sampleUrl ??
        initialContent?.previewUrl;
    final authorName =
        detail.authorName ?? initialContent?.authorName ?? '未知作者';
    final summary = detail.description.isNotEmpty
        ? detail.description
        : (initialContent?.summary ?? detail.body);
    final tags = detail.tags.isNotEmpty
        ? detail.tags
        : (initialContent?.tags ?? const []);
    final publishedAt = detail.createdAt ?? initialContent?.publishedAt;
    final favoriteEntry =
        favoriteContent ?? novelDetailToContent(detail, fallback: initialContent);
    final isFavorite = ref.watch(
      libraryFavoritesProvider.select((asyncValue) {
        final entries = asyncValue.valueOrNull;
        if (entries == null) {
          return false;
        }
        return entries.any(
          (entry) => entry.isContent && entry.content!.id == favoriteEntry.id,
        );
      }),
    );
    final primaryLink = favoriteEntry.originalUrl ??
        (favoriteEntry.sourceLinks.isNotEmpty
            ? favoriteEntry.sourceLinks.first
            : null);

    Widget buildHero() {
      final lowResCover =
          initialContent?.previewUrl ?? initialContent?.sampleUrl;
      return _NovelHeroImage(
        contentId: favoriteEntry.id,
        lowRes: lowResCover,
        highRes: coverUrl ?? lowResCover,
        fallbackColor: theme.colorScheme.surfaceVariant,
      );
    }

    Widget buildPrimaryActions() {
      final baseCount = favoriteEntry.favoriteCount;
      final displayCount = baseCount + (isFavorite ? 1 : 0);
      final favoriteLabel =
          '${isFavorite ? '已收藏' : '收藏'}（$displayCount）';
      return Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
              label: Text(favoriteLabel),
              onPressed: () {
                ref
                    .read(libraryFavoritesProvider.notifier)
                    .toggleContentFavorite(favoriteEntry);
              },
            ),
          ),
        ],
      );
    }

    Widget buildTagsCard() {
      return DetailSectionCard(
        title: '标签',
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tags
              .map(
                (tag) => Chip(
                  label: Text(tag),
                  backgroundColor: theme.colorScheme.surfaceVariant,
                ),
              )
              .toList(),
        ),
      );
    }

    Widget buildSourceCard() {
      return DetailSectionCard(
        title: '外部链接',
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: detail.sourceLinks
              .map(
                (link) => OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () => _launchExternal(context, link),
                  label: Text(link.host),
                ),
              )
              .toList(),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(novelDetailProvider(novelId));
        ref.invalidate(novelReadingProgressProvider(novelId));
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          buildHero(),
          if (detail.length != null) ...[
            const SizedBox(height: 12),
            _InfoPill(
              icon: Icons.menu_book,
              label: '${detail.length} 字',
              background: theme.colorScheme.surfaceVariant,
            ),
          ],
          const SizedBox(height: 20),
          Text(
            detail.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '评级：${favoriteEntry.rating.isNotEmpty ? favoriteEntry.rating : 'General'}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            authorName,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          buildPrimaryActions(),
          const SizedBox(height: 16),
          _ReadActionCard(
            detail: detail,
            novelId: novelId,
            progressAsync: progressAsync,
            onReadPressed: () {
              context.push('/feed/novel/$novelId/reader');
            },
            onClearProgress: progress == null
                ? null
                : () async {
                    final storage = ref.read(novelReadingStorageProvider);
                    await storage.clearProgress(novelId);
                    ref.invalidate(
                      novelReadingProgressProvider(novelId),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已清除阅读进度')),
                      );
                    }
                  },
            onRetryProgress: () {
              ref.invalidate(novelReadingProgressProvider(novelId));
            },
            onOpenChapters: detail.series?.isValid ?? false
                ? () => _openNovelChapterSelector(
                      context,
                      detail.series!,
                      novelId,
                    )
                : null,
          ),
          const SizedBox(height: 16),
          DetailSectionCard(
            title: '作品信息',
            child: _MetaInfoSection(
              authorName: authorName,
              publishedAt: publishedAt,
              length: detail.length ?? detail.body.length,
              rating: favoriteEntry.rating,
              readCount: detail.readCount,
            ),
          ),
          const SizedBox(height: 16),
          DetailSectionCard(
            title: '简介',
            child: SelectableText(
              summary.isNotEmpty ? summary : '暂无简介',
              style: theme.textTheme.bodyLarge,
            ),
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            buildTagsCard(),
          ],
          if (detail.series?.isValid ?? false) ...[
            const SizedBox(height: 16),
            _NovelSeriesPreview(
              series: detail.series!,
              currentNovelId: novelId,
            ),
          ],
          if (detail.sourceLinks.isNotEmpty) ...[
            const SizedBox(height: 16),
            buildSourceCard(),
          ],
        ],
      ),
    );
  }

  Future<void> _launchExternal(BuildContext context, Uri url) async {
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开链接：${url.toString()}')),
      );
    }
  }
}

Future<void> _openNovelChapterSelector(
  BuildContext context,
  NovelSeriesOutline series,
  int currentNovelId,
) async {
  final selected = await showNovelSeriesSheet(
    context: context,
    seriesId: series.id,
    currentNovelId: currentNovelId,
  );
  if (selected == null || selected == currentNovelId) {
    return;
  }
  if (!context.mounted) return;
  context.pushReplacement('/feed/novel/$selected');
}

class _ReadActionCard extends StatelessWidget {
  const _ReadActionCard({
    required this.detail,
    required this.novelId,
    required this.progressAsync,
    required this.onReadPressed,
    this.onClearProgress,
    this.onRetryProgress,
    this.onOpenChapters,
  });

  final NovelDetail detail;
  final int novelId;
  final AsyncValue<NovelReadingProgress?> progressAsync;
  final VoidCallback onReadPressed;
  final VoidCallback? onClearProgress;
  final VoidCallback? onRetryProgress;
  final VoidCallback? onOpenChapters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = progressAsync.valueOrNull;
    final hasProgress = progress != null;
    final percent = (progress?.relativeOffset ?? 0).clamp(0.0, 1.0) * 100;
    final formattedPercent = percent.toStringAsFixed(0);
    final onCard = theme.colorScheme.onSurface;
    final onCardMuted = theme.colorScheme.onSurfaceVariant;

    final statusText = hasProgress
        ? '继续阅读 · 已读 $formattedPercent%'
        : '开始阅读 · 还未开始';

    Widget trailingStatus;
    if (progressAsync.isLoading) {
      trailingStatus = const SizedBox(
        key: ValueKey('status-loading'),
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (progressAsync.hasError) {
      trailingStatus = _ReadStatusChip(
        key: const ValueKey('status-error'),
        label: '同步失败',
        icon: Icons.warning_amber_rounded,
        background: theme.colorScheme.errorContainer,
        foreground: theme.colorScheme.onErrorContainer,
      );
    } else if (hasProgress) {
      trailingStatus = _ReadStatusChip(
        key: const ValueKey('status-sync'),
        label: '上次同步 ${_formatRelativeTime(progress!.updatedAt)}',
        foreground: onCardMuted,
      );
    } else {
      trailingStatus = const SizedBox(
        key: ValueKey('status-empty'),
        width: 0,
        height: 0,
      );
    }

    Widget buildProgressVisual() {
      if (progressAsync.hasError) {
        return Column(
          key: const ValueKey('progress-error'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '阅读进度同步失败，请稍后重试',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            if (onRetryProgress != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onRetryProgress,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重新获取进度'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                ),
              ),
            ],
          ],
        );
      }
      if (hasProgress) {
        return Column(
          key: const ValueKey('progress-filled'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
              value: progress!.relativeOffset.clamp(0.0, 1.0),
              minHeight: 6,
              color: theme.colorScheme.primary,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
            ),
            const SizedBox(height: 8),
            Text(
              '已读 $formattedPercent% · 更新于 ${_formatDate(progress.updatedAt)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: onCardMuted,
              ),
            ),
          ],
        );
      }
      return Column(
        key: const ValueKey('progress-empty'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GradientProgressTrack(
            startColor: theme.colorScheme.primary.withOpacity(0.18),
            endColor: theme.colorScheme.primary.withOpacity(0.05),
          ),
          const SizedBox(height: 8),
          Text(
            '还未开始，点击上方开始阅读',
            style: theme.textTheme.bodySmall?.copyWith(
              color: onCardMuted,
            ),
          ),
        ],
      );
    }

    final canClearProgress = hasProgress && onClearProgress != null;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    statusText,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: onCard,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: trailingStatus,
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onReadPressed,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      hasProgress ? '继续阅读' : '开始阅读',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: buildProgressVisual(),
            ),
            if (canClearProgress || onOpenChapters != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (canClearProgress)
                    TextButton.icon(
                      onPressed: onClearProgress,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('清除进度'),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                      ),
                    ),
                  if (onOpenChapters != null)
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: onOpenChapters,
                          icon: const Icon(Icons.view_list_rounded),
                          label: const Text('章节列表'),
                          style: TextButton.styleFrom(
                            foregroundColor: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReadStatusChip extends StatelessWidget {
  const _ReadStatusChip({
    super.key,
    required this.label,
    this.icon,
    this.background,
    this.foreground,
  });

  final String label;
  final IconData? icon;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = background ??
        theme.colorScheme.onSurface.withOpacity(
          theme.brightness == Brightness.dark ? 0.14 : 0.12,
        );
    final fg = foreground ?? theme.colorScheme.onSurface;
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientProgressTrack extends StatelessWidget {
  const _GradientProgressTrack({
    required this.startColor,
    required this.endColor,
  });

  final Color startColor;
  final Color endColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 6,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [startColor, endColor],
          ),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _MetaInfoSection extends StatelessWidget {
  const _MetaInfoSection({
    required this.authorName,
    required this.publishedAt,
    required this.length,
    this.rating,
    this.readCount,
  });

  final String authorName;
  final DateTime? publishedAt;
  final int length;
  final String? rating;
  final int? readCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chips = <Widget>[
      Chip(
        avatar: const Icon(Icons.person, size: 18),
        label: Text(authorName),
      ),
      Chip(
        avatar: const Icon(Icons.schedule, size: 18),
        label: Text(publishedAt != null
            ? _formatDate(publishedAt!)
            : '未知时间'),
      ),
      Chip(
        avatar: const Icon(Icons.text_fields, size: 18),
        label: Text('约 $length 字'),
      ),
      if (rating != null && rating!.isNotEmpty)
        Chip(
          avatar: const Icon(Icons.shield, size: 18),
          label: Text(rating!),
        ),
      if (readCount != null && readCount! > 0)
        Chip(
          avatar: const Icon(Icons.visibility, size: 18),
          label: Text('$readCount 阅读'),
        ),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips,
    );
  }
}

class _NovelSeriesPreview extends ConsumerWidget {
  const _NovelSeriesPreview({
    required this.series,
    required this.currentNovelId,
  });

  final NovelSeriesOutline series;
  final int currentNovelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final seriesAsync = ref.watch(novelSeriesDetailProvider(series.id));
    final seriesFavorite = LibrarySeriesFavorite(
      seriesId: series.id,
      title: series.title.isNotEmpty ? series.title : '未知合集',
    );

    Future<void> openSelector() async {
      final selected = await showNovelSeriesSheet(
        context: context,
        seriesId: series.id,
        currentNovelId: currentNovelId,
      );
      if (selected == null || selected == currentNovelId) {
        return;
      }
      if (!context.mounted) return;
      context.pushReplacement('/feed/novel/$selected');
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    series.title.isNotEmpty ? series.title : '所属系列',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FavoriteIconButton.series(
                  series: seriesFavorite,
                  backgroundColor: Colors.transparent,
                  iconSize: 22,
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: openSelector,
                  child: const Text('查看选集'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            seriesAsync.when(
              data: (detail) {
                if (detail == null || detail.novels.isEmpty) {
                  return const Text('暂无章节列表');
                }
                final preview = detail.novels.take(3).toList();
                return Column(
                  children: preview
                      .map(
                        (entry) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            entry.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          leading: Icon(
                            entry.id == currentNovelId
                                ? Icons.play_arrow
                                : Icons.menu_book_outlined,
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            if (entry.id == currentNovelId) {
                              await openSelector();
                              return;
                            }
                            if (!context.mounted) return;
                            context.pushReplacement(
                              '/feed/novel/${entry.id}',
                            );
                          },
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),
              error: (error, stackTrace) => Text(
                '系列加载失败：$error',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime dateTime) {
  final local = dateTime.toLocal();
  final two = (int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

String _formatRelativeTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  final now = DateTime.now();
  final diff = now.difference(local);
  if (diff.isNegative) {
    return '刚刚';
  }
  if (diff.inMinutes < 1) {
    return '刚刚';
  }
  if (diff.inHours < 1) {
    return '${diff.inMinutes} 分钟前';
  }
  if (diff.inDays < 1) {
    return '${diff.inHours} 小时前';
  }
  if (diff.inDays < 7) {
    return '${diff.inDays} 天前';
  }
  if (diff.inDays < 30) {
    final weeks = (diff.inDays / 7).floor();
    return '$weeks 周前';
  }
  if (diff.inDays < 365) {
    final months = (diff.inDays / 30).floor();
    return '$months 个月前';
  }
  final years = (diff.inDays / 365).floor();
  return '$years 年前';
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    this.background,
  });

  final IconData icon;
  final String label;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background ??
            theme.colorScheme.surfaceVariant.withOpacity(
              theme.brightness == Brightness.dark ? 0.7 : 0.9,
            ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.onSurface),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NovelHeroImage extends StatelessWidget {
  const _NovelHeroImage({
    required this.contentId,
    this.lowRes,
    this.highRes,
    this.fallbackColor,
  });

  final String? contentId;
  final Uri? lowRes;
  final Uri? highRes;
  final Color? fallbackColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget child;
    if (lowRes == null && highRes == null) {
      child = Container(
        height: 260,
        decoration: BoxDecoration(
          color: fallbackColor ?? theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(24),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.menu_book_outlined,
          size: 48,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    } else {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: AspectRatio(
          aspectRatio: 0.75,
          child: _ProgressiveNovelImage(
            lowRes: lowRes,
            highRes: highRes,
            fallbackColor: fallbackColor ?? theme.colorScheme.surfaceVariant,
          ),
        ),
      );
    }

    if (contentId == null) {
      return child;
    }

    return Hero(
      tag: novelHeroTag(contentId!),
      transitionOnUserGestures: true,
      createRectTween: novelHeroRectTween,
      child: child,
    );
  }
}

class _ProgressiveNovelImage extends StatefulWidget {
  const _ProgressiveNovelImage({
    this.lowRes,
    this.highRes,
    required this.fallbackColor,
  });

  final Uri? lowRes;
  final Uri? highRes;
  final Color fallbackColor;

  @override
  State<_ProgressiveNovelImage> createState() => _ProgressiveNovelImageState();
}

class _ProgressiveNovelImageState extends State<_ProgressiveNovelImage> {
  bool _highResLoaded = false;

  @override
  void didUpdateWidget(covariant _ProgressiveNovelImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highRes?.toString() != oldWidget.highRes?.toString()) {
      _highResLoaded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final layers = <Widget>[
      Positioned.fill(
        child: widget.lowRes != null
            ? Image(
                image: CachedNetworkImageProvider(
                  widget.lowRes.toString(),
                  headers: imageHeadersForUrl(widget.lowRes),
                ),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: widget.fallbackColor,
                ),
              )
            : Container(color: widget.fallbackColor),
      ),
    ];

    if (widget.highRes != null) {
      layers.add(
        Positioned.fill(
          child: AnimatedOpacity(
            opacity: _highResLoaded ? 1 : 0,
            duration: const Duration(milliseconds: 320),
            child: Image(
              image: CachedNetworkImageProvider(
                widget.highRes.toString(),
                headers: imageHeadersForUrl(widget.highRes),
              ),
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null && !_highResLoaded) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    setState(() => _highResLoaded = true);
                  });
                }
                return child;
              },
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
      );
    }

    layers.add(
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withOpacity(0.35),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: layers,
    );
  }
}
