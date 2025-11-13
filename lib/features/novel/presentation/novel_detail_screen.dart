import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:faio/domain/models/content_item.dart';
import 'package:faio/domain/models/novel_detail.dart';
import 'package:faio/domain/models/novel_reader.dart';
import 'package:faio/features/common/widgets/detail_section_card.dart';
import 'package:faio/features/common/widgets/skeleton_theme.dart';
import 'package:faio/features/library/domain/library_entries.dart';
import 'package:faio/features/library/providers/library_providers.dart';
import 'package:faio/features/library/utils/library_mappers.dart';
import 'package:faio/features/library/presentation/widgets/favorite_icon_button.dart';
import 'package:faio/features/novel/presentation/novel_hero.dart';

import '../providers/novel_providers.dart';
import 'widgets/novel_image.dart';
import 'widgets/novel_series_sheet.dart';

class NovelDetailScreen extends ConsumerStatefulWidget {
  const NovelDetailScreen({
    required this.novelId,
    this.initialContent,
    super.key,
  });

  final int novelId;
  final FaioContent? initialContent;

  @override
  ConsumerState<NovelDetailScreen> createState() => _NovelDetailScreenState();
}

class _NovelDetailScreenState extends ConsumerState<NovelDetailScreen> {
  String? _lastRecordedContentId;

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

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(novelDetailProvider(widget.novelId));
    final progressAsync =
        ref.watch(novelReadingProgressProvider(widget.novelId));
    final title = detailAsync.maybeWhen(
      data: (detail) => detail.title,
      orElse: () => widget.initialContent?.title ?? '小说详情',
    );
    final detail = detailAsync.valueOrNull;
    final historyContent = detail != null
        ? novelDetailToContent(detail, fallback: widget.initialContent)
        : widget.initialContent;
    if (historyContent != null) {
      _recordHistory(historyContent, force: detail != null);
    }
    final fallbackDetail = widget.initialContent != null
        ? contentToNovelDetail(
            widget.initialContent!,
            novelIdOverride: widget.novelId,
          )
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: detailAsync.when(
        data: (detail) => _NovelDetailContent(
          detail: detail,
          initialContent: widget.initialContent,
          novelId: widget.novelId,
          progressAsync: progressAsync,
          favoriteContent: historyContent,
        ),
        loading: () {
          if (fallbackDetail != null) {
            return _NovelDetailContent(
              detail: fallbackDetail,
              initialContent: widget.initialContent,
              novelId: widget.novelId,
              progressAsync: progressAsync,
              favoriteContent: widget.initialContent,
            );
          }
          return _NovelDetailSkeleton(initialContent: widget.initialContent);
        },
        error: (error, stackTrace) => _NovelDetailError(
          message: error.toString(),
          onRetry: () => ref.invalidate(novelDetailProvider(widget.novelId)),
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
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: Text(primaryLink == null ? '暂无外链' : '打开原站'),
              onPressed: primaryLink == null
                  ? null
                  : () => _launchExternal(context, primaryLink),
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

class _ReadActionCard extends StatelessWidget {
  const _ReadActionCard({
    required this.detail,
    required this.novelId,
    required this.progressAsync,
    required this.onReadPressed,
    this.onClearProgress,
  });

  final NovelDetail detail;
  final int novelId;
  final AsyncValue<NovelReadingProgress?> progressAsync;
  final VoidCallback onReadPressed;
  final VoidCallback? onClearProgress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = progressAsync.valueOrNull;
    final percent =
        (progress?.relativeOffset ?? 0) * 100;
    final formattedPercent = percent.toStringAsFixed(0);

    return Card(
      color: theme.colorScheme.surfaceVariant,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilledButton.icon(
              onPressed: onReadPressed,
              icon: const Icon(Icons.menu_book),
              label: Text(
                progress == null ? '开始阅读' : '继续阅读（已读 $formattedPercent%）',
              ),
            ),
            if (progressAsync.isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              )
            else if (progressAsync.hasError) ...[
              const SizedBox(height: 8),
              Text(
                '无法获取阅读进度',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ]
            else if (progress != null) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progress.relativeOffset.clamp(0.0, 1.0),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '上次阅读：'
                    '${_formatDate(progress.updatedAt)}',
                    style: theme.textTheme.bodySmall,
                  ),
                  TextButton(
                    onPressed: onClearProgress,
                    child: const Text('清除进度'),
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
