import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:faio/features/common/utils/content_warning.dart';

import '../../../core/preferences/content_safety_settings.dart';

class ContentGateState {
  const ContentGateState({
    required this.warning,
    required this.isBlocked,
    required this.requiresPrompt,
  });

  final ContentWarning? warning;
  final bool isBlocked;
  final bool requiresPrompt;
}

ContentGateState evaluateContentGate(
  ContentWarning? warning,
  ContentSafetySettings settings,
) {
  final isBlocked = settings.isBlocked(warning?.level);
  final requiresPrompt =
      warning != null && !isBlocked && settings.requiresPrompt(warning.level);
  return ContentGateState(
    warning: warning,
    isBlocked: isBlocked,
    requiresPrompt: requiresPrompt,
  );
}

Future<bool> ensureContentAllowed({
  required BuildContext context,
  required WidgetRef ref,
  required ContentGateState gate,
}) async {
  final warning = gate.warning;
  if (warning == null) {
    return true;
  }
  if (gate.isBlocked) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text('${warning.label} 内容已被屏蔽，可前往设置调整。')),
    );
    return false;
  }
  if (!gate.requiresPrompt) {
    return true;
  }

  var rememberChoice = false;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('${warning.label} 内容提示'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(warning.message, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: rememberChoice,
                  onChanged: (value) => setState(() {
                    rememberChoice = value ?? false;
                  }),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('记住我的选择，不再提示'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('继续查看'),
              ),
            ],
          );
        },
      );
    },
  );

  if (confirmed == true && rememberChoice) {
    final notifier = ref.read(contentSafetySettingsProvider.notifier);
    switch (warning.level) {
      case ContentWarningLevel.extreme:
        notifier.setExtremeVisibility(ContentVisibility.show);
        break;
      case ContentWarningLevel.adult:
        notifier.setAdultVisibility(ContentVisibility.show);
        break;
      case ContentWarningLevel.none:
        break;
    }
  }

  return confirmed == true;
}
