import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:faio/data/pixiv/pixiv_image_cache.dart';
import 'package:faio/domain/models/content_item.dart';
import 'package:faio/domain/utils/content_id.dart';
import 'package:faio/domain/utils/pixiv_image_utils.dart';
import 'package:faio/features/tagging/widgets/tag_chip.dart';

import 'package:faio/features/feed/providers/feed_providers.dart'
    show IllustrationSource;
import 'package:faio/features/feed/presentation/illustration_detail_screen.dart'
    show IllustrationDetailRouteArgs, IllustrationDetailScreen;
import '../../novel/presentation/novel_detail_screen.dart';

import '../../novel/presentation/widgets/novel_series_sheet.dart';
import '../domain/library_entries.dart';
import '../providers/library_providers.dart';
import 'widgets/favorite_icon_button.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(libraryFavoritesProvider);
    final historyAsync = ref.watch(libraryHistoryProvider);

    final favoritesPreview =
        (favoritesAsync.valueOrNull ?? const <LibraryFavoriteEntry>[])
            .where((entry) => entry.content != null)
            .map((entry) => entry.content!)
            .take(8)
            .toList();
    final historyPreview =
        (historyAsync.valueOrNull ?? const <LibraryHistoryEntry>[])
            .map((entry) => entry.content)
            .take(8)
            .toList();

    Future<void> refresh() async {
      await Future.wait([
        ref.refresh(libraryFavoritesProvider.future),
        ref.refresh(libraryHistoryProvider.future),
      ]);
    }

    final favoritesCount = favoritesAsync.valueOrNull?.length;
    final historyCount = historyAsync.valueOrNull?.length;

    return Scaffold(
      appBar: AppBar(title: const Text('库')),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _LibraryNavCard(
              title: '收藏',
              countLabel: favoritesCount != null ? '共 $favoritesCount 项' : null,
              loading: favoritesAsync.isLoading,
              previewContents: favoritesPreview ?? const [],
              onOpenContent: (content) => _openContent(context, content),
              onTap: () => context.push('/library/favorites'),
            ),
            const SizedBox(height: 16),
            _LibraryNavCard(
              title: '浏览记录',
              countLabel: historyCount != null ? '共 $historyCount 条' : null,
              loading: historyAsync.isLoading,
              previewContents: historyPreview ?? const [],
              onOpenContent: (content) => _openContent(context, content),
              onTap: () => context.push('/library/history'),
            ),
          ],
        ),
      ),
    );
  }
}

class LibraryFavoritesScreen extends ConsumerStatefulWidget {
  const LibraryFavoritesScreen({super.key});

  @override
  ConsumerState<LibraryFavoritesScreen> createState() =>
      _LibraryFavoritesScreenState();
}

