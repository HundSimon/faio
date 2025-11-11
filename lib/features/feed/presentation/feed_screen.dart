import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:faio/domain/models/content_item.dart';
import 'package:faio/domain/utils/content_id.dart';

import '../providers/feed_providers.dart';

const _pixivFallbackHosts = ['i.pixiv.cat', 'i.pixiv.re', 'i.pixiv.nl'];

Map<String, String>? _imageHeadersFor(FaioContent item, {Uri? url}) {
  final resolvedUrl =
      url ?? item.previewUrl ?? item.sampleUrl ?? item.originalUrl;
  final host = resolvedUrl?.host.toLowerCase();
  final source = item.source.toLowerCase();

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
    for (final fallbackHost in _pixivFallbackHosts) {
      final candidate = url.replace(host: fallbackHost);
      final alreadyExists = candidates.any(
        (existing) => existing.toString() == candidate.toString(),
      );
      if (!alreadyExists) {
        candidates.add(candidate);
      }
    }
  }
  return candidates;
}

class _ResilientNetworkImage extends StatefulWidget {
  const _ResilientNetworkImage({
    required this.urls,
    this.headers,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.errorBuilder,
  }) : assert(urls.length > 0, 'urls must not be empty');

  final List<Uri> urls;
  final Map<String, String>? headers;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  @override
  State<_ResilientNetworkImage> createState() => _ResilientNetworkImageState();
}

class _ResilientNetworkImageState extends State<_ResilientNetworkImage> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final currentUrl = widget.urls[_index].toString();
    return Image.network(
      currentUrl,
      fit: widget.fit,
      alignment: widget.alignment,
      headers: widget.headers,
      errorBuilder: (context, error, stackTrace) {
        if (_index < widget.urls.length - 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _index += 1;
            });
          });
          return const SizedBox.expand();
        }
        final builder = widget.errorBuilder;
        if (builder != null) {
          return builder(context, error, stackTrace);
        }
        return const SizedBox.expand();
      },
    );
  }
}

Future<void> _showAllTags(BuildContext context, List<String> tags) async {
  if (tags.isEmpty) {
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '全部标签',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    },
  );
}

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('信息流'),
          bottom: const TabBar(
            isScrollable: false,
            indicatorSize: TabBarIndicatorSize.tab,
            tabAlignment: TabAlignment.fill,
            tabs: [
              Tab(text: 'AIO'),
              Tab(text: '插画'),
              Tab(text: '漫画'),
              Tab(text: '小说'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ComingSoonTab(message: 'AIO 聚合体验开发中'),
            _IllustrationTab(),
            _MangaTab(),
            _NovelTab(),
          ],
        ),
      ),
    );
  }
}

class _IllustrationTab extends ConsumerStatefulWidget {
  const _IllustrationTab();

  @override
  ConsumerState<_IllustrationTab> createState() => _IllustrationTabState();
}

