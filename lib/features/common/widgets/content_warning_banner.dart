import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:faio/features/common/utils/content_warning.dart';

class ContentWarningBanner extends StatelessWidget {
  const ContentWarningBanner({super.key, required this.warning});

  final ContentWarning warning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final background = warning.level == ContentWarningLevel.extreme
        ? colors.errorContainer
        : colors.tertiaryContainer;
    final foreground = warning.level == ContentWarningLevel.extreme
        ? colors.onErrorContainer
        : colors.onTertiaryContainer;

    return Card(
      color: background,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: foreground, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${warning.label} 内容警告',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: foreground,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    warning.message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: foreground,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ContentWarningOverlay extends StatelessWidget {
  const ContentWarningOverlay({
    super.key,
    required this.warning,
    required this.onConfirm,
    required this.onDismiss,
  });

  final ContentWarning warning;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final containerColor = colors.surface.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.86 : 0.94,
    );
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(color: Colors.black.withValues(alpha: 0.45)),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: containerColor,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          color: colors.primary,
                          size: 26,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${warning.label} 内容已模糊',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      warning.message,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: onConfirm,
                      child: const Text('继续查看'),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: onDismiss,
                      icon: const Icon(Icons.close),
                      label: const Text('返回'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