class _LibraryFavoritesScreenState
    extends ConsumerState<LibraryFavoritesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Set<String> _selection = {};

  bool get _isSelecting => _selection.isNotEmpty;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    _clearSelection();
    await ref.refresh(libraryFavoritesProvider.future);
  }

  void _toggleSelection(String key) {
    setState(() {
      if (_selection.contains(key)) {
        _selection = {..._selection}..remove(key);
      } else {
        _selection = {..._selection, key};
      }
    });
  }

  void _clearSelection() {
    if (_selection.isEmpty) return;
    setState(() => _selection = {});
  }

  void _selectAll(List<LibraryFavoriteEntry> entries) {
    if (entries.isEmpty) return;
    final keys = entries.map((entry) => entry.key).toSet();
    final shouldClear =
        _selection.length == keys.length &&
        keys.every((key) => _selection.contains(key));
    setState(() {
      _selection = shouldClear ? {} : keys;
    });
  }

  Future<void> _removeSelected() async {
    final keys = _selection;
    _clearSelection();
    await ref.read(libraryFavoritesProvider.notifier).removeByKeys(keys);
  }

  List<LibraryFavoriteEntry> _filter(List<LibraryFavoriteEntry> entries) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return entries;
    }
    return entries.where((entry) => _matchesEntry(entry, query)).toList();
  }

  bool _matchesEntry(LibraryFavoriteEntry entry, String query) {
    if (entry.isContent && entry.content != null) {
      final content = entry.content!;
      final author = content.authorName ?? '';
      final tags = content.tags.map((tag) => tag.displayName).join(' ');
      final allText = [
        content.title,
        content.summary,
        author,
        content.source,
        tags,
      ].join(' ').toLowerCase();
      return allText.contains(query);
    }
    if (entry.series != null) {
      final series = entry.series!;
      final allText = [
        series.title,
        series.caption ?? '',
      ].join(' ').toLowerCase();
      return allText.contains(query);
    }
    return false;
  }

  void _handleContentTap({
    required LibraryFavoriteEntry entry,
    required List<FaioContent> orderedContents,
  }) {
    if (_isSelecting) {
      _toggleSelection(entry.key);
      return;
    }
    final content = entry.content;
    if (content == null) return;
    final initialIndex = orderedContents.indexWhere((c) => c.id == content.id);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LibraryContentPagerScreen(
          contents: orderedContents,
          initialIndex: math.max(initialIndex, 0),
        ),
      ),
    );
  }

  void _handleSeriesTap(LibraryFavoriteEntry entry) {
    if (_isSelecting) {
      _toggleSelection(entry.key);
      return;
    }
    final series = entry.series;
    if (series != null) {
      _openSeries(context, series);
    }
  }

  Widget _buildFavoritesList(List<LibraryFavoriteEntry> entries) {
    final filtered = _filter(entries);
    if (filtered.isEmpty) {
      final hasQuery = _searchController.text.trim().isNotEmpty;
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 32, 16, 32),
        children: [
          _EmptyHint(message: hasQuery ? '没有匹配的收藏' : '还没有收藏内容，去信息流点爱心吧'),
        ],
      );
    }

    final contents = filtered.where((entry) => entry.isContent).toList();
    final contentList = contents.map((entry) => entry.content!).toList();
    final series = filtered.where((entry) => entry.isSeries).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 12, 16, _isSelecting ? 96 : 24),
      children: [
        for (var i = 0; i < contents.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _LibraryContentTile(
            content: contents[i].content!,
            onTap: () => _handleContentTap(
              entry: contents[i],
              orderedContents: contentList,
            ),
            onLongPress: () => _toggleSelection(contents[i].key),
            showFavoriteToggle: !_isSelecting,
            overlay: _SelectionIndicator(
              selected: _selection.contains(contents[i].key),
              visible: _isSelecting || _selection.contains(contents[i].key),
              onTap: () => _toggleSelection(contents[i].key),
            ),
          ),
        ],
        if (contents.isNotEmpty && series.isNotEmpty)
          const SizedBox(height: 16),
        for (var i = 0; i < series.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _LibrarySeriesTile(
            series: series[i].series!,
            onTap: () => _handleSeriesTap(series[i]),
            onLongPress: () => _toggleSelection(series[i].key),
            showFavoriteToggle: !_isSelecting,
            overlay: _SelectionIndicator(
              selected: _selection.contains(series[i].key),
              visible: _isSelecting || _selection.contains(series[i].key),
              onTap: () => _toggleSelection(series[i].key),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final favoritesAsync = ref.watch(libraryFavoritesProvider);
    final entries =
        favoritesAsync.valueOrNull ?? const <LibraryFavoriteEntry>[];
    final filteredEntries = _filter(entries);
    final allSelected =
        filteredEntries.isNotEmpty &&
        filteredEntries.every((entry) => _selection.contains(entry.key));

    return Scaffold(
      appBar: AppBar(
        title: const Text('收藏'),
        actions: [
          if (_isSelecting)
            TextButton(
              onPressed: () => _selectAll(filteredEntries),
              child: Text(allSelected ? '取消全选' : '全选'),
            ),
        ],
      ),
      bottomNavigationBar: _isSelecting
          ? _SelectionBar(
              selectedCount: _selection.length,
              primaryActionLabel: '取消收藏',
              primaryIcon: Icons.favorite_border,
              onPrimaryAction: _selection.isEmpty ? null : _removeSelected,
              onClearSelection: _clearSelection,
              onSelectAll: filteredEntries.isEmpty
                  ? null
                  : () => _selectAll(filteredEntries),
              allSelected: allSelected,
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: const InputDecoration(
                labelText: '搜索标题、作者或标签',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: favoritesAsync.when(
                data: (entries) => _buildFavoritesList(entries),
                loading: () => const _ScrollableLoading(),
                error: (error, stackTrace) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 32, 16, 32),
                  children: [_SectionError(message: error.toString())],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LibraryHistoryScreen extends ConsumerStatefulWidget {
  const LibraryHistoryScreen({super.key});

  @override
  ConsumerState<LibraryHistoryScreen> createState() =>
      _LibraryHistoryScreenState();
}

class _LibraryHistoryScreenState extends ConsumerState<LibraryHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Set<String> _selection = {};

  bool get _isSelecting => _selection.isNotEmpty;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    _clearSelection();
    await ref.refresh(libraryHistoryProvider.future);
  }

  void _toggleSelection(String key) {
    setState(() {
      if (_selection.contains(key)) {
        _selection = {..._selection}..remove(key);
      } else {
        _selection = {..._selection, key};
      }
    });
  }

  void _clearSelection() {
    if (_selection.isEmpty) return;
    setState(() => _selection = {});
  }

  void _selectAll(List<LibraryHistoryEntry> entries) {
    if (entries.isEmpty) return;
    final keys = entries.map((entry) => entry.key).toSet();
    final shouldClear =
        _selection.length == keys.length &&
        keys.every((key) => _selection.contains(key));
    setState(() {
      _selection = shouldClear ? {} : keys;
    });
  }

  Future<void> _deleteSelected() async {
    final keys = _selection;
    _clearSelection();
    await ref.read(libraryHistoryProvider.notifier).removeByKeys(keys);
  }

  List<LibraryHistoryEntry> _filter(List<LibraryHistoryEntry> entries) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return entries;
    }
    return entries.where((entry) => _matchesEntry(entry, query)).toList();
  }

  bool _matchesEntry(LibraryHistoryEntry entry, String query) {
    final content = entry.content;
    final author = content.authorName ?? '';
    final tags = content.tags.map((tag) => tag.displayName).join(' ');
    final allText = [
      content.title,
      content.summary,
      content.source,
      author,
      tags,
    ].join(' ').toLowerCase();
    return allText.contains(query);
  }

  void _handleContentTap({
    required LibraryHistoryEntry entry,
    required List<FaioContent> orderedContents,
  }) {
    if (_isSelecting) {
      _toggleSelection(entry.key);
      return;
    }
    final initialIndex = orderedContents.indexWhere(
      (content) => content.id == entry.content.id,
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LibraryContentPagerScreen(
          contents: orderedContents,
          initialIndex: math.max(initialIndex, 0),
        ),
      ),
    );
  }

  Future<void> _confirmClearHistory() async {
    final theme = Theme.of(context);
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空浏览记录'),
        content: const Text('确认要清空所有浏览记录吗？该操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (shouldClear == true) {
      await ref.read(libraryHistoryProvider.notifier).clearHistory();
    }
  }

  Widget _buildHistoryList(List<LibraryHistoryEntry> entries) {
    final filtered = _filter(entries);
    if (filtered.isEmpty) {
      final hasQuery = _searchController.text.trim().isNotEmpty;
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 32, 16, 32),
        children: [
          _EmptyHint(message: hasQuery ? '没有匹配的浏览记录' : '最近浏览的内容会出现在这里'),
        ],
      );
    }

    final contentList = filtered.map((entry) => entry.content).toList();

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 12, 16, _isSelecting ? 96 : 24),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final entry = filtered[index];
        return Padding(
          padding: EdgeInsets.only(
            bottom: index == filtered.length - 1 ? 0 : 12,
          ),
          child: _LibraryContentTile(
            content: entry.content,
            viewedAt: entry.viewedAt,
            onTap: () =>
                _handleContentTap(entry: entry, orderedContents: contentList),
            onLongPress: () => _toggleSelection(entry.key),
            overlay: _SelectionIndicator(
              selected: _selection.contains(entry.key),
              visible: _isSelecting || _selection.contains(entry.key),
              onTap: () => _toggleSelection(entry.key),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(libraryHistoryProvider);
    final entries = historyAsync.valueOrNull ?? const <LibraryHistoryEntry>[];
    final filteredEntries = _filter(entries);
    final allSelected =
        filteredEntries.isNotEmpty &&
        filteredEntries.every((entry) => _selection.contains(entry.key));

    return Scaffold(
      appBar: AppBar(
        title: const Text('浏览记录'),
        actions: [
          if (_isSelecting)
            TextButton(
              onPressed: () => _selectAll(filteredEntries),
              child: Text(allSelected ? '取消全选' : '全选'),
            )
          else if (entries.isNotEmpty)
            TextButton(
              onPressed: _confirmClearHistory,
              child: const Text('清空'),
            ),
        ],
      ),
      bottomNavigationBar: _isSelecting
          ? _SelectionBar(
              selectedCount: _selection.length,
              primaryActionLabel: '删除',
              onPrimaryAction: _selection.isEmpty ? null : _deleteSelected,
              onClearSelection: _clearSelection,
              onSelectAll: filteredEntries.isEmpty
                  ? null
                  : () => _selectAll(filteredEntries),
              allSelected: allSelected,
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: const InputDecoration(
                labelText: '搜索标题、作者或标签',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: historyAsync.when(
                data: (entries) => _buildHistoryList(entries),
                loading: () => const _ScrollableLoading(),
                error: (error, stackTrace) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 32, 16, 32),
                  children: [_SectionError(message: error.toString())],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryContentTile extends StatelessWidget {
  const _LibraryContentTile({
    required this.content,
    required this.onTap,
    this.viewedAt,
    this.showFavoriteToggle = false,
    this.onLongPress,
    this.overlay,
  });

  final FaioContent content;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final DateTime? viewedAt;
  final bool showFavoriteToggle;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metaParts = [
      _typeLabel(content.type),
      content.source,
      if (content.authorName != null && content.authorName!.isNotEmpty)
        content.authorName!,
    ];
    final meta = metaParts.where((part) => part.trim().isNotEmpty).join(' · ');
    final summary = content.summary.trim().isNotEmpty
        ? content.summary.trim()
        : (content.tags.isNotEmpty
              ? content.tags.map((tag) => tag.displayName).join(', ')
              : '暂无简介');

    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(
        theme.brightness == Brightness.dark ? 0.35 : 0.5,
      ),
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            onLongPress: onLongPress,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ContentThumbnail(content: content),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          content.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          meta,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (viewedAt != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '浏览于 ${_formatDate(viewedAt!)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  if (showFavoriteToggle) ...[
                    const SizedBox(width: 8),
                    FavoriteIconButton.content(
                      content: content,
                      backgroundColor: Colors.transparent,
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (overlay != null) Positioned(top: 8, right: 8, child: overlay!),
        ],
      ),
    );
  }
}

class _LibrarySeriesTile extends StatelessWidget {
  const _LibrarySeriesTile({
    required this.series,
    required this.onTap,
    this.onLongPress,
    this.overlay,
    this.showFavoriteToggle = true,
  });

  final LibrarySeriesFavorite series;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget? overlay;
  final bool showFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(
        theme.brightness == Brightness.dark ? 0.35 : 0.45,
      ),
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            onLongPress: onLongPress,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.collections_bookmark,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          series.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (series.caption != null &&
                            series.caption!.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            series.caption!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (showFavoriteToggle)
                    FavoriteIconButton.series(
                      series: series,
                      backgroundColor: Colors.transparent,
                      padding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
          ),
          if (overlay != null) Positioned(top: 8, right: 8, child: overlay!),
        ],
      ),
    );
  }
}

class _LibraryNavCard extends StatelessWidget {
  const _LibraryNavCard({
    required this.title,
    required this.onTap,
    this.countLabel,
    this.loading = false,
    required this.previewContents,
    this.onOpenContent,
  });

  final String title;
  final VoidCallback onTap;
  final String? countLabel;
  final bool loading;
  final List<FaioContent> previewContents;
  final ValueChanged<FaioContent>? onOpenContent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surfaceContainerHighest.withOpacity(
      theme.brightness == Brightness.dark ? 0.32 : 0.5,
    );
    final items = previewContents.take(6).toList();
    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (countLabel != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      countLabel!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (loading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurface,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                Row(
                  children: [
                    Text(
                      '暂无内容',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    TextButton(onPressed: onTap, child: const Text('查看更多')),
                  ],
                )
              else
                SizedBox(
                  height: 110,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      if (index == items.length) {
                        return _ViewMoreTile(onTap: onTap);
                      }
                      final content = items[index];
                      return _PreviewTile(
                        content: content,
                        onTap: () => onOpenContent?.call(content),
                      );
                    },
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 10),
                    itemCount: items.length + 1,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({required this.content, this.onTap});

  final FaioContent content;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 88,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: _ContentThumbnail(content: content),
            ),
            const SizedBox(height: 6),
            Text(
              content.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewMoreTile extends StatelessWidget {
  const _ViewMoreTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 88,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 80,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(
                    theme.brightness == Brightness.dark ? 0.24 : 0.4,
                  ),
                ),
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: theme.colorScheme.onSurface,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '查看更多',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
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

class LibraryContentPagerScreen extends StatefulWidget {
  const LibraryContentPagerScreen({
    required this.contents,
    this.initialIndex = 0,
    super.key,
  }) : assert(contents.length > 0);

  final List<FaioContent> contents;
  final int initialIndex;

  @override
  State<LibraryContentPagerScreen> createState() =>
      _LibraryContentPagerScreenState();
}

class _LibraryContentPagerScreenState extends State<LibraryContentPagerScreen> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.contents.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.contents.length;
    return Scaffold(
      body: PageView.builder(
        controller: _controller,
        onPageChanged: (value) => setState(() => _index = value),
        itemCount: total,
        itemBuilder: (context, index) {
          final content = widget.contents[index];
          return _buildDetailPage(content, index);
        },
      ),
    );
  }

  Widget _buildDetailPage(FaioContent content, int index) {
    if (content.type == ContentType.novel) {
      final novelId = parseContentNumericId(content);
      if (novelId != null) {
        return NovelDetailScreen(
          key: ValueKey('libraryPager-novel-${content.id}'),
          novelId: novelId,
          initialContent: content,
          initialIndex: index,
          skipInitialWarningPrompt: true,
          enableFeedPager: false,
        );
      }
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: _LibraryContentPreview(content: content),
        ),
      );
    }

    final illustrationSource = _mapIllustrationSource(content.source);
    if (illustrationSource != null) {
      return IllustrationDetailScreen(
        key: ValueKey('libraryPager-illust-${content.id}'),
        source: illustrationSource,
        initialIndex: index,
        initialContent: content,
        skipInitialWarningPrompt: true,
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: _LibraryContentPreview(content: content),
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.selectedCount,
    required this.primaryActionLabel,
    required this.onPrimaryAction,
    required this.onClearSelection,
    this.onSelectAll,
    this.allSelected = false,
    this.primaryIcon = Icons.delete_forever,
  });

  final int selectedCount;
  final String primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final VoidCallback onClearSelection;
  final VoidCallback? onSelectAll;
  final bool allSelected;
  final IconData primaryIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              Text('$selectedCount 项已选', style: theme.textTheme.bodyMedium),
              const SizedBox(width: 12),
              if (onSelectAll != null)
                TextButton(
                  onPressed: onSelectAll,
                  child: Text(allSelected ? '取消全选' : '全选'),
                ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: onClearSelection,
                child: const Text('取消'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: onPrimaryAction,
                icon: Icon(primaryIcon),
                label: Text(primaryActionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionIndicator extends StatelessWidget {
  const _SelectionIndicator({
    required this.selected,
    required this.visible,
    required this.onTap,
  });

  final bool selected;
  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (!visible && !selected) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      shape: const CircleBorder(),
      elevation: 1,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            selected ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 22,
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
          ),
        ),
      ),
    );
  }
}

class _ScrollableLoading extends StatelessWidget {
  const _ScrollableLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 32),
      children: const [
        SizedBox(
          height: 160,
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
    );
  }
}

