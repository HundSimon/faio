import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:faio/domain/models/content_item.dart';

import '../providers/feed_providers.dart';

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
            _ComingSoonTab(message: 'AIO 体验敬请期待'),
            _IllustrationTab(),
            _ComingSoonTab(message: '漫画内容建设中'),
            _ComingSoonTab(message: '小说内容建设中'),
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
            return const _LoadMoreTile();
          }
          final item = items[index];
          return _IllustrationTile(item: item, index: index);
        },
      ),
    );
  }
}

class _LoadMoreTile extends ConsumerWidget {
  const _LoadMoreTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoadingMore = ref.watch(
      feedControllerProvider.select((state) => state.isLoadingMore),
    );
    return Center(
      child: isLoadingMore
          ? const CircularProgressIndicator()
          : const SizedBox.shrink(),
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
    final theme = Theme.of(context);
    final previewUrl = item.previewUrl;

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
        onTap: () {
          ref.read(feedSelectionProvider.notifier).select(index);
          context.push('/feed/detail', extra: index);
        },
        child: previewUrl != null
            ? Image.network(
                previewUrl.toString(),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => placeholder(Icons.broken_image),
              )
            : placeholder(Icons.image),
      ),
    );
  }
}
