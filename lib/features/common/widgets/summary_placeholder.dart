import 'package:flutter/material.dart';

class SummaryPlaceholder extends StatelessWidget {
  const SummaryPlaceholder({super.key, this.onAction, this.actionLabel});

  final VoidCallback? onAction;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveLabel = actionLabel ?? '前往原站';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '作者尚未提供简介。',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (onAction != null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(effectiveLabel),
          ),
        ],
      ],
    );
  }
}