class _SectionError extends StatelessWidget {
  const _SectionError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Center(child: Text('加载失败：$message', textAlign: TextAlign.center)),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(
          theme.brightness == Brightness.dark ? 0.24 : 0.4,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ContentThumbnail extends StatefulWidget {
  const _ContentThumbnail({required this.content});

  final FaioContent content;

  @override
  State<_ContentThumbnail> createState() => _ContentThumbnailState();
}

class _ContentThumbnailState extends State<_ContentThumbnail> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final preview =
        widget.content.previewUrl ??
        widget.content.sampleUrl ??
        widget.content.originalUrl;
    final theme = Theme.of(context);
    final placeholder = Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Icon(
        widget.content.type == ContentType.novel
            ? Icons.menu_book_outlined
            : Icons.image_outlined,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );

    if (preview == null) {
      return placeholder;
    }
    final urls = pixivImageUrlCandidates(preview);
    final headers = pixivImageHeaders(content: widget.content, url: preview);
    final currentUrl = urls[_index];
    final imageProvider = CachedNetworkImageProvider(
      currentUrl.toString(),
      headers: headers,
      cacheManager: pixivImageCacheManagerForUrl(currentUrl),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 72,
        height: 72,
        child: Image(
          image: imageProvider,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            if (_index < urls.length - 1) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() {
                  _index += 1;
                });
              });
              return const SizedBox.shrink();
            }
            return placeholder;
          },
        ),
      ),
    );
  }
}

