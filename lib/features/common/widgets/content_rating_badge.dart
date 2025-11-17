import 'package:flutter/material.dart';

import 'package:faio/features/common/utils/content_warning.dart';

class ContentRatingBadge extends StatelessWidget {
  const ContentRatingBadge({
    super.key,
    this.warning,
    this.icon = Icons.shield_outlined,
  });

  final ContentWarning? warning;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    Color background;
    Color foreground;
    switch (warning?.level) {
      case ContentWarningLevel.extreme:
        background = colors.errorContainer;
        foreground = colors.onErrorContainer;
        break;
      case ContentWarningLevel.adult:
        background = colors.tertiaryContainer;
        foreground = colors.onTertiaryContainer;
        break;
      case ContentWarningLevel.none:
      case null:
        background = colors.surfaceContainerHighest;
        foreground = colors.onSurfaceVariant;
        break;
    }
    final label = warning?.label ?? 'General';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}
