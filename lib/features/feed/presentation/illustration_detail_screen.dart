import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:faio/domain/models/content_item.dart';
import 'package:faio/features/common/widgets/detail_section_card.dart';
import 'package:faio/features/library/providers/library_providers.dart';

import '../providers/feed_providers.dart';
import 'illustration_gallery_screen.dart';

Map<String, String>? _imageHeadersFor(FaioContent content) {
  final source = content.source.toLowerCase();
  if (source.startsWith('pixiv')) {
    return const {
      'Referer': 'https://app-api.pixiv.net/',
      'User-Agent': 'PixivAndroidApp/5.0.234 (Android 11; Pixel 5)',
    };
  }
  return null;
}

class IllustrationDetailScreen extends ConsumerStatefulWidget {
  const IllustrationDetailScreen({required this.initialIndex, super.key});

  final int initialIndex;

  @override
  ConsumerState<IllustrationDetailScreen> createState() =>
      _IllustrationDetailScreenState();
}

class _IllustrationDetailScreenState
    extends ConsumerState<IllustrationDetailScreen> {
  late int _currentIndex;
  bool _ensurePending = false;
  String? _lastRecordedId;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(feedSelectionProvider.notifier).select(_currentIndex);
      ref
          .read(feedControllerProvider.notifier)
          .ensureIndexLoaded(_currentIndex);
    });
  }

  void _ensureIndexLoaded() {
    if (!mounted) return;
    if (_ensurePending) return;
    _ensurePending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await ref
          .read(feedControllerProvider.notifier)
          .ensureIndexLoaded(_currentIndex);
      _ensurePending = false;
    });
  }

  void _recordView(FaioContent content) {
    if (_lastRecordedId == content.id) {
      return;
    }
    _lastRecordedId = content.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(libraryHistoryProvider.notifier).recordView(content);
    });
  }

  Uri? _primarySourceLink(FaioContent content) {
    if (content.originalUrl != null) {
      return content.originalUrl;
    }
    if (content.sourceLinks.isNotEmpty) {
      return content.sourceLinks.first;
    }
    return null;
  }

  Future<void> _openSourceLink(BuildContext context, Uri url) async {
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开链接：${url.host}')),
      );
    }
  }

  Future<void> _openGallery() async {
    final result = await Navigator.of(context, rootNavigator: true).push<int>(
      PageRouteBuilder(
        pageBuilder: (context, _, __) =>
            IllustrationGalleryScreen(initialIndex: _currentIndex),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );

    if (!mounted) return;

    if (result != null && result != _currentIndex) {
      setState(() {
        _currentIndex = result;
        _lastRecordedId = null;
      });
      ref.read(feedSelectionProvider.notifier).select(result);
      ref.read(feedControllerProvider.notifier).ensureIndexLoaded(result);
    }
  }

  void _requestScrollBack() {
    if (!mounted) return;
    ref.read(feedSelectionProvider.notifier).requestScrollTo(_currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedControllerProvider);

    ref.listen<FeedSelectionState>(feedSelectionProvider, (prev, next) {
      if (!mounted) return;
      final selected = next.selectedIndex;
      if (selected != null && selected != _currentIndex) {
        setState(() {
          _currentIndex = selected;
          _lastRecordedId = null;
        });
      }
    });

    final theme = Theme.of(context);

    if (_currentIndex < 0) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('未找到内容')),
      );
    }

    FaioContent? maybeContent;
    if (_currentIndex < feedState.items.length) {
      maybeContent = feedState.items[_currentIndex];
    } else if (feedState.hasMore) {
      _ensureIndexLoaded();
    }

    if (maybeContent == null) {
      final isLoading = feedState.isLoadingInitial || feedState.isLoadingMore;
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: isLoading
              ? const CircularProgressIndicator()
              : const Text('正在加载更多内容…'),
        ),
      );
    }

    final content = maybeContent;
    _recordView(content);
    final isFavorite = ref.watch(
      libraryFavoritesProvider.select((asyncValue) {
        final entries = asyncValue.valueOrNull;
        if (entries == null) {
          return false;
        }
        return entries.any(
          (entry) => entry.isContent && entry.content!.id == content.id,
        );
      }),
    );
    final aspectRatio = content.previewAspectRatio ?? 1;
    final hasSummary = content.summary.trim().isNotEmpty;
    final detailImageUrl = content.sampleUrl ?? content.previewUrl;
    final fallbackPreviewUrl = content.previewUrl;
    final primaryLink = _primarySourceLink(content);

    String formatDateTime(DateTime? dateTime) {
      if (dateTime == null) {
        return '未知';
      }
      final local = dateTime.toLocal();
      return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
          '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }

    final formattedCreatedAt = formatDateTime(content.publishedAt);
    final formattedUpdatedAt = formatDateTime(content.updatedAt);

    Widget placeholder(IconData icon) {
      return Container(
        height: 280,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Icon(icon, color: theme.colorScheme.onSurfaceVariant, size: 48),
      );
    }

    Widget buildHero() {
      if (detailImageUrl == null) {
        return placeholder(Icons.image);
      }
      return GestureDetector(
        onTap: _openGallery,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: aspectRatio > 0 ? aspectRatio : 1,
                child: Image.network(
                  detailImageUrl.toString(),
                  fit: BoxFit.cover,
                  headers: _imageHeadersFor(content),
                  errorBuilder: (_, __, ___) => placeholder(Icons.broken_image),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) {
                      return child;
                    }
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        if (fallbackPreviewUrl != null)
                          Image.network(
                            fallbackPreviewUrl.toString(),
                            fit: BoxFit.cover,
                            headers: _imageHeadersFor(content),
                            errorBuilder: (_, __, ___) =>
                                placeholder(Icons.broken_image),
                          ),
                        const Center(child: CircularProgressIndicator()),
                      ],
                    );
                  },
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.35),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget buildMetaCard() {
      final chips = <Widget>[
        if (content.rating.isNotEmpty)
          _MetaChip(
            icon: Icons.shield,
            label: '评级 ${content.rating}',
          ),
        _MetaChip(
          icon: Icons.schedule,
          label: '发布 $formattedCreatedAt',
        ),
        _MetaChip(
          icon: Icons.update,
          label: '更新 $formattedUpdatedAt',
        ),
        _MetaChip(
          icon: Icons.people_alt_outlined,
          label: content.authorName?.isNotEmpty == true
              ? content.authorName!
              : '匿名作者',
        ),
      ];
      return DetailSectionCard(
        title: '作品信息',
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: chips,
        ),
      );
    }

    Widget buildPrimaryActions() {
      final baseCount = content.favoriteCount;
      final displayCount = baseCount + (isFavorite ? 1 : 0);
      final favoriteLabelBase = isFavorite ? '已收藏' : '收藏';
      final favoriteLabel = '$favoriteLabelBase（$displayCount）';
      return Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              icon: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
              ),
              label: Text(favoriteLabel),
              onPressed: () {
                ref
                    .read(libraryFavoritesProvider.notifier)
                    .toggleContentFavorite(content);
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: Text(primaryLink == null ? '暂无外链' : '打开原站'),
              onPressed: primaryLink == null
                  ? null
                  : () => _openSourceLink(context, primaryLink),
            ),
          ),
        ],
      );
    }

    Widget buildSummaryCard() {
      return DetailSectionCard(
        title: '简介',
        child: SelectableText(
          hasSummary ? content.summary : '暂无简介',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    Widget buildTagsCard() {
      return DetailSectionCard(
        title: '标签',
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: content.tags
              .map(
                (tag) => Chip(
                  label: Text(tag),
                  backgroundColor: theme.colorScheme.surfaceVariant,
                ),
              )
              .toList(),
        ),
      );
    }

    Widget buildSourceCard() {
      return DetailSectionCard(
        title: '来源链接',
        child: Column(
          children: [
            for (var i = 0; i < content.sourceLinks.length; i++) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  content.sourceLinks[i].host,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  content.sourceLinks[i].toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _openSourceLink(context, content.sourceLinks[i]),
              ),
              if (i < content.sourceLinks.length - 1)
                const Divider(height: 12),
            ],
          ],
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        _requestScrollBack();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            content.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            buildHero(),
            const SizedBox(height: 20),
            Text(
              content.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            buildPrimaryActions(),
            const SizedBox(height: 20),
            buildMetaCard(),
            const SizedBox(height: 20),
            buildSummaryCard(),
            if (content.tags.isNotEmpty) ...[
              const SizedBox(height: 20),
              buildTagsCard(),
            ],
            if (content.sourceLinks.isNotEmpty) ...[
              const SizedBox(height: 20),
              buildSourceCard(),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      backgroundColor: theme.colorScheme.surfaceVariant,
    );
  }
}
