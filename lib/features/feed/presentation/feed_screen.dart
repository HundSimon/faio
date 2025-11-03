import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:faio/domain/models/content_item.dart';

import '../providers/feed_providers.dart';

/// Unified content feed showing placeholder aggregated items.
class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(mockFeedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('信息流'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          return ListTile(
            contentPadding: const EdgeInsets.all(12),
            tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            leading: item.previewUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Image.network(
                        item.previewUrl.toString(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.image),
                      ),
                    ),
                  )
                : CircleAvatar(
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      switch (item.type) {
                        ContentType.comic => Icons.menu_book,
                        ContentType.novel => Icons.auto_stories,
                        ContentType.audio => Icons.headphones,
                        ContentType.illustration => Icons.image,
                      },
                    ),
                  ),
            title: Text(item.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  item.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: -8,
                  children: [
                    Chip(
                      label: Text(item.source),
                      visualDensity: VisualDensity.compact,
                    ),
                    Chip(
                      label: Text(item.rating),
                      visualDensity: VisualDensity.compact,
                    ),
                    if (item.authorName != null)
                      Chip(
                        label: Text(item.authorName!),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ],
            ),
            onTap: () {},
          );
        },
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemCount: items.length,
      ),
    );
  }
}