class _IllustrationTabState extends ConsumerState<_IllustrationTab> {
  static const _horizontalPadding = 16.0;
  static const _verticalPadding = 16.0;
  static const _crossAxisSpacing = 12.0;
  static const _mainAxisSpacing = 12.0;
  static const _crossAxisCount = 2;

  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      ref.read(feedControllerProvider.notifier).loadMore();
    }
  }

  Future<void> _scrollToIndex(int index) async {
    if (!_scrollController.hasClients) {
      return;
    }
    final width = context.size?.width ?? MediaQuery.of(context).size.width;
    final gridWidth =
        width -
        (_horizontalPadding * 2) -
        (_crossAxisSpacing * (_crossAxisCount - 1));
    final tileWidth = gridWidth / _crossAxisCount;
    final tileHeight = tileWidth;
    final rowHeight = tileHeight + _mainAxisSpacing;
    final row = index ~/ _crossAxisCount;
    final targetOffset =
        _verticalPadding + row * rowHeight - (_mainAxisSpacing / 2);

    final maxScroll = _scrollController.position.maxScrollExtent;
    final clampedOffset = targetOffset.clamp(0.0, maxScroll);

    await _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<FeedState>(feedControllerProvider, (previous, next) {
      if (!mounted) return;
      final previousError = previous?.lastError;
      if (next.lastError != null && next.lastError != previousError) {
        final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
        scaffoldMessenger?.showSnackBar(
          SnackBar(content: Text('加载内容失败：${next.lastError}')),
        );
      }
    });

    ref.listen<FeedSelectionState>(feedSelectionProvider, (previous, next) {
      if (!mounted) return;
      final targetIndex = next.pendingScrollIndex;
      if (targetIndex != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToIndex(targetIndex);
          final controller = ref.read(feedSelectionProvider.notifier);
          controller.clearScrollRequest();
          controller.clearSelection();
        });
      }
    });

    final feedState = ref.watch(feedControllerProvider);
    final notifier = ref.read(feedControllerProvider.notifier);
    final items = feedState.items;

    if (feedState.isLoadingInitial && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (items.isEmpty) {
      final theme = Theme.of(context);
      return RefreshIndicator(
        onRefresh: notifier.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.4,
              child: Center(
                child: Text(
                  '暂时没有插画内容',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final itemCount = items.length + (feedState.hasMore ? 1 : 0);

    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(
          horizontal: _horizontalPadding,
          vertical: _verticalPadding,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _crossAxisCount,
          mainAxisSpacing: _mainAxisSpacing,
          crossAxisSpacing: _crossAxisSpacing,
          childAspectRatio: 1,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index >= items.length) {
            return _LoadMoreTile(provider: feedControllerProvider);
          }
          final item = items[index];
          return _IllustrationTile(item: item, index: index);
        },
      ),
    );
  }
}

class _MangaTab extends ConsumerStatefulWidget {
  const _MangaTab();

  @override
  ConsumerState<_MangaTab> createState() => _MangaTabState();
}

class _MangaTabState extends ConsumerState<_MangaTab> {
  static const _horizontalPadding = 16.0;
  static const _verticalPadding = 16.0;
  static const _crossAxisSpacing = 12.0;
  static const _mainAxisSpacing = 12.0;
  static const _crossAxisCount = 2;

  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      ref.read(pixivMangaFeedControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<FeedState>(pixivMangaFeedControllerProvider, (previous, next) {
      if (!mounted) return;
      final previousError = previous?.lastError;
      if (next.lastError != null && next.lastError != previousError) {
        final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
        scaffoldMessenger?.showSnackBar(
          SnackBar(content: Text('加载内容失败：${next.lastError}')),
        );
      }
    });

    final feedState = ref.watch(pixivMangaFeedControllerProvider);
    final notifier = ref.read(pixivMangaFeedControllerProvider.notifier);
    final items = feedState.items;

    if (feedState.isLoadingInitial && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (items.isEmpty) {
      final theme = Theme.of(context);
      return RefreshIndicator(
        onRefresh: notifier.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.4,
              child: Center(
                child: Text(
                  '暂时没有漫画内容',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final itemCount = items.length + (feedState.hasMore ? 1 : 0);

    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(
          horizontal: _horizontalPadding,
          vertical: _verticalPadding,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _crossAxisCount,
          mainAxisSpacing: _mainAxisSpacing,
          crossAxisSpacing: _crossAxisSpacing,
          childAspectRatio: 1,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index >= items.length) {
            return _LoadMoreTile(provider: pixivMangaFeedControllerProvider);
          }
          final item = items[index];
          return _MangaTile(item: item);
        },
      ),
    );
  }
}

class _NovelTab extends ConsumerStatefulWidget {
  const _NovelTab();

  @override
  ConsumerState<_NovelTab> createState() => _NovelTabState();
}

class _NovelTabState extends ConsumerState<_NovelTab> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      ref.read(pixivNovelFeedControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<FeedState>(pixivNovelFeedControllerProvider, (previous, next) {
      if (!mounted) return;
      final previousError = previous?.lastError;
      if (next.lastError != null && next.lastError != previousError) {
        final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
        scaffoldMessenger?.showSnackBar(
          SnackBar(content: Text('加载内容失败：${next.lastError}')),
        );
      }
    });

    final feedState = ref.watch(pixivNovelFeedControllerProvider);
    final notifier = ref.read(pixivNovelFeedControllerProvider.notifier);
    final items = feedState.items;

    if (feedState.isLoadingInitial && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: items.length + 1,
        itemBuilder: (context, index) {
          if (index >= items.length) {
            return _ListLoadMore(provider: pixivNovelFeedControllerProvider);
          }
          final item = items[index];
          return _NovelListItem(item: item);
        },
      ),
    );
  }
}

