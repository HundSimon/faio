import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/novel_detail.dart';
import '../../providers/novel_providers.dart';
import 'novel_image.dart';

Future<int?> showNovelSeriesSheet({
  required BuildContext context,
  required int seriesId,
  int? currentNovelId,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Consumer(
          builder: (context, ref, _) {
            final seriesAsync = ref.watch(novelSeriesDetailProvider(seriesId));
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: seriesAsync.when(
                data: (detail) => _SeriesSheetBody(
                  detail: detail,
                  currentNovelId: currentNovelId,
                ),
                loading: () => const SizedBox(
                  height: 240,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stackTrace) => SizedBox(
                  height: 240,
                  child: Center(
                    child: Text(
                      '系列加载失败：$error',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

class _SeriesSheetBody extends StatelessWidget {
  const _SeriesSheetBody({required this.detail, this.currentNovelId});

  final NovelSeriesDetail? detail;
  final int? currentNovelId;

  @override
  Widget build(BuildContext context) {
    if (detail == null) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('未找到系列信息')),
      );
    }

    final theme = Theme.of(context);
    final entries = detail!.novels;
    return FractionallySizedBox(
      heightFactor: 0.8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail!.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (detail!.caption.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    detail!.caption,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (detail!.tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: detail!.tags
                        .map(
                          (tag) => Chip(
                            label: Text(tag),
                            backgroundColor:
                                theme.colorScheme.surfaceVariant,
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final isCurrent = entry.id == currentNovelId;
                return Card(
                  color: isCurrent
                      ? theme.colorScheme.primary.withOpacity(0.08)
                      : null,
                  child: ListTile(
                    leading: _SeriesCover(coverUrl: entry.coverUrl),
                    title: Text(
                      entry.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: isCurrent
                        ? Text(
                            '当前章节',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : null,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).pop(entry.id),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SeriesCover extends StatelessWidget {
  const _SeriesCover({this.coverUrl});

  final Uri? coverUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placeholder = Container(
      width: 56,
      height: 80,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.menu_book_outlined,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    if (coverUrl == null) {
      return placeholder;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 56,
        height: 80,
        child: ResilientNetworkImage(
          urls: imageUrlCandidates(coverUrl!),
          headers: imageHeadersForUrl(coverUrl),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder,
        ),
      ),
    );
  }
}
