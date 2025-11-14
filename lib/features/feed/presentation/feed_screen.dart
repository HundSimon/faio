import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:faio/data/pixiv/pixiv_image_cache.dart';
import 'package:faio/domain/models/content_item.dart';
import 'package:faio/domain/utils/content_id.dart';
import 'package:faio/domain/utils/pixiv_image_utils.dart';
import 'package:faio/features/common/widgets/skeleton_theme.dart';
import 'package:faio/features/novel/presentation/novel_detail_screen.dart'
    show NovelDetailRouteExtra;
import 'package:faio/features/novel/presentation/novel_hero.dart';
import 'package:faio/features/novel/providers/novel_providers.dart'
    show NovelFeedSelectionState, novelFeedSelectionProvider;

import '../providers/feed_providers.dart';
import 'illustration_hero.dart';
import 'illustration_detail_screen.dart' show IllustrationDetailRouteArgs;

class _ResilientNetworkImage extends StatefulWidget {
  const _ResilientNetworkImage({
    required this.urls,
    this.headers,
    this.fit = BoxFit.cover,
    this.errorBuilder,
    this.placeholder,
  }) : assert(urls.length > 0, 'urls must not be empty');

  final List<Uri> urls;
  final Map<String, String>? headers;
  final BoxFit fit;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;
  final Widget? placeholder;

  @override
  State<_ResilientNetworkImage> createState() => _ResilientNetworkImageState();
}

class _ResilientNetworkImageState extends State<_ResilientNetworkImage> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final currentUri = widget.urls[_index];
    final cacheManager = pixivImageCacheManagerForUrl(currentUri);
    final currentUrl = currentUri.toString();
    final imageProvider = CachedNetworkImageProvider(
      currentUrl,
      headers: widget.headers,
      cacheManager: cacheManager,
    );
    return Image(
      image: imageProvider,
      fit: widget.fit,
      alignment: Alignment.center,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return widget.placeholder ?? child;
      },
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

