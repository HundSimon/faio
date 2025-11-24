import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:faio/core/preferences/content_safety_settings.dart';
import 'package:faio/domain/models/content_item.dart';
import 'package:faio/domain/models/content_tag.dart';
import 'package:faio/domain/utils/content_id.dart';
import 'package:faio/features/common/utils/content_gate.dart';
import 'package:faio/features/common/utils/content_warning.dart';
import 'package:faio/features/common/widgets/blurred_gate_overlay.dart';
import 'package:faio/features/common/widgets/skeleton_theme.dart';
import 'package:faio/features/novel/presentation/novel_detail_screen.dart'
    show NovelDetailRouteExtra;
import 'package:faio/features/novel/presentation/novel_hero.dart';
import 'package:faio/features/novel/providers/novel_providers.dart'
    show NovelFeedSelectionState, novelFeedSelectionProvider;
import 'package:faio/features/tagging/widgets/tag_chip.dart';

import '../providers/feed_providers.dart';
import 'illustration_detail_screen.dart' show IllustrationDetailRouteArgs;
import 'illustration_hero.dart';
import 'widgets/progressive_illustration_image.dart';

Future<void> _showAllTags(BuildContext context, List<ContentTag> tags) async {
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
                    .map((tag) => TagChip(tag: tag, compact: true))
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
  static const _horizontalPadding = 16.0;
  static const _verticalPadding = 16.0;
  static const _crossAxisSpacing = 12.0;
  static const _mainAxisSpacing = 12.0;
  static const _crossAxisCount = 2;

  late final ScrollController _scrollController;
  final Map<int, GlobalKey> _itemKeys = {};
  ProviderSubscription<FeedState>? _mixedFeedSubscription;
  ProviderSubscription<FeedSelectionState>? _selectionSubscription;

  void _log(String message) {
    debugPrint('[illustration-tab] $message');
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    final mixedProvider = illustrationFeedControllerProvider(
      IllustrationSource.mixed,
    );
    _mixedFeedSubscription = ref.listenManual<FeedState>(mixedProvider, (
      previous,
      next,
    ) {
      if (!mounted) return;
      final previousError = previous?.lastError;
      if (next.lastError != null && next.lastError != previousError) {
        final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
        scaffoldMessenger?.showSnackBar(
          SnackBar(content: Text('混合源加载失败：${next.lastError}')),
        );
      }
    });
    _selectionSubscription = ref.listenManual<FeedSelectionState>(
      feedSelectionProvider,
      (previous, next) {
        if (!mounted) return;
        final source = next.pendingScrollSource;
        final targetIndex = next.pendingScrollIndex;
        final shouldScroll =
            source == IllustrationSource.mixed && targetIndex != null;
        if (shouldScroll) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await _scrollToIndex(IllustrationSource.mixed, targetIndex);
            final controller = ref.read(feedSelectionProvider.notifier);
            controller.clearScrollRequest();
            controller.clearSelection();
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _mixedFeedSubscription?.close();
    _selectionSubscription?.close();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final feedState = ref.read(
      illustrationFeedControllerProvider(IllustrationSource.mixed),
    );
    if (feedState.isLoadingInitial || feedState.items.isEmpty) {
      _log(
        'Scroll ignored (loading=${feedState.isLoadingInitial}, items=${feedState.items.length})',
      );
      return;
    }
    final position = _scrollController.position;
    // Avoid spamming pagination before the grid becomes scrollable.
    if (position.maxScrollExtent <= 0 && position.pixels <= 0) {
      _log('Scroll ignored (maxScrollExtent=${position.maxScrollExtent})');
      return;
    }
    final threshold = position.maxScrollExtent - 200;
    if (position.pixels >= threshold) {
      _log(
        'Triggering loadMore at ${position.pixels.toStringAsFixed(1)} / '
        '${position.maxScrollExtent.toStringAsFixed(1)}',
      );
      ref
          .read(
            illustrationFeedControllerProvider(
              IllustrationSource.mixed,
            ).notifier,
          )
          .loadMore();
    }
  }

  Future<void> _scrollToIndex(IllustrationSource source, int index) async {
    if (source != IllustrationSource.mixed) {
      return;
    }
    final provider = illustrationFeedControllerProvider(source);
    final items = ref.read(provider).items;
    if (index < 0 || index >= items.length) {
      return;
    }
    final itemKeys = _itemKeys;
    if (!_scrollController.hasClients) {
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

    if (await ensureVisible()) {
      return;
    }
    final offset = _calculateScrollOffset(_scrollController, index);
    await _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    await Future<void>.delayed(const Duration(milliseconds: 16));
    await ensureVisible();
  }

  @override
  Widget build(BuildContext context) {
    final mixedProvider = illustrationFeedControllerProvider(
      IllustrationSource.mixed,
    );
    final mixedState = ref.watch(mixedProvider);

    return _buildSourceGrid(
      context,
      provider: mixedProvider,
      controller: _scrollController,
      state: mixedState,
      source: IllustrationSource.mixed,
      emptyTitle: '暂时没有插画',
      emptySubtitle: '下拉刷新即可重新获取最新内容',
      emptyIcon: Icons.photo_outlined,
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
    final theme = Theme.of(context);
    final notifier = ref.read(provider.notifier);
    final shouldShowSkeleton = state.isLoadingInitial && state.items.isEmpty;
    final skeletonCount = shouldShowSkeleton
        ? _estimateIllustrationSkeletonCount(context)
        : 0;
    final showLoadMore = !shouldShowSkeleton && state.hasMore;
    final itemKeys = _itemKeys;
    if (!shouldShowSkeleton) {
      itemKeys.removeWhere((key, _) => key >= state.items.length);
    }

    if (!shouldShowSkeleton && state.items.isEmpty) {
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
    final skeletonBaseColor = theme.colorScheme.surfaceContainerHighest;

    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: Skeletonizer(
        effect: themedFaioSkeletonEffect(skeletonBaseColor),
        enabled: shouldShowSkeleton,
        containersColor: skeletonBaseColor,
        child: MasonryGridView.count(
          controller: controller,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: _horizontalPadding,
            vertical: _verticalPadding,
          ),
          cacheExtent: 0,
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
    final safetySettings = ref.watch(contentSafetySettingsProvider);
    final warning = evaluateContentWarning(
      rating: item.rating,
      tags: item.tags,
    );
    final gate = evaluateContentGate(warning, safetySettings);
    final blurLabel = warning?.label ?? 'R-18';
    if (gate.isBlocked) {
      return const SizedBox.shrink();
    }
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: _ContentTile(
        item: item,
        blurLabel: gate.requiresPrompt ? blurLabel : null,
        onTap: () async {
          final allowed = await ensureContentAllowed(
            context: context,
            ref: ref,
            gate: gate,
          );
          if (!allowed) {
            return;
          }
          if (!context.mounted) return;
          ref.read(feedSelectionProvider.notifier).select(source, index);
          context.push(
            '/feed/detail',
            extra: IllustrationDetailRouteArgs(
              source: source,
              initialIndex: index,
              skipInitialWarningPrompt: gate.requiresPrompt,
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
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
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
      theme.colorScheme.surfaceContainerHighest.withOpacity(
        theme.brightness == Brightness.dark ? 0.28 : 0.2,
      ),
      theme.colorScheme.surface,
    );
    bool isAdultTag(ContentTag tag) {
      final canonical = tag.canonicalName;
      final displayLower = tag.displayName.toLowerCase();
      return canonical.contains('r18') ||
          canonical.contains('r_18') ||
          displayLower.contains('18禁');
    }

    final uniqueTags = <String>{};
    final adultTags = <ContentTag>[];
    final standardTags = <ContentTag>[];
    for (final tag in item.tags) {
      final canonical = tag.canonicalName;
      if (canonical.isEmpty || !uniqueTags.add(canonical)) {
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
        ? adultTags.first.displayName
        : (isAdultRated ? 'R-18' : null);

    const maxInlineTags = 4;
    final visibleTags = standardTags.take(maxInlineTags).toList();
    final overflowCount = math.max(0, standardTags.length - visibleTags.length);
    final allTagsForSheet = <ContentTag>[
      if (adultTags.isNotEmpty)
        ...adultTags
      else if (isAdultRated)
        ContentTag.fromLabels(primary: 'R-18'),
      ...standardTags,
    ];
    final safetySettings = ref.watch(contentSafetySettingsProvider);
    final warning = evaluateContentWarning(
      rating: item.rating,
      tags: item.tags,
    );
    final gate = evaluateContentGate(warning, safetySettings);
    final blurLabel = warning?.label ?? 'R-18';
    if (gate.isBlocked) {
      return const SizedBox.shrink();
    }

    Widget buildImage() {
      final borderRadius = BorderRadius.circular(12);
      Widget base;
      final lowRes = item.previewUrl ?? item.sampleUrl ?? item.originalUrl;
      final highRes = item.sampleUrl ?? item.originalUrl;
      if (lowRes == null && highRes == null) {
        base = Container(
          color: theme.colorScheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: Icon(
            Icons.menu_book,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        );
      } else {
        base = ProgressiveIllustrationImage(
          content: item,
          lowRes: lowRes,
          highRes: highRes,
          fit: BoxFit.cover,
          showLowResImmediately: true,
        );
      }

      Widget child;
      if (gate.requiresPrompt) {
        child = BlurredGateOverlay(
          label: blurLabel,
          borderRadius: borderRadius,
          child: base,
        );
      } else {
        child = ClipRRect(borderRadius: borderRadius, child: base);
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
        onTap: () async {
          final allowed = await ensureContentAllowed(
            context: context,
            ref: ref,
            gate: gate,
          );
          if (!allowed) {
            return;
          }
          if (!context.mounted) return;
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
            skipInitialWarningPrompt: gate.requiresPrompt,
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

              Widget buildOverflowChip(String label, {VoidCallback? onTap}) {
                final borderRadius = BorderRadius.circular(999);
                final chip = Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: borderRadius,
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  ),
                  child: Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: onTap != null
                      ? InkWell(
                          onTap: onTap,
                          borderRadius: borderRadius,
                          child: chip,
                        )
                      : chip,
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
                  for (final tag in visibleTags)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: TagChip(tag: tag, compact: true),
                    ),
                  if (overflowCount > 0)
                    buildOverflowChip(
                      '+$overflowCount',
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
      theme.colorScheme.surfaceContainerHighest.withOpacity(
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
            color: theme.colorScheme.surfaceContainerHighest,
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
                  color: theme.colorScheme.surfaceContainerHighest,
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

class _ContentTile extends StatefulWidget {
  const _ContentTile({required this.item, this.onTap, this.blurLabel});

  final FaioContent item;
  final VoidCallback? onTap;
  final String? blurLabel;

  @override
  State<_ContentTile> createState() => _ContentTileState();
}

class _ContentTileState extends State<_ContentTile> {
  bool _hasFirstFrame = false;

  @override
  void didUpdateWidget(covariant _ContentTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.id != oldWidget.item.id) {
      _hasFirstFrame = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lowRes =
        widget.item.previewUrl ??
        widget.item.sampleUrl ??
        widget.item.originalUrl;
    final highRes = widget.item.sampleUrl ?? widget.item.originalUrl;
    Widget placeholder({IconData? icon}) {
      return Container(
        color: theme.colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: icon == null
            ? null
            : Icon(icon, color: theme.colorScheme.onSurfaceVariant),
      );
    }

    late final Widget image;
    if (lowRes != null || highRes != null) {
      image = DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
        ),
        child: ProgressiveIllustrationImage(
          content: widget.item,
          lowRes: lowRes,
          highRes: highRes,
          fit: BoxFit.cover,
          showLowResImmediately: true,
          onFirstFrameShown: () {
            if (_hasFirstFrame) return;
            setState(() => _hasFirstFrame = true);
          },
        ),
      );
    } else {
      image = placeholder(icon: Icons.image);
    }

    Widget child = image;
    if (widget.blurLabel != null) {
      child = BlurredGateOverlay(
        label: widget.blurLabel!,
        borderRadius: BorderRadius.circular(12),
        child: _hasFirstFrame ? image : placeholder(),
      );
    }

    return Hero(
      tag: illustrationHeroTag(widget.item.id),
      transitionOnUserGestures: true,
      createRectTween: illustrationHeroRectTween,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: widget.onTap, child: child),
      ),
    );
  }
}
