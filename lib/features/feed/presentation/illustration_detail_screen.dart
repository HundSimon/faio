import 'package:flutter/material.dart';

import 'package:faio/domain/models/content_item.dart';

class IllustrationDetailScreen extends StatelessWidget {
  const IllustrationDetailScreen({required this.content, super.key});

  final FaioContent content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget placeholder(IconData icon) {
      return Container(
        height: 240,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
      );
    }

    final aspectRatio = content.previewAspectRatio ?? 1;
    final hasSummary = content.summary.trim().isNotEmpty;
    final detailImageUrl = content.sampleUrl ?? content.previewUrl;

    String formatDateTime(DateTime? dateTime) {
      if (dateTime == null) {
        return '未知';
      }
      final local = dateTime.toLocal();
      return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
          '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }

    final formattedCreatedAt = formatDateTime(content.publishedAt);

    return Scaffold(
      appBar: AppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (detailImageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: aspectRatio > 0 ? aspectRatio : 1,
                  child: Image.network(
                    detailImageUrl.toString(),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        placeholder(Icons.broken_image),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) {
                        return child;
                      }
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          if (content.previewUrl != null)
                            Image.network(
                              content.previewUrl.toString(),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  placeholder(Icons.broken_image),
                            ),
                          Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              )
            else
              placeholder(Icons.image),
            const SizedBox(height: 16),
            Text('来源：${content.source}', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(
              '作者：${content.authorName ?? '未知'}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text('评级：${content.rating}', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text('创建时间：$formattedCreatedAt', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(
              '更新时间：${formatDateTime(content.updatedAt)}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '收藏数：${content.favoriteCount}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text(
              '简介',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasSummary ? content.summary : '暂无简介',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: hasSummary
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (content.sourceLinks.isNotEmpty) ...[
              Text(
                '来源链接',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: content.sourceLinks
                    .map(
                      (uri) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SelectableText(
                          uri.toString(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],
            if (content.tags.isNotEmpty) ...[
              Text(
                '标签',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: content.tags
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
          ],
        ),
      ),
    );
  }
}