class _IllustrationTabState extends ConsumerState<_IllustrationTab>
    with TickerProviderStateMixin {
  static const _pixivTabIndex = 0;
  static const _e621TabIndex = 1;
  static const _horizontalPadding = 16.0;
  static const _verticalPadding = 16.0;
  static const _crossAxisSpacing = 12.0;
  static const _mainAxisSpacing = 12.0;
  static const _crossAxisCount = 2;

  late final TabController _sourceTabController;
  late final ScrollController _pixivScrollController;
  late final ScrollController _e621ScrollController;
  var _tabsVisible = true;
  var _suppressVisibilityUpdates = false;
  final Map<int, GlobalKey> _pixivItemKeys = {};
  final Map<int, GlobalKey> _e621ItemKeys = {};

  @override
  void initState() {
    super.initState();
    _sourceTabController = TabController(length: 2, vsync: this);
    _pixivScrollController = ScrollController()..addListener(_onPixivScroll);
    _e621ScrollController = ScrollController()..addListener(_onE621Scroll);
  }

  @override
  void dispose() {
    _pixivScrollController.removeListener(_onPixivScroll);
    _e621ScrollController.removeListener(_onE621Scroll);
    _pixivScrollController.dispose();
    _e621ScrollController.dispose();
    _sourceTabController.dispose();
    super.dispose();
  }

  void _onPixivScroll() {
    if (!_pixivScrollController.hasClients) {
      return;
    }
    _updateTabVisibility(_pixivScrollController);
    final position = _pixivScrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      ref
          .read(
            illustrationFeedControllerProvider(
              IllustrationSource.pixiv,
            ).notifier,
          )
          .loadMore();
    }
  }

  void _onE621Scroll() {
    if (!_e621ScrollController.hasClients) {
      return;
    }
    _updateTabVisibility(_e621ScrollController);
    final position = _e621ScrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      ref
          .read(
            illustrationFeedControllerProvider(
              IllustrationSource.e621,
            ).notifier,
          )
          .loadMore();
    }
  }

  Future<void> _scrollToIndex(IllustrationSource source, int index) async {
    final provider = illustrationFeedControllerProvider(source);
    final items = ref.read(provider).items;
    if (index < 0 || index >= items.length) {
      return;
    }
    final targetTab = source == IllustrationSource.pixiv
        ? _pixivTabIndex
        : _e621TabIndex;

    if (_sourceTabController.index != targetTab) {
      _sourceTabController.animateTo(targetTab);
      await Future<void>.delayed(const Duration(milliseconds: 220));
    }

    final controller = source == IllustrationSource.pixiv
        ? _pixivScrollController
        : _e621ScrollController;
    final itemKeys = source == IllustrationSource.pixiv
        ? _pixivItemKeys
        : _e621ItemKeys;
    if (!controller.hasClients) {
      return;
    }
    Future<bool> ensureVisible() async {
      final context = itemKeys[index]?.currentContext;
      if (context == null) {
        return false;
      }
      await Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.1,
      );
      return true;
    }

    _setTabsVisible(true);
    _suppressVisibilityUpdates = true;
    try {
      if (await ensureVisible()) {
        return;
      }
      final offset = _calculateScrollOffset(controller, index);
      await controller.animateTo(
        offset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      await Future<void>.delayed(const Duration(milliseconds: 16));
      await ensureVisible();
    } finally {
      _suppressVisibilityUpdates = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<FeedState>(
      illustrationFeedControllerProvider(IllustrationSource.pixiv),
      (previous, next) {
        if (!mounted) return;
        final previousError = previous?.lastError;
        if (next.lastError != null && next.lastError != previousError) {
          final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
          scaffoldMessenger?.showSnackBar(
            SnackBar(content: Text('Pixiv 加载失败：${next.lastError}')),
          );
        }
      },
    );
    ref.listen<FeedState>(
      illustrationFeedControllerProvider(IllustrationSource.e621),
      (previous, next) {
        if (!mounted) return;
        final previousError = previous?.lastError;
        if (next.lastError != null && next.lastError != previousError) {
          final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
          scaffoldMessenger?.showSnackBar(
            SnackBar(content: Text('e621 加载失败：${next.lastError}')),
          );
        }
      },
    );

    ref.listen<FeedSelectionState>(feedSelectionProvider, (previous, next) {
      if (!mounted) return;
      final source = next.pendingScrollSource;
      final targetIndex = next.pendingScrollIndex;
      if (source != null && targetIndex != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _scrollToIndex(source, targetIndex);
          final controller = ref.read(feedSelectionProvider.notifier);
          controller.clearScrollRequest();
          controller.clearSelection();
        });
      }
    });

    final pixivProvider = illustrationFeedControllerProvider(
      IllustrationSource.pixiv,
    );
    final e621Provider = illustrationFeedControllerProvider(
      IllustrationSource.e621,
    );
    final pixivState = ref.watch(pixivProvider);
    final e621State = ref.watch(e621Provider);

    return Column(
      children: [
        _buildSourceTabs(context),
        Expanded(
          child: AnimatedBuilder(
            animation: _sourceTabController,
            builder: (context, _) {
              final tabIndex = _sourceTabController.index;
              return IndexedStack(
                index: tabIndex,
                children: [
                  _buildSourceGrid(
                    context,
                    provider: pixivProvider,
                    controller: _pixivScrollController,
                    state: pixivState,
                    source: IllustrationSource.pixiv,
                    emptyTitle: '暂时没有 Pixiv 插画',
                    emptySubtitle: '下拉刷新可重新获取随机精选作品',
                    emptyIcon: Icons.casino_outlined,
                  ),
                  _buildSourceGrid(
                    context,
                    provider: e621Provider,
                    controller: _e621ScrollController,
                    state: e621State,
                    source: IllustrationSource.e621,
                    emptyTitle: '暂时没有 e621 插画',
                    emptySubtitle: '下拉刷新即可查看最新倒序内容',
                    emptyIcon: Icons.schedule_outlined,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  int _estimateIllustrationSkeletonCount(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final gridWidth =
        size.width -
        (_horizontalPadding * 2) -
        (_crossAxisSpacing * (_crossAxisCount - 1));
    final tileWidth = math.max(gridWidth / _crossAxisCount, 120.0);
    final rowHeight = tileWidth + _mainAxisSpacing;
    final minRows = (size.height / rowHeight).ceil() + 1;
    return math.max(minRows * _crossAxisCount, _crossAxisCount * 4);
  }

  Widget _buildSourceTabs(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tabBar = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: colorScheme.surfaceVariant.withOpacity(
            theme.brightness == Brightness.dark ? 0.4 : 0.6,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: TabBar(
          controller: _sourceTabController,
          indicator: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          labelPadding: EdgeInsets.zero,
          tabs: [
            Tab(
              child: _SourceTabLabel(
                label: 'Pixiv',
                color: colorScheme.primary,
              ),
            ),
            Tab(
              child: _SourceTabLabel(
                label: 'e621',
                color: colorScheme.tertiary,
              ),
            ),
          ],
        ),
      ),
    );

    return ClipRect(
      child: AnimatedAlign(
        alignment: Alignment.topCenter,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        heightFactor: _tabsVisible ? 1 : 0,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: _tabsVisible ? 1 : 0,
          child: tabBar,
        ),
      ),
    );
  }

  Widget _buildSourceGrid(
    BuildContext context, {
    required AutoDisposeStateNotifierProvider<FeedController, FeedState>
    provider,
    required ScrollController controller,
    required FeedState state,
    required IllustrationSource source,
    required String emptyTitle,
    required String emptySubtitle,
    required IconData emptyIcon,
  }) {
    final notifier = ref.read(provider.notifier);
    final shouldShowSkeleton = state.isLoadingInitial && state.items.isEmpty;
    final skeletonCount = shouldShowSkeleton
        ? _estimateIllustrationSkeletonCount(context)
        : 0;
    final showLoadMore = !shouldShowSkeleton && state.hasMore;
    final itemKeys = source == IllustrationSource.pixiv
        ? _pixivItemKeys
        : _e621ItemKeys;
    if (!shouldShowSkeleton) {
      itemKeys.removeWhere((key, _) => key >= state.items.length);
    }

    if (!shouldShowSkeleton && state.items.isEmpty) {
      final theme = Theme.of(context);
      return RefreshIndicator(
        onRefresh: notifier.refresh,
        child: ListView(
          controller: controller,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.3,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(emptyIcon, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(height: 12),
                    Text(emptyTitle, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      emptySubtitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final itemCount = shouldShowSkeleton
        ? skeletonCount
        : state.items.length + (showLoadMore ? 1 : 0);

    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: Skeletonizer(
        effect: kFaioSkeletonEffect,
        enabled: shouldShowSkeleton,
        child: MasonryGridView.count(
          controller: controller,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: _horizontalPadding,
            vertical: _verticalPadding,
          ),
          crossAxisSpacing: _crossAxisSpacing,
          mainAxisSpacing: _mainAxisSpacing,
          crossAxisCount: _crossAxisCount,
          itemCount: itemCount,
          itemBuilder: (context, index) {
            if (shouldShowSkeleton) {
              return const _IllustrationSkeletonTile();
            }
            if (showLoadMore && index >= state.items.length) {
              return _LoadMoreTile(provider: provider);
            }
            final item = state.items[index];
            return _IllustrationTile(
              key: itemKeys.putIfAbsent(index, () => GlobalKey()),
              item: item,
              index: index,
              source: source,
            );
          },
        ),
      ),
    );
  }

  double _calculateScrollOffset(ScrollController controller, int localIndex) {
    final width = context.size?.width ?? MediaQuery.of(context).size.width;
    final gridWidth =
        width -
        (_horizontalPadding * 2) -
        (_crossAxisSpacing * (_crossAxisCount - 1));
    final tileWidth = gridWidth / _crossAxisCount;
    final tileHeight = tileWidth;
    final rowHeight = tileHeight + _mainAxisSpacing;
    final row = localIndex ~/ _crossAxisCount;
    final targetOffset =
        _verticalPadding + row * rowHeight - (_mainAxisSpacing / 2);
    final maxScroll = controller.position.maxScrollExtent;
    return targetOffset.clamp(0.0, maxScroll);
  }

  void _updateTabVisibility(ScrollController controller) {
    if (_suppressVisibilityUpdates || !controller.hasClients) {
      return;
    }
    final position = controller.position;
    final direction = position.userScrollDirection;
    final isNearTop = position.pixels <= (position.minScrollExtent + 8.0);
    if (direction == ScrollDirection.reverse && !isNearTop) {
      _setTabsVisible(false);
    } else if (direction == ScrollDirection.forward || isNearTop) {
      _setTabsVisible(true);
    }
  }

  void _setTabsVisible(bool visible) {
    if (_tabsVisible == visible) {
      return;
    }
    setState(() {
      _tabsVisible = visible;
    });
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
  final Map<int, GlobalKey> _itemKeys = {};

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

  Future<void> _scrollToIndex(int index) async {
    if (!_scrollController.hasClients) {
      return;
    }

    Future<bool> ensureVisible() async {
      final context = _itemKeys[index]?.currentContext;
      if (context != null) {
        await Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOut,
          alignment: 0.1,
        );
        return true;
      }
      return false;
    }

    if (await ensureVisible()) {
      return;
    }

    final fallbackExtent = 240.0;
    final targetOffset = index * fallbackExtent;
    final position = _scrollController.position;
    final clamped = targetOffset.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    await _scrollController.animateTo(
      clamped,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
    await Future<void>.delayed(const Duration(milliseconds: 16));
    await ensureVisible();
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

    ref.listen<NovelFeedSelectionState>(novelFeedSelectionProvider, (
      previous,
      next,
    ) {
      if (!mounted) return;
      final targetIndex = next.pendingScrollIndex;
      if (targetIndex != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _scrollToIndex(targetIndex);
          final controller = ref.read(novelFeedSelectionProvider.notifier);
          controller.clearScrollRequest();
          controller.clearSelection();
        });
      }
    });

    final feedState = ref.watch(pixivNovelFeedControllerProvider);
    final notifier = ref.read(pixivNovelFeedControllerProvider.notifier);
    final items = feedState.items;
    _itemKeys.removeWhere((key, _) => key >= items.length);

    if (feedState.isLoadingInitial && items.isEmpty) {
      final size = MediaQuery.of(context).size;
      const estimatedItemHeight = 180.0;
      final skeletonCount = math.max(
        6,
        (size.height / estimatedItemHeight).ceil() + 2,
      );
      return RefreshIndicator(
        onRefresh: notifier.refresh,
        child: Skeletonizer(
          effect: kFaioSkeletonEffect,
          child: ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            itemCount: skeletonCount,
            itemBuilder: (context, index) => const _NovelListSkeletonItem(),
          ),
        ),
      );
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
          final key = _itemKeys.putIfAbsent(index, () => GlobalKey());
          return _NovelListItem(key: key, item: item, index: index);
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
    return SizedBox(
      height: 48,
      child: Center(
        child: isLoadingMore
            ? const CircularProgressIndicator()
            : const SizedBox.shrink(),
      ),
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
  const _IllustrationTile({
    required this.item,
    required this.index,
    required this.source,
    super.key,
  });

  final FaioContent item;
  final int index;
  final IllustrationSource source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aspectRatio = ((item.previewAspectRatio ?? 1).clamp(
      0.5,
      1.8,
    )).toDouble();
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: _ContentTile(
        item: item,
        onTap: () {
          ref.read(feedSelectionProvider.notifier).select(source, index);
          context.push(
            '/feed/detail',
            extra: IllustrationDetailRouteArgs(
              source: source,
              initialIndex: index,
            ),
          );
        },
      ),
    );
  }
}

class _IllustrationSkeletonTile extends StatelessWidget {
  const _IllustrationSkeletonTile();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceVariant;
    return Skeleton.leaf(
      child: AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(color: color),
        ),
      ),
    );
  }
}

class _SourceTabLabel extends StatelessWidget {
  const _SourceTabLabel({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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

class _NovelListItem extends ConsumerWidget {
  const _NovelListItem({required this.item, required this.index, super.key});

  final FaioContent item;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final previewUrl = item.previewUrl ?? item.sampleUrl;
    final aspectRatio = ((item.previewAspectRatio ?? 1.4).clamp(
      0.2,
      5.0,
    )).toDouble();
    final hasSummary = item.summary.trim().isNotEmpty;

    final portraitAspectRatio =
        (aspectRatio > 1 ? 1 / aspectRatio : aspectRatio)
            .clamp(0.5, 0.85)
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
      Widget child;
      if (previewUrl == null) {
        child = ClipRRect(
          borderRadius: borderRadius,
          child: Container(
            color: theme.colorScheme.surfaceVariant,
            alignment: Alignment.center,
            child: Icon(
              Icons.menu_book,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        );
      } else {
        final urls = pixivImageUrlCandidates(previewUrl);
        final headers = pixivImageHeaders(content: item, url: previewUrl);
        child = ClipRRect(
          borderRadius: borderRadius,
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
        );
      }
      return Hero(
        tag: novelHeroTag(item.id),
        transitionOnUserGestures: true,
        createRectTween: novelHeroRectTween,
        child: child,
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: cardColor,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          ref.read(novelFeedSelectionProvider.notifier).select(index);
          final novelId = parseContentNumericId(item);
          if (novelId == null) {
            final messenger = ScaffoldMessenger.maybeOf(context);
            messenger?.showSnackBar(const SnackBar(content: Text('无法解析小说 ID')));
            return;
          }
          final extras = NovelDetailRouteExtra(
            initialContent: item,
            initialIndex: index,
          );
          context.push('/feed/novel/$novelId?index=$index', extra: extras);
        },
        splashColor: theme.colorScheme.primary.withOpacity(0.08),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              final coverWidth = math.max(
                108.0,
                math.min(maxWidth * 0.28, 148.0),
              );
              const maxImageHeight = 180.0;
              final constrainedAspectRatio = math.max(
                portraitAspectRatio,
                coverWidth / maxImageHeight,
              );
              final imageHeight = coverWidth / constrainedAspectRatio;

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
                    horizontal: 10,
                    vertical: 4,
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
                  badgeRowChildren.add(const SizedBox(width: 10));
                  badgeRowChildren.add(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
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
                    const SizedBox(height: 6),
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
                    height: imageHeight,
                    child: buildImage(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
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
                            const SizedBox(height: 6),
                            Text(
                              summaryText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: hasSummary
                                    ? theme.colorScheme.onSurface
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
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

class _NovelListSkeletonItem extends StatelessWidget {
  const _NovelListSkeletonItem();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = Color.alphaBlend(
      theme.colorScheme.surfaceVariant.withOpacity(
        theme.brightness == Brightness.dark ? 0.28 : 0.2,
      ),
      theme.colorScheme.surface,
    );
    const coverWidth = 128.0;
    const coverHeight = 180.0;

    Widget line({double height = 14, double? width, double radius = 6}) {
      return Skeleton.leaf(
        child: Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: cardColor,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton.leaf(
              child: Container(
                width: coverWidth,
                height: coverHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: theme.colorScheme.surfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  line(height: 20, radius: 8),
                  const SizedBox(height: 8),
                  line(height: 16, width: 160, radius: 8),
                  const SizedBox(height: 12),
                  line(),
                  const SizedBox(height: 6),
                  line(width: 220),
                  const SizedBox(height: 6),
                  line(width: 180),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: line(height: 20, radius: 999)),
                      const SizedBox(width: 12),
                      line(height: 20, width: 52, radius: 999),
                    ],
                  ),
                ],
              ),
            ),
          ],
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
    Widget placeholder({IconData? icon}) {
      return Container(
        color: theme.colorScheme.surfaceVariant,
        alignment: Alignment.center,
        child: icon == null
            ? null
            : Icon(icon, color: theme.colorScheme.onSurfaceVariant),
      );
    }

    final loadingPlaceholder = placeholder();
    return Hero(
      tag: illustrationHeroTag(item.id),
      transitionOnUserGestures: true,
      createRectTween: illustrationHeroRectTween,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: preview != null
              ? _ResilientNetworkImage(
                  urls: pixivImageUrlCandidates(preview),
                  headers: pixivImageHeaders(content: item, url: preview),
                  fit: BoxFit.cover,
                  placeholder: loadingPlaceholder,
                  errorBuilder: (_, __, ___) =>
                      placeholder(icon: Icons.broken_image),
                )
              : placeholder(icon: Icons.image),
        ),
      ),
    );
  }
}