class _LibraryContentPreview extends StatelessWidget {
  const _LibraryContentPreview({required this.content});

  final FaioContent content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview =
        content.sampleUrl ?? content.previewUrl ?? content.originalUrl;
    final summary = content.summary.trim().isNotEmpty
        ? content.summary
        : '暂无简介';
    final tags = content.tags;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              content.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (preview != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: (content.previewAspectRatio ?? 1)
                      .clamp(0.5, 1.6)
                      .toDouble(),
                  child: _PreviewImage(content: content, url: preview),
                ),
              ),
            const SizedBox(height: 12),
            Text(summary, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 12),
            Text(
              '来源：${content.source}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (content.authorName != null &&
                content.authorName!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '作者：${content.authorName}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (tags.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tags
                    .map((tag) => TagChip(tag: tag, compact: true))
                    .toList(),
              ),
            if (content.sourceLinks.isNotEmpty ||
                content.originalUrl != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.open_in_new),
                onPressed: () {
                  final target =
                      content.originalUrl ?? content.sourceLinks.firstOrNull;
                  if (target != null) {
                    _launchExternal(context, target);
                  }
                },
                label: const Text('打开原站'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PreviewImage extends StatefulWidget {
  const _PreviewImage({required this.content, required this.url});

  final FaioContent content;
  final Uri url;

  @override
  State<_PreviewImage> createState() => _PreviewImageState();
}

class _PreviewImageState extends State<_PreviewImage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final urls = pixivImageUrlCandidates(widget.url);
    final headers = pixivImageHeaders(content: widget.content, url: widget.url);
    final theme = Theme.of(context);

    final currentUrl = urls[_index];
    final imageProvider = CachedNetworkImageProvider(
      currentUrl.toString(),
      headers: headers,
      cacheManager: pixivImageCacheManagerForUrl(currentUrl),
    );
    return Image(
      image: imageProvider,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        if (_index < urls.length - 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _index += 1);
          });
          return const SizedBox.shrink();
        }
        return Container(
          color: theme.colorScheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: Icon(
            Icons.broken_image,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        );
      },
    );
  }
}

