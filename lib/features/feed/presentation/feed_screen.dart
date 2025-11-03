import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:faio/domain/models/content_item.dart';

import '../providers/feed_providers.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(feedStreamProvider);

    ref.listen(feedStreamProvider, (previous, next) {
      next.whenOrNull(
        error: (error, stackTrace) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('加载 e621 内容失败：$error')),
          );
        },
      );
    });

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
        body: feedAsync.when(
          data: (items) {
            final illustrations =
                items.where((item) => item.type == ContentType.illustration).toList();

            return TabBarView(
              children: [
                const _ComingSoonTab(message: 'AIO 体验敬请期待'),
                _IllustrationGrid(items: illustrations),
                const _ComingSoonTab(message: '漫画内容建设中'),
                const _ComingSoonTab(message: '小说内容建设中'),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Text('加载内容失败：$error'),
          ),
        ),
      ),
    );
  }
}

class _IllustrationGrid extends StatelessWidget {
  const _IllustrationGrid({required this.items});

  final List<FaioContent> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      final theme = Theme.of(context);
      return Center(
        child: Text(
          '暂时没有插画内容',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _IllustrationTile(item: items[index]),
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

class _IllustrationTile extends StatelessWidget {
  const _IllustrationTile({required this.item});

  final FaioContent item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewUrl = item.previewUrl;

    Widget placeholder(IconData icon) {
      return Container(
        color: theme.colorScheme.surfaceVariant,
        alignment: Alignment.center,
        child: Icon(
          icon,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: previewUrl != null
          ? Image.network(
              previewUrl.toString(),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => placeholder(Icons.broken_image),
            )
          : placeholder(Icons.image),
    );
  }
}
