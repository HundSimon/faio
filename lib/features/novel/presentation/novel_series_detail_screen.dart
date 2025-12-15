import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:faio/data/pixiv/pixiv_image_cache.dart';
import 'package:faio/domain/utils/pixiv_image_utils.dart';
import 'package:faio/features/common/widgets/categorized_tags.dart';
import 'package:faio/features/common/widgets/detail_section_card.dart';
import 'package:faio/features/library/domain/library_entries.dart';
import 'package:faio/features/library/providers/library_providers.dart';
import 'package:faio/features/novel/providers/novel_providers.dart';

import 'widgets/novel_image.dart';

class NovelSeriesDetailScreen extends ConsumerWidget {
  const NovelSeriesDetailScreen({
    required this.seriesId,
    this.currentNovelId,
    this.replaceOnSelect = false,
    super.key,
  });

  final int seriesId;
  final int? currentNovelId;
  final bool replaceOnSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final seriesAsync = ref.watch(novelSeriesDetailProvider(seriesId));
    final title = seriesAsync.maybeWhen(
      data: (detail) => detail?.title,
      orElse: () => null,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title?.trim().isNotEmpty == true ? title!.trim() : '系列详情',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: seriesAsync.when(
        data: (detail) {
          if (detail == null) {
            return const Center(child: Text('未找到系列信息'));
          }

          final firstNovelId = detail.novels.isNotEmpty
              ? detail.novels.first.id
              : null;
          final firstNovelAsync = firstNovelId != null
              ? ref.watch(novelDetailProvider(firstNovelId))
              : null;
          final firstNovel = firstNovelAsync?.valueOrNull;

          final seriesFavorite = LibrarySeriesFavorite(
            seriesId: detail.id,
            title: detail.title.trim().isNotEmpty
                ? detail.title.trim()
                : '未知合集',
            caption: detail.caption.trim().isNotEmpty
                ? detail.caption.trim()
                : null,
            coverUrl: detail.novels.isNotEmpty
                ? detail.novels.first.coverUrl
                : null,
            source: firstNovel?.source ?? 'furrynovel',
            authorName: firstNovel?.authorName,
            authorId: firstNovel?.authorId,
          );
          final authorName =
              seriesFavorite.authorName?.trim().isNotEmpty == true
              ? seriesFavorite.authorName!.trim()
              : '未知作者';
          final isFavorite = ref.watch(
            libraryFavoritesProvider.select((asyncValue) {
              final entries = asyncValue.valueOrNull;
              if (entries == null) return false;
              return entries.any(
                (entry) =>
                    entry.isSeries &&
                    entry.series!.seriesId == seriesFavorite.seriesId,
              );
            }),
          );
          final primaryLink = _primarySeriesLink(seriesFavorite);
          final lastReadNovelId = currentNovelId == null
              ? ref.watch(lastReadNovelInSeriesProvider(seriesId)).valueOrNull
              : null;
          final highlightedNovelId = currentNovelId ?? lastReadNovelId;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _SeriesHeaderSection(
                series: seriesFavorite,
                authorName: authorName,
                chaptersCount: detail.novels.length,
              ),
              const SizedBox(height: 12),
              _SeriesFavoriteCard(
                series: seriesFavorite,
                isFavorite: isFavorite,
                primaryLink: primaryLink,
                onOpenLink: (url) => _launchExternal(context, url),
              ),
              if (seriesFavorite.caption != null) ...[
                const SizedBox(height: 16),
                DetailSectionCard(
                  title: '简介',
                  child: SelectableText(
                    seriesFavorite.caption!,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
                  ),
                ),
              ],
              if (detail.tags.isNotEmpty) ...[
                const SizedBox(height: 16),
                DetailSectionCard(
                  title: '标签',
                  child: CategorizedTagList(tags: detail.tags),
                ),
              ],
              const SizedBox(height: 16),
              DetailSectionCard(
                title: '章节',
                child: detail.novels.isEmpty
                    ? const Text('暂无章节列表')
                    : Column(
                        children: [
                          for (final entry in detail.novels)
                            _SeriesEntryTile(
                              novelId: entry.id,
                              title: entry.title,
                              coverUrl: entry.coverUrl,
                              isCurrent: highlightedNovelId == entry.id,
                              onTap: () {
                                final path = '/feed/novel/${entry.id}';
                                if (replaceOnSelect) {
                                  context.pushReplacement(path);
                                } else {
                                  context.push(path);
                                }
                              },
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('系列加载失败：$error', textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }

  Uri? _primarySeriesLink(LibrarySeriesFavorite series) {
    if (series.seriesId <= 0) return null;
    return Uri.parse('https://www.pixiv.net/novel/series/${series.seriesId}');
  }

  Future<void> _launchExternal(BuildContext context, Uri url) async {
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无法打开链接：${url.toString()}')));
    }
  }
}

class _SeriesHeaderSection extends StatelessWidget {
  const _SeriesHeaderSection({
    required this.series,
    required this.authorName,
    required this.chaptersCount,
  });

  final LibrarySeriesFavorite series;
  final String authorName;
  final int chaptersCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 520;
            final coverWidth = math.min(
              constraints.maxWidth * (isCompact ? 0.42 : 0.32),
              220.0,
            );
            final cover = SizedBox(
              width: coverWidth,
              child: _SeriesHeroImage(
                coverUrl: series.coverUrl,
                height: isCompact ? null : 220,
                aspectRatio: 0.68,
              ),
            );

            final infoSpacing = isCompact ? 12.0 : 24.0;
            final statPills = <Widget>[
              _InfoPill(
                icon: Icons.menu_book_outlined,
                label: '$chaptersCount 章',
              ),
              if (series.source != null && series.source!.trim().isNotEmpty)
                _InfoPill(icon: Icons.public, label: series.source!.trim()),
            ];

            Widget buildInfoColumn() {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    series.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    authorName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              );
            }

            Widget? buildBadgesRow() {
              if (statPills.isEmpty) return null;
              return Padding(
                padding: EdgeInsets.only(top: isCompact ? 12 : 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  child: Row(
                    children: [
                      for (var i = 0; i < statPills.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        statPills[i],
                      ],
                    ],
                  ),
                ),
              );
            }

            final badgesRow = buildBadgesRow();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    cover,
                    SizedBox(width: infoSpacing),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: infoSpacing),
                        child: buildInfoColumn(),
                      ),
                    ),
                  ],
                ),
                if (badgesRow != null) badgesRow,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SeriesFavoriteCard extends ConsumerWidget {
  const _SeriesFavoriteCard({
    required this.series,
    required this.isFavorite,
    required this.primaryLink,
    required this.onOpenLink,
  });

  final LibrarySeriesFavorite series;
  final bool isFavorite;
  final Uri? primaryLink;
  final ValueChanged<Uri> onOpenLink;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    key: ValueKey(isFavorite),
                  ),
                ),
                label: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Text(
                    isFavorite ? '已收藏' : '收藏',
                    key: ValueKey(isFavorite),
                  ),
                ),
                onPressed: () {
                  ref
                      .read(libraryFavoritesProvider.notifier)
                      .toggleSeriesFavorite(series);
                },
              ),
            ),
            if (primaryLink != null) ...[
              const SizedBox(width: 12),
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('查看原站'),
                  onPressed: () => onOpenLink(primaryLink!),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.7 : 0.9,
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

class _SeriesHeroImage extends StatelessWidget {
  const _SeriesHeroImage({
    required this.coverUrl,
    this.height,
    this.aspectRatio,
  });

  final Uri? coverUrl;
  final double? height;
  final double? aspectRatio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedAspectRatio = aspectRatio ?? 0.75;
    final url = coverUrl;
    Widget child;
    if (url == null) {
      child = Container(
        height: height ?? 260,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.collections_bookmark_outlined,
          size: 48,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    } else {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: AspectRatio(
          aspectRatio: resolvedAspectRatio,
          child: Image(
            image: CachedNetworkImageProvider(
              url.toString(),
              headers: pixivImageHeaders(url: url),
              cacheManager: pixivImageCacheManagerForUrl(url),
            ),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: theme.colorScheme.surfaceContainerHighest,
              alignment: Alignment.center,
              child: Icon(
                Icons.collections_bookmark_outlined,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
      if (height != null) {
        child = SizedBox(height: height, child: child);
      }
    }
    return child;
  }
}

class _SeriesEntryTile extends StatelessWidget {
  const _SeriesEntryTile({
    required this.novelId,
    required this.title,
    required this.coverUrl,
    required this.isCurrent,
    required this.onTap,
  });

  final int novelId;
  final String title;
  final Uri? coverUrl;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlightColor = theme.colorScheme.primary.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.14 : 0.08,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: isCurrent ? highlightColor : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                _SeriesCoverThumbnail(coverUrl: coverUrl, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: isCurrent
                        ? theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          )
                        : theme.textTheme.bodyLarge,
                  ),
                ),
                const SizedBox(width: 8),
                isCurrent
                    ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                    : const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SeriesCoverThumbnail extends StatelessWidget {
  const _SeriesCoverThumbnail({required this.coverUrl, this.size = 72});

  final Uri? coverUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.collections_bookmark_outlined,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );

    if (coverUrl == null) {
      return placeholder;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: size,
        height: size,
        child: ResilientNetworkImage(
          urls: pixivImageUrlCandidates(coverUrl!),
          headers: pixivImageHeaders(url: coverUrl),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder,
        ),
      ),
    );
  }
}