Future<void> _openContent(BuildContext context, FaioContent content) async {
  if (content.type == ContentType.novel) {
    final novelId = parseContentNumericId(content);
    if (novelId == null) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(const SnackBar(content: Text('无法解析小说 ID')));
      return;
    }
    context.push('/feed/novel/$novelId', extra: content);
    return;
  }

  final source = _mapIllustrationSource(content.source);
  if (source != null) {
    context.pushNamed(
      'feed_detail',
      extra: IllustrationDetailRouteArgs(
        source: source,
        initialIndex: 0,
        initialContent: content,
        skipInitialWarningPrompt: true,
      ),
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _LibraryContentPreview(content: content),
  );
}

Future<void> _openSeries(
  BuildContext context,
  LibrarySeriesFavorite series,
) async {
  final selected = await showNovelSeriesSheet(
    context: context,
    seriesId: series.seriesId,
  );
  if (selected == null) {
    return;
  }
  context.push('/feed/novel/$selected');
}

Future<void> _launchExternal(BuildContext context, Uri url) async {
  if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text('无法打开链接：${url.toString()}')));
  }
}

IllustrationSource? _mapIllustrationSource(String source) {
  switch (source.toLowerCase()) {
    case 'pixiv':
      return IllustrationSource.pixiv;
    case 'e621':
      return IllustrationSource.e621;
    default:
      return null;
  }
}

String _typeLabel(ContentType type) {
  switch (type) {
    case ContentType.illustration:
      return '插画';
    case ContentType.comic:
      return '漫画';
    case ContentType.novel:
      return '小说';
    case ContentType.audio:
      return '音频';
  }
}

String _formatDate(DateTime dateTime) {
  final local = dateTime.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

extension FirstOrNullExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : this[0];
}
