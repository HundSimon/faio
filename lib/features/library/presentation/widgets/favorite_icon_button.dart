import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/content_item.dart';
import '../../domain/library_entries.dart';
import '../../providers/library_providers.dart';

class FavoriteIconButton extends ConsumerWidget {
  const FavoriteIconButton.content({
    required FaioContent content,
    this.padding = const EdgeInsets.all(6),
    this.iconSize = 20,
    this.backgroundColor,
    this.onToggled,
    super.key,
  })  : _content = content,
        _series = null;

  const FavoriteIconButton.series({
    required LibrarySeriesFavorite series,
    this.padding = const EdgeInsets.all(6),
    this.iconSize = 20,
    this.backgroundColor,
    this.onToggled,
    super.key,
  })  : _content = null,
        _series = series;

  final FaioContent? _content;
  final LibrarySeriesFavorite? _series;
  final EdgeInsetsGeometry padding;
  final double iconSize;
  final Color? backgroundColor;
  final void Function(bool isFavorite)? onToggled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(
      libraryFavoritesProvider.select((asyncValue) {
        final entries = asyncValue.valueOrNull;
        if (entries == null) {
          return false;
        }
        if (_content != null) {
          return entries.any(
            (entry) =>
                entry.isContent && entry.content!.id == _content.id,
          );
        }
        if (_series != null) {
          return entries.any(
            (entry) =>
                entry.isSeries &&
                entry.series!.seriesId == _series.seriesId,
          );
        }
        return false;
      }),
    );
    final notifier = ref.read(libraryFavoritesProvider.notifier);
    final theme = Theme.of(context);
    final containerColor =
        backgroundColor ??
        theme.colorScheme.surface.withOpacity(
          theme.brightness == Brightness.dark ? 0.72 : 0.82,
        );

    return Material(
      color: containerColor,
      shape: const CircleBorder(),
      child: Padding(
        padding: padding,
        child: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          iconSize: iconSize,
          color: isFavorite
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface,
          tooltip: isFavorite ? '取消收藏' : '收藏',
          icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
          onPressed: () async {
            if (_content != null) {
              await notifier.toggleContentFavorite(_content);
            } else if (_series != null) {
              await notifier.toggleSeriesFavorite(_series);
            }
            onToggled?.call(!isFavorite);
          },
        ),
      ),
    );
  }
}
