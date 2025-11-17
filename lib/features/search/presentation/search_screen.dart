import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/content_item.dart';
import '../providers/search_providers.dart';

/// Early prototype of unified search UI.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    ref.read(searchQueryProvider.notifier).state = value;
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(searchResultsProvider);

    ref.listen(searchResultsProvider, (previous, next) {
      next.whenOrNull(
        error: (error, stackTrace) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('搜索失败：$error')));
        },
      );
    });

    return Scaffold(
      appBar: AppBar(title: const Text('搜索')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: '搜索关键字、作者或标签',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.search,
              onChanged: _onQueryChanged,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: resultsAsync.when(
                data: (items) {
                  if (_controller.text.trim().isEmpty) {
                    return const Center(child: Text('输入关键词即可跨站点搜索内容'));
                  }
                  if (items.isEmpty) {
                    return const Center(child: Text('没有匹配结果，试试其他关键词或标签'));
                  }

                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _SearchResultTile(item: item);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) =>
                    Center(child: Text('搜索出现问题：$error')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.item});

  final FaioContent item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = item.summary.trim().isEmpty ? null : item.summary.trim();
    final author = item.authorName?.trim();
    final metadataStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: _buildLeading(theme),
        title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${item.source} · ${_typeLabel(item.type)} · ${item.rating}',
              style: metadataStyle,
            ),
            if (author != null && author.isNotEmpty)
              Text(author, style: theme.textTheme.bodySmall),
            if (summary != null)
              Text(
                summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: metadataStyle,
              ),
          ],
        ),
        trailing: const Icon(Icons.open_in_new_rounded, size: 18),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }

  Widget _buildLeading(ThemeData theme) {
    final (background, foreground) = _badgeColors(theme.colorScheme);
    final iconData = _iconForType(item.type);
    return CircleAvatar(
      radius: 24,
      backgroundColor: background,
      foregroundColor: foreground,
      child: Icon(iconData),
    );
  }

  (Color, Color) _badgeColors(ColorScheme scheme) {
    return switch (item.type) {
      ContentType.novel => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      ContentType.comic => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      _ => (scheme.primaryContainer, scheme.onPrimaryContainer),
    };
  }

  static IconData _iconForType(ContentType type) {
    return switch (type) {
      ContentType.novel => Icons.menu_book_rounded,
      ContentType.comic => Icons.collections_bookmark,
      ContentType.audio => Icons.graphic_eq_rounded,
      _ => Icons.image,
    };
  }

  static String _typeLabel(ContentType type) {
    return switch (type) {
      ContentType.novel => '小说',
      ContentType.comic => '漫画',
      ContentType.audio => '音频',
      _ => '插画',
    };
  }
}
