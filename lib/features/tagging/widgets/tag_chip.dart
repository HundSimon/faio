import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tagging/tag_preferences_provider.dart';
import '../../../domain/models/content_tag.dart';
import '../../../domain/models/tag_preferences.dart';

class TagChip extends ConsumerWidget {
  const TagChip({
    super.key,
    required this.tag,
    this.enableActions = true,
    this.compact = false,
  });

  final ContentTag tag;
  final bool enableActions;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferencesAsync = ref.watch(tagPreferencesProvider);
    final preferences = preferencesAsync.valueOrNull;
    final status = preferences?.statusForTag(tag) ?? ContentTagStatus.neutral;
    final theme = Theme.of(context);
    final colors = _chipColors(theme, status);
    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      color: colors.foreground,
      fontWeight: status == ContentTagStatus.blocked
          ? FontWeight.w600
          : FontWeight.w500,
    );
    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 4)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 6);

    final icon = switch (status) {
      ContentTagStatus.liked => Icons.favorite,
      ContentTagStatus.blocked => Icons.block,
      _ => null,
    };

    final chip = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: colors.foreground),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              tag.displayName,
              overflow: TextOverflow.ellipsis,
              style: labelStyle,
            ),
          ),
        ],
      ),
    );

    if (!enableActions) {
      return chip;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => _handleTap(context, ref),
        onLongPress: () => _handleTap(context, ref),
        child: chip,
      ),
    );
  }

  void _handleTap(BuildContext context, WidgetRef ref) {
    final prefsState = ref.read(tagPreferencesProvider);
    final preferences = prefsState.valueOrNull;
    if (preferences == null) {
      final message = prefsState.hasError ? '标签偏好加载失败' : '标签偏好加载中，请稍候';
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    showTagActionSheet(
      context: context,
      ref: ref,
      tag: tag,
      fallbackPreferences: preferences,
    );
  }
}

Future<void> showTagActionSheet({
  required BuildContext context,
  required WidgetRef ref,
  required ContentTag tag,
  TagPreferences? fallbackPreferences,
}) async {
  final prefs =
      ref.read(tagPreferencesProvider).valueOrNull ?? fallbackPreferences;
  if (prefs == null) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(const SnackBar(content: Text('标签偏好加载中，请稍候')));
    return;
  }
  final notifier = ref.read(tagPreferencesProvider.notifier);
  final status = prefs.statusForTag(tag);
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.favorite,
                color: status == ContentTagStatus.liked
                    ? theme.colorScheme.primary
                    : theme.iconTheme.color,
              ),
              title: const Text('标记为喜欢'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await notifier.likeTag(tag);
                if (!context.mounted) return;
                _showStatusSnack(context, '已标记喜欢');
              },
            ),
            ListTile(
              leading: Icon(
                Icons.block,
                color: status == ContentTagStatus.blocked
                    ? theme.colorScheme.error
                    : theme.iconTheme.color,
              ),
              title: const Text('标记为屏蔽'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await notifier.blockTag(tag);
                if (!context.mounted) return;
                _showStatusSnack(context, '已屏蔽该标签');
              },
            ),
            ListTile(
              enabled: status != ContentTagStatus.neutral,
              leading: const Icon(Icons.remove_circle_outline),
              title: const Text('移除偏好'),
              onTap: status == ContentTagStatus.neutral
                  ? null
                  : () async {
                      Navigator.of(sheetContext).pop();
                      await notifier.removeTag(tag);
                      if (!context.mounted) return;
                      _showStatusSnack(context, '已移除该标签偏好');
                    },
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

void _showStatusSnack(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(message)));
}

_TagChipColors _chipColors(ThemeData theme, ContentTagStatus status) {
  switch (status) {
    case ContentTagStatus.liked:
      return _TagChipColors(
        theme.colorScheme.secondaryContainer.withValues(alpha: 0.9),
        theme.colorScheme.onSecondaryContainer,
        theme.colorScheme.secondary.withValues(alpha: 0.4),
      );
    case ContentTagStatus.blocked:
      return _TagChipColors(
        theme.colorScheme.errorContainer.withValues(alpha: 0.9),
        theme.colorScheme.onErrorContainer,
        theme.colorScheme.error.withValues(alpha: 0.5),
      );
    case ContentTagStatus.neutral:
      return _TagChipColors(
        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
        theme.colorScheme.onSurfaceVariant,
        theme.colorScheme.outline.withValues(alpha: 0.3),
      );
  }
}

class _TagChipColors {
  const _TagChipColors(this.background, this.foreground, this.border);

  final Color background;
  final Color foreground;
  final Color border;
}
