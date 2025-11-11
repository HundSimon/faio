import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:faio/domain/models/content_item.dart';
import 'package:faio/domain/utils/content_id.dart';

import '../../novel/presentation/widgets/novel_series_sheet.dart';
import '../domain/library_entries.dart';
import '../providers/library_providers.dart';
import 'widgets/favorite_icon_button.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(libraryFavoritesProvider);
    final historyAsync = ref.watch(libraryHistoryProvider);

    Future<void> refresh() async {
      await Future.wait([
        ref.refresh(libraryFavoritesProvider.future),
        ref.refresh(libraryHistoryProvider.future),
      ]);
    }

    final hasHistory = historyAsync.valueOrNull?.isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('库'),
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _SectionContainer(
              title: '收藏',
              child: favoritesAsync.when(
                data: (entries) => _FavoritesSection(entries: entries),
                loading: () => const _SectionLoading(),
                error: (error, stackTrace) =>
                    _SectionError(message: error.toString()),
              ),
            ),
            const SizedBox(height: 32),
            _SectionContainer(
              title: '浏览记录',
              trailing: hasHistory
                  ? TextButton(
                      onPressed: () {
                        ref.read(libraryHistoryProvider.notifier).clearHistory();
                      },
                      child: const Text('清除'),
                    )
                  : null,
              child: historyAsync.when(
                data: (entries) => _HistorySection(entries: entries),
                loading: () => const _SectionLoading(),
                error: (error, stackTrace) =>
                    _SectionError(message: error.toString()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoritesSection extends StatelessWidget {
  const _FavoritesSection({required this.entries});

  final List<LibraryFavoriteEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const _EmptyHint(message: '还没有收藏内容，去信息流点爱心吧');
    }

    final contentFavorites = entries
        .where((entry) => entry.isContent)
        .map((entry) => entry.content!)
        .toList();
    final seriesFavorites = entries
        .where((entry) => entry.isSeries)
        .map((entry) => entry.series!)
        .toList();

    final children = <Widget>[];

    if (contentFavorites.isNotEmpty) {
      for (var i = 0; i < contentFavorites.length; i++) {
        if (i > 0) {
          children.add(const SizedBox(height: 12));
        }
        final content = contentFavorites[i];
        children.add(
          _LibraryContentTile(
            content: content,
            showFavoriteToggle: true,
            onTap: () => _openContent(context, content),
          ),
        );
      }
    }

    if (seriesFavorites.isNotEmpty) {
      if (contentFavorites.isNotEmpty) {
        children.add(const SizedBox(height: 16));
      }
      children.add(
        Text(
          '小说合集',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      );
      children.add(const SizedBox(height: 8));
      for (var i = 0; i < seriesFavorites.length; i++) {
        if (i > 0) {
          children.add(const SizedBox(height: 12));
        }
        final series = seriesFavorites[i];
        children.add(
          _LibrarySeriesTile(
            series: series,
            onTap: () => _openSeries(context, series),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({required this.entries});

  final List<LibraryHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const _EmptyHint(message: '最近浏览的内容会出现在这里');
    }
    return Column(
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _LibraryContentTile(
            content: entries[i].content,
            viewedAt: entries[i].viewedAt,
            onTap: () => _openContent(context, entries[i].content),
          ),
        ],
      ],
    );
  }
}

class _LibraryContentTile extends StatelessWidget {
  const _LibraryContentTile({
    required this.content,
    required this.onTap,
    this.viewedAt,
    this.showFavoriteToggle = false,
  });

  final FaioContent content;
  final VoidCallback onTap;
  final DateTime? viewedAt;
  final bool showFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metaParts = [
      _typeLabel(content.type),
      content.source,
      if (content.authorName != null && content.authorName!.isNotEmpty)
        content.authorName!,
    ];
    final meta = metaParts.where((part) => part.trim().isNotEmpty).join(' · ');
    final summary = content.summary.trim().isNotEmpty
        ? content.summary.trim()
        : (content.tags.isNotEmpty ? content.tags.join(', ') : '暂无简介');

    return Material(
      color: theme.colorScheme.surfaceVariant.withOpacity(
        theme.brightness == Brightness.dark ? 0.35 : 0.5,
      ),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ContentThumbnail(content: content),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      content.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      meta,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (viewedAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '浏览于 ${_formatDate(viewedAt!)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (showFavoriteToggle) ...[
                const SizedBox(width: 8),
                FavoriteIconButton.content(
                  content: content,
                  backgroundColor: Colors.transparent,
                  padding: EdgeInsets.zero,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LibrarySeriesTile extends StatelessWidget {
  const _LibrarySeriesTile({required this.series, required this.onTap});

  final LibrarySeriesFavorite series;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceVariant.withOpacity(
        theme.brightness == Brightness.dark ? 0.35 : 0.45,
      ),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.collections_bookmark,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      series.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (series.caption != null &&
                        series.caption!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        series.caption!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              FavoriteIconButton.series(
                series: series,
                backgroundColor: Colors.transparent,
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionContainer extends StatelessWidget {
  const _SectionContainer({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _SectionLoading extends StatelessWidget {
  const _SectionLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 120,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _SectionError extends StatelessWidget {
  const _SectionError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Center(
        child: Text(
          '加载失败：$message',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surfaceVariant.withOpacity(
          theme.brightness == Brightness.dark ? 0.24 : 0.4,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ContentThumbnail extends StatefulWidget {
  const _ContentThumbnail({required this.content});

  final FaioContent content;

  @override
  State<_ContentThumbnail> createState() => _ContentThumbnailState();
}

class _ContentThumbnailState extends State<_ContentThumbnail> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final preview =
        widget.content.previewUrl ??
        widget.content.sampleUrl ??
        widget.content.originalUrl;
    final theme = Theme.of(context);
    final placeholder = Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Icon(
        widget.content.type == ContentType.novel
            ? Icons.menu_book_outlined
            : Icons.image_outlined,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );

    if (preview == null) {
      return placeholder;
    }
    final urls = _imageUrlCandidates(preview);
    final headers = _imageHeadersFor(widget.content, url: preview);
    final currentUrl = urls[_index];

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 72,
        height: 72,
        child: Image.network(
          currentUrl.toString(),
          fit: BoxFit.cover,
          headers: headers,
          errorBuilder: (context, error, stackTrace) {
            if (_index < urls.length - 1) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() {
                  _index += 1;
                });
              });
              return const SizedBox.shrink();
            }
            return placeholder;
          },
        ),
      ),
    );
  }
}

class _LibraryContentPreview extends StatelessWidget {
  const _LibraryContentPreview({required this.content});

  final FaioContent content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview =
        content.sampleUrl ?? content.previewUrl ?? content.originalUrl;
    final summary = content.summary.trim().isNotEmpty
        ? content.summary
        : '暂无简介';
    final tags = content.tags;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              content.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (preview != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio:
                      (content.previewAspectRatio ?? 1).clamp(0.5, 1.6).toDouble(),
                  child: _PreviewImage(content: content, url: preview),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              summary,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            Text(
              '来源：${content.source}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (content.authorName != null &&
                content.authorName!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '作者：${content.authorName}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (tags.isNotEmpty)
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
            if (content.sourceLinks.isNotEmpty ||
                content.originalUrl != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.open_in_new),
                onPressed: () {
                  final target = content.originalUrl ??
                      content.sourceLinks.firstOrNull;
                  if (target != null) {
                    _launchExternal(context, target);
                  }
                },
                label: const Text('打开原站'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PreviewImage extends StatefulWidget {
  const _PreviewImage({required this.content, required this.url});

  final FaioContent content;
  final Uri url;

  @override
  State<_PreviewImage> createState() => _PreviewImageState();
}

class _PreviewImageState extends State<_PreviewImage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final urls = _imageUrlCandidates(widget.url);
    final headers = _imageHeadersFor(widget.content, url: widget.url);
    final theme = Theme.of(context);

    return Image.network(
      urls[_index].toString(),
      fit: BoxFit.cover,
      headers: headers,
      errorBuilder: (context, error, stackTrace) {
        if (_index < urls.length - 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _index += 1);
          });
          return const SizedBox.shrink();
        }
        return Container(
          color: theme.colorScheme.surfaceVariant,
          alignment: Alignment.center,
          child: Icon(
            Icons.broken_image,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        );
      },
    );
  }
}

Future<void> _openContent(BuildContext context, FaioContent content) async {
  if (content.type == ContentType.novel) {
    final novelId = parseContentNumericId(content);
    if (novelId == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('无法解析小说 ID')),
      );
      return;
    }
    context.push('/feed/novel/$novelId', extra: content);
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _LibraryContentPreview(content: content),
  );
}

Future<void> _openSeries(
  BuildContext context,
  LibrarySeriesFavorite series,
) async {
  final selected = await showNovelSeriesSheet(
    context: context,
    seriesId: series.seriesId,
  );
  if (selected == null) {
    return;
  }
  context.push('/feed/novel/$selected');
}

Future<void> _launchExternal(BuildContext context, Uri url) async {
  if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text('无法打开链接：${url.toString()}')),
    );
  }
}

String _typeLabel(ContentType type) {
  switch (type) {
    case ContentType.illustration:
      return '插画';
    case ContentType.comic:
      return '漫画';
    case ContentType.novel:
      return '小说';
    case ContentType.audio:
      return '音频';
  }
}

String _formatDate(DateTime dateTime) {
  final local = dateTime.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

const _pixivFallbackHosts = ['i.pixiv.cat', 'i.pixiv.re', 'i.pixiv.nl'];

Map<String, String>? _imageHeadersFor(FaioContent content, {Uri? url}) {
  final resolved = url ?? content.previewUrl ?? content.sampleUrl;
  final host = resolved?.host.toLowerCase();
  final source = content.source.toLowerCase();

  if (host != null && host.endsWith('pximg.net')) {
    return const {
      'Referer': 'https://www.pixiv.net/',
      'User-Agent': 'PixivAndroidApp/5.0.234 (Android 11; Pixel 5)',
    };
  }

  if (source.startsWith('pixiv')) {
    return const {
      'Referer': 'https://app-api.pixiv.net/',
      'User-Agent': 'PixivAndroidApp/5.0.234 (Android 11; Pixel 5)',
    };
  }

  return null;
}

List<Uri> _imageUrlCandidates(Uri url) {
  final candidates = <Uri>[url];
  final host = url.host.toLowerCase();
  if (host == 'i.pximg.net') {
    for (final fallback in _pixivFallbackHosts) {
      final replacement = url.replace(host: fallback);
      final exists = candidates.any(
        (existing) => existing.toString() == replacement.toString(),
      );
      if (!exists) {
        candidates.add(replacement);
      }
    }
  }
  return candidates;
}

extension FirstOrNullExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : this[0];
}
