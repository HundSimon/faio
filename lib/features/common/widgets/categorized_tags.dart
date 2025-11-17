import 'package:flutter/material.dart';

import 'package:faio/domain/models/content_tag.dart';
import 'package:faio/features/tagging/utils/tag_grouping.dart';
import 'package:faio/features/tagging/widgets/tag_chip.dart';

class CategorizedTagList extends StatelessWidget {
  const CategorizedTagList({super.key, required this.tags});

  final List<ContentTag> tags;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }
    final groups = buildTagCategoryGroups(tags);
    if (groups.isEmpty) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: tags.map((tag) => TagChip(tag: tag)).toList(),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groups
          .map((group) => _TagGroupSection(group: group))
          .toList(growable: false),
    );
  }
}

class _TagGroupSection extends StatelessWidget {
  const _TagGroupSection({required this.group});

  final TagCategoryGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _accentColorFor(group.category, theme);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accent.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.22 : 0.16,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(group.icon, size: 18, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  group.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: group.tags.map((tag) => TagChip(tag: tag)).toList(),
          ),
        ],
      ),
    );
  }

  Color _accentColorFor(TagCategoryType category, ThemeData theme) {
    final scheme = theme.colorScheme;
    switch (category) {
      case TagCategoryType.contentRating:
        return scheme.error;
      case TagCategoryType.theme:
        return scheme.primary;
      case TagCategoryType.species:
        return scheme.tertiary;
      case TagCategoryType.character:
        return scheme.secondary;
      case TagCategoryType.trait:
        return scheme.secondaryContainer;
      case TagCategoryType.general:
        return scheme.outline;
    }
  }
}
