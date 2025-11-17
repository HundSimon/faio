import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:faio/domain/models/content_tag.dart';
import 'package:faio/domain/models/tag_preferences.dart';
import 'package:faio/features/tagging/widgets/tag_chip.dart';
import '../../../core/tagging/tag_preferences_provider.dart';

class TagManagementScreen extends ConsumerStatefulWidget {
  const TagManagementScreen({super.key});

  @override
  ConsumerState<TagManagementScreen> createState() =>
      _TagManagementScreenState();
}

class _TagManagementScreenState extends ConsumerState<TagManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final prefsAsync = ref.watch(tagPreferencesProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('标签管理')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('新增标签'),
        onPressed: () => _showAddTagDialog(context),
      ),
      body: prefsAsync.when(
        data: (prefs) => _buildContent(context, prefs),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('加载标签偏好失败：$error'),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Text(
          '喜欢的标签会用于突出内容，屏蔽的标签将直接在信息流中过滤。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, TagPreferences prefs) {
    final liked = prefs.liked;
    final blocked = prefs.blocked;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        _TagSection(
          title: '喜欢的标签',
          description: '优先展示这些标签的作品，长按可调整状态。',
          tags: liked,
        ),
        const SizedBox(height: 16),
        _TagSection(
          title: '屏蔽的标签',
          description: '含有以下标签的作品将不会显示。',
          tags: blocked,
        ),
        const SizedBox(height: 24),
        TextButton.icon(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (dialogContext) {
                return AlertDialog(
                  title: const Text('清空全部标签偏好？'),
                  content: const Text('此操作无法撤销，将移除所有喜欢和屏蔽标签。'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: const Text('清空'),
                    ),
                  ],
                );
              },
            );
            if (!context.mounted) {
              return;
            }
            if (confirmed == true) {
              await ref.read(tagPreferencesProvider.notifier).clearAll();
              if (!context.mounted) {
                return;
              }
              ScaffoldMessenger.maybeOf(
                context,
              )?.showSnackBar(const SnackBar(content: Text('已清空所有标签偏好')));
            }
          },
          icon: const Icon(Icons.delete_outline),
          label: const Text('清空所有标签'),
        ),
      ],
    );
  }

  Future<void> _showAddTagDialog(BuildContext context) async {
    final controller = TextEditingController();
    var selectedStatus = ContentTagStatus.blocked;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('添加标签'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: '标签名称',
                      helperText: '不区分大小写，支持中日文本',
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<ContentTagStatus>(
                    segments: const [
                      ButtonSegment(
                        value: ContentTagStatus.liked,
                        label: Text('喜欢'),
                        icon: Icon(Icons.favorite),
                      ),
                      ButtonSegment(
                        value: ContentTagStatus.blocked,
                        label: Text('屏蔽'),
                        icon: Icon(Icons.block),
                      ),
                    ],
                    selected: {selectedStatus},
                    onSelectionChanged: (selection) {
                      if (selection.isNotEmpty) {
                        setState(() {
                          selectedStatus = selection.first;
                        });
                      }
                    },
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
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!context.mounted) {
      controller.dispose();
      return;
    }

    if (result == true) {
      final input = controller.text.trim();
      if (input.isEmpty) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(const SnackBar(content: Text('请输入有效标签')));
      } else {
        await ref
            .read(tagPreferencesProvider.notifier)
            .setStatusForName(input, selectedStatus);
        if (!context.mounted) {
          controller.dispose();
          return;
        }
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text('已添加标签：$input')));
      }
    }
    controller.dispose();
  }
}

class _TagSection extends StatelessWidget {
  const _TagSection({
    required this.title,
    required this.description,
    required this.tags,
  });

  final String title;
  final String description;
  final List<ContentTag> tags;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (tags.isEmpty)
              Text(
                '暂无标签',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tags
                    .map((tag) => TagChip(tag: tag, compact: true))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}