class _LoadMoreTile extends ConsumerWidget {
  const _LoadMoreTile({required this.provider});

  final AutoDisposeStateNotifierProvider<FeedController, FeedState> provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoadingMore = ref.watch(
      provider.select((state) => state.isLoadingMore),
    );
    return Center(
      child: isLoadingMore
          ? const CircularProgressIndicator()
          : const SizedBox.shrink(),
    );
  }
}

class _ListLoadMore extends ConsumerWidget {
  const _ListLoadMore({required this.provider});

  final AutoDisposeStateNotifierProvider<FeedController, FeedState> provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoadingMore = ref.watch(
      provider.select((state) => state.isLoadingMore),
    );
    if (!isLoadingMore) {
      return const SizedBox.shrink();
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ComingSoonTab extends StatelessWidget {
  const _ComingSoonTab({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _IllustrationTile extends ConsumerWidget {
  const _IllustrationTile({required this.item, required this.index});

  final FaioContent item;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ContentTile(
      item: item,
      onTap: () {
        ref.read(feedSelectionProvider.notifier).select(index);
        context.push('/feed/detail', extra: index);
      },
    );
  }
}

class _MangaTile extends StatelessWidget {
  const _MangaTile({required this.item});

  final FaioContent item;

  @override
  Widget build(BuildContext context) {
    return _ContentTile(
      item: item,
      onTap: () {
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.showSnackBar(const SnackBar(content: Text('漫画详情页开发中')));
      },
    );
  }
}

class _NovelListItem extends StatelessWidget {
  const _NovelListItem({required this.item});

  final FaioContent item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewUrl = item.previewUrl ?? item.sampleUrl;
    final aspectRatio = ((item.previewAspectRatio ?? 1.4).clamp(
      0.2,
      5.0,
    )).toDouble();
    final hasSummary = item.summary.trim().isNotEmpty;

    final portraitAspectRatio =
        (aspectRatio > 1 ? 1 / aspectRatio : aspectRatio)
            .clamp(0.45, 0.85)
            .toDouble();
    final summaryText = hasSummary ? item.summary : '暂无简介';
    final authorName = item.authorName?.trim();
    final hasAuthor = authorName?.isNotEmpty ?? false;
    final cardColor = Color.alphaBlend(
      theme.colorScheme.surfaceVariant.withOpacity(
        theme.brightness == Brightness.dark ? 0.28 : 0.2,
      ),
      theme.colorScheme.surface,
    );
    bool isAdultTag(String tag) {
      final lowered = tag.toLowerCase();
      return lowered.contains('r-18') ||
          lowered.contains('r18') ||
          lowered.contains('18禁');
    }

    final uniqueTags = <String>{};
    final adultTags = <String>[];
    final standardTags = <String>[];
    for (final rawTag in item.tags) {
      final tag = rawTag.trim();
      if (tag.isEmpty || !uniqueTags.add(tag)) {
        continue;
      }
      if (isAdultTag(tag)) {
        adultTags.add(tag);
      } else {
        standardTags.add(tag);
      }
    }

    final ratingLower = item.rating.toLowerCase();
    final isAdultRated = ratingLower == 'adult';
    final highlightAdult = isAdultRated || adultTags.isNotEmpty;
    final adultBadgeLabel = adultTags.isNotEmpty
        ? adultTags.first
        : (isAdultRated ? 'R-18' : null);

    const maxInlineTags = 4;
    final visibleTags = standardTags.take(maxInlineTags).toList();
    final overflowCount = math.max(0, standardTags.length - visibleTags.length);
    final allTagsForSheet = <String>[
      if (adultTags.isNotEmpty) ...adultTags else if (isAdultRated) 'R-18',
      ...standardTags,
    ];

    Widget buildImage() {
      final borderRadius = BorderRadius.circular(12);
      if (previewUrl == null) {
        return ClipRRect(
          borderRadius: borderRadius,
          child: AspectRatio(
            aspectRatio: portraitAspectRatio,
            child: Container(
              color: theme.colorScheme.surfaceVariant,
              alignment: Alignment.center,
              child: Icon(
                Icons.menu_book,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      }
      final urls = _imageUrlCandidates(previewUrl);
      final headers = _imageHeadersFor(item, url: previewUrl);
      return ClipRRect(
        borderRadius: borderRadius,
        child: AspectRatio(
          aspectRatio: portraitAspectRatio,
          child: _ResilientNetworkImage(
            urls: urls,
            headers: headers,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: theme.colorScheme.surfaceVariant,
              alignment: Alignment.center,
              child: Icon(
                Icons.broken_image,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      color: cardColor,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          final novelId = parseContentNumericId(item);
          if (novelId == null) {
            final messenger = ScaffoldMessenger.maybeOf(context);
            messenger?.showSnackBar(
              const SnackBar(content: Text('无法解析小说 ID')),
            );
            return;
          }
          context.push('/feed/novel/$novelId', extra: item);
        },
        splashColor: theme.colorScheme.primary.withOpacity(0.08),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              final coverWidth = math.max(
                120.0,
                math.min(maxWidth * 0.32, 164.0),
              );
              final imageHeight = coverWidth / portraitAspectRatio;

              Widget buildTagChip(
                String label, {
                bool isOverflow = false,
                VoidCallback? onTap,
              }) {
                final foreground = isOverflow
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant;
                final borderRadius = BorderRadius.circular(999);
                final chip = Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: borderRadius,
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(
                        theme.brightness == Brightness.dark ? 0.5 : 0.25,
                      ),
                    ),
                    color: isOverflow
                        ? theme.colorScheme.primary.withOpacity(0.12)
                        : Colors.transparent,
                  ),
                  child: Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: foreground,
                      fontWeight: isOverflow ? FontWeight.w600 : null,
                    ),
                  ),
                );
                final wrappedChip = onTap != null
                    ? InkWell(
                        onTap: onTap,
                        borderRadius: borderRadius,
                        child: chip,
                      )
                    : chip;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: wrappedChip,
                );
              }

              Widget buildMetaSection() {
                final favorite = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.favorite,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${item.favoriteCount}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );

                final badgeRowChildren = <Widget>[favorite];

                if (highlightAdult) {
                  badgeRowChildren.add(const SizedBox(width: 12));
                  badgeRowChildren.add(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        adultBadgeLabel ?? 'R-18',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                }

                final tagWidgets = <Widget>[
                  for (final tag in visibleTags) buildTagChip(tag),
                  if (overflowCount > 0)
                    buildTagChip(
                      '+$overflowCount',
                      isOverflow: true,
                      onTap: () => _showAllTags(context, allTagsForSheet),
                    ),
                ];

                if (tagWidgets.isEmpty) {
                  return Row(children: badgeRowChildren);
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: badgeRowChildren),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(children: tagWidgets),
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: coverWidth,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(height: imageHeight, child: buildImage()),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (hasAuthor) ...[
                              const SizedBox(height: 4),
                              Text(
                                authorName!,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              summaryText,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: hasSummary
                                    ? theme.colorScheme.onSurface
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        buildMetaSection(),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ContentTile extends StatelessWidget {
  const _ContentTile({required this.item, this.onTap});

  final FaioContent item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = item.previewUrl ?? item.sampleUrl;
    Widget placeholder(IconData icon) {
      return Container(
        color: theme.colorScheme.surfaceVariant,
        alignment: Alignment.center,
        child: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
      );
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: preview != null
            ? _ResilientNetworkImage(
                urls: _imageUrlCandidates(preview),
                headers: _imageHeadersFor(item, url: preview),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => placeholder(Icons.broken_image),
              )
            : placeholder(Icons.image),
      ),
    );
  }
}
