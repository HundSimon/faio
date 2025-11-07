import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:faio/domain/models/content_item.dart';
import 'package:faio/domain/models/novel_detail.dart';
import 'package:faio/domain/models/novel_reader.dart';

import '../providers/novel_providers.dart';
import 'widgets/novel_image.dart';
import 'widgets/novel_series_sheet.dart';

class NovelDetailScreen extends ConsumerWidget {
  const NovelDetailScreen({
    required this.novelId,
    this.initialContent,
    super.key,
  });

  final int novelId;
  final FaioContent? initialContent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(novelDetailProvider(novelId));
    final progressAsync = ref.watch(novelReadingProgressProvider(novelId));
    final title = detailAsync.maybeWhen(
      data: (detail) => detail.title,
      orElse: () => initialContent?.title ?? '小说详情',
    );

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
          initialContent: initialContent,
          novelId: novelId,
          progressAsync: progressAsync,
        ),
        loading: () => _NovelDetailSkeleton(initialContent: initialContent),
        error: (error, stackTrace) => _NovelDetailError(
          message: error.toString(),
          onRetry: () => ref.invalidate(novelDetailProvider(novelId)),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: const CircularProgressIndicator(),
          ),
          const SizedBox(height: 24),
          Text(
            initialContent?.title ?? '正在加载小说详情…',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            initialContent?.summary ?? '请稍候，正在获取最新内容',
            style: theme.textTheme.bodyLarge,
          ),
        ],
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
  });

  final NovelDetail detail;
  final FaioContent? initialContent;
  final int novelId;
  final AsyncValue<NovelReadingProgress?> progressAsync;

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

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(novelDetailProvider(novelId));
        ref.invalidate(novelReadingProgressProvider(novelId));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CoverSection(
              coverUrl: coverUrl,
              detail: detail,
              authorName: authorName,
              summary: summary,
            ),
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
            _MetaInfoSection(
              authorName: authorName,
              publishedAt: publishedAt,
              length: detail.length ?? detail.body.length,
              rating: initialContent?.rating,
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 16),
              _TagsSection(tags: tags),
            ],
            const SizedBox(height: 24),
            Text(
              '简介',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              summary.isNotEmpty ? summary : '暂无简介',
              style: theme.textTheme.bodyLarge,
            ),
            if (detail.series?.isValid ?? false) ...[
              const SizedBox(height: 24),
              _NovelSeriesPreview(
                series: detail.series!,
                currentNovelId: novelId,
              ),
            ],
            if (detail.sourceLinks.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                '外部链接',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
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
            ],
          ],
        ),
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

class _CoverSection extends StatelessWidget {
  const _CoverSection({
    required this.coverUrl,
    required this.detail,
    required this.authorName,
    required this.summary,
  });

  final Uri? coverUrl;
  final NovelDetail detail;
  final String authorName;
  final String summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placeholder = Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surfaceVariant,
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.menu_book_outlined,
        color: theme.colorScheme.onSurfaceVariant,
        size: 48,
      ),
    );

    Widget buildImage() {
      final cover = coverUrl;
      if (cover == null) {
        return placeholder;
      }
      final urls = imageUrlCandidates(cover);
      final headers = imageHeadersForUrl(cover);
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 220,
          width: double.infinity,
          child: ResilientNetworkImage(
            urls: urls,
            headers: headers,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => placeholder,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildImage(),
        const SizedBox(height: 16),
        Text(
          detail.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          authorName,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          summary,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
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
  });

  final String authorName;
  final DateTime? publishedAt;
  final int length;
  final String? rating;

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
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips,
    );
  }
}

class _TagsSection extends StatelessWidget {
  const _TagsSection({required this.tags});

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '标签',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
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
      ],
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
