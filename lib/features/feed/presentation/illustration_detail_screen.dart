import 'dart:math' as math;

import 'package:animations/animations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:faio/domain/models/content_item.dart';
import 'package:faio/features/common/widgets/detail_section_card.dart';
import 'package:faio/features/library/providers/library_providers.dart';

import '../providers/feed_providers.dart';
import 'illustration_hero.dart';

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

Uri? _primarySourceLink(FaioContent content) {
  if (content.originalUrl != null) {
    return content.originalUrl;
  }
  if (content.sourceLinks.isNotEmpty) {
    return content.sourceLinks.first;
  }
  return null;
}

String _formatDateTime(DateTime? dateTime) {
  if (dateTime == null) {
    return '未知';
  }
  final local = dateTime.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
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
  String? _lastRecordedId;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(feedSelectionProvider.notifier).select(_currentIndex);
      ref
          .read(feedControllerProvider.notifier)
          .ensureIndexLoaded(_currentIndex);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _animateToIndex(int index) async {
    if (!_pageController.hasClients) {
      return;
    }
    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
  }

  void _handlePageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _lastRecordedId = null;
    });
    final selection = ref.read(feedSelectionProvider.notifier);
    selection.select(index);
    final controller = ref.read(feedControllerProvider.notifier);
    controller.ensureIndexLoaded(index + 1);
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

  Future<void> _openSourceLink(BuildContext context, Uri url) async {
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开链接：${url.host}')),
      );
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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _animateToIndex(selected);
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

    final favoritesValue = ref.watch(libraryFavoritesProvider);
    final favoriteIds = favoritesValue.maybeWhen(
      data: (entries) => entries
          .where((entry) => entry.isContent && entry.content != null)
          .map((entry) => entry.content!.id)
          .toSet(),
      orElse: () => <String>{},
    );

    final items = feedState.items;
    if (items.isEmpty && feedState.isLoadingInitial) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (items.isEmpty && !feedState.hasMore) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('暂时没有可展示的插画')),
      );
    }

    final baseCount = feedState.hasMore ? items.length + 1 : items.length;
    final minCount = math.max(widget.initialIndex + 1, _currentIndex + 1);
    final itemCount = math.max(baseCount, minCount);
    final currentTitle = (_currentIndex >= 0 && _currentIndex < items.length)
        ? items[_currentIndex].title
        : '作品详情';

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
            currentTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: PageView.builder(
          controller: _pageController,
          onPageChanged: _handlePageChanged,
          itemCount: math.max(1, itemCount),
          itemBuilder: (context, index) {
            if (index >= items.length) {
              if (feedState.hasMore) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  ref
                      .read(feedControllerProvider.notifier)
                      .ensureIndexLoaded(index);
                });
                return const _DetailLoadingPlaceholder();
              }
              return const _DetailEndOfListPlaceholder();
            }
            final content = items[index];
            _recordView(content);
            final isFavorite = favoriteIds.contains(content.id);
            return _IllustrationDetailView(
              key: ValueKey(content.id),
              content: content,
              isFavorite: isFavorite,
              onToggleFavorite: () {
                ref
                    .read(libraryFavoritesProvider.notifier)
                    .toggleContentFavorite(content);
              },
              onOpenSource: (url) => _openSourceLink(context, url),
              primaryLink: _primarySourceLink(content),
            );
          },
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

class _IllustrationDetailView extends StatelessWidget {
  const _IllustrationDetailView({
    super.key,
    required this.content,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onOpenSource,
    required this.primaryLink,
  });

  final FaioContent content;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final void Function(Uri url) onOpenSource;
  final Uri? primaryLink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aspectRatio = (content.previewAspectRatio ?? 1).clamp(0.4, 1.8);
    final hasSummary = content.summary.trim().isNotEmpty;
    final heroPreview = content.previewUrl ?? content.sampleUrl ?? content.originalUrl;
    final heroHighRes = content.sampleUrl ?? content.originalUrl ?? content.previewUrl;

    Widget placeholder(IconData icon) {
      return Container(
        height: 280,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Icon(icon, color: theme.colorScheme.onSurfaceVariant, size: 48),
      );
    }

    Widget buildHero() {
      if (heroPreview == null && heroHighRes == null) {
        return placeholder(Icons.image);
      }
      final heroChild = OpenContainer(
        closedElevation: 0,
        openElevation: 0,
        closedColor: Colors.transparent,
        openColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 420),
        transitionType: ContainerTransitionType.fadeThrough,
        closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        tappable: false,
        openBuilder: (context, _) => _IllustrationFullscreenView(content: content),
        closedBuilder: (context, openContainer) {
          return InkWell(
            onTap: openContainer,
            borderRadius: BorderRadius.circular(28),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: AspectRatio(
                aspectRatio: aspectRatio > 0 ? aspectRatio : 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _ProgressiveIllustrationImage(
                      content: content,
                      lowRes: heroPreview,
                      highRes: heroHighRes,
                      fit: BoxFit.cover,
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.4),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      return Hero(
        tag: illustrationHeroTag(content.id),
        transitionOnUserGestures: true,
        createRectTween: illustrationHeroRectTween,
        child: heroChild,
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
              icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
              label: Text(favoriteLabel),
              onPressed: onToggleFavorite,
            ),
          ),
        ],
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
          label: '发布 ${_formatDateTime(content.publishedAt)}',
        ),
        _MetaChip(
          icon: Icons.update,
          label: '更新 ${_formatDateTime(content.updatedAt)}',
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
      if (content.sourceLinks.isEmpty) {
        return const SizedBox.shrink();
      }
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
                onTap: () => onOpenSource(content.sourceLinks[i]),
              ),
              if (i < content.sourceLinks.length - 1)
                const Divider(height: 12),
            ],
          ],
        ),
      );
    }

    return ListView(
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
        const SizedBox(height: 8),
        Text(
          content.authorName?.isNotEmpty == true
              ? content.authorName!
              : '匿名作者',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
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
    );
  }
}

class _ProgressiveIllustrationImage extends StatefulWidget {
  const _ProgressiveIllustrationImage({
    required this.content,
    this.lowRes,
    this.highRes,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
  });

  final FaioContent content;
  final Uri? lowRes;
  final Uri? highRes;
  final BoxFit fit;
  final AlignmentGeometry alignment;

  @override
  State<_ProgressiveIllustrationImage> createState() =>
      _ProgressiveIllustrationImageState();
}

class _ProgressiveIllustrationImageState
    extends State<_ProgressiveIllustrationImage> {
  bool _highResLoaded = false;

  @override
  void didUpdateWidget(covariant _ProgressiveIllustrationImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highRes?.toString() != oldWidget.highRes?.toString()) {
      _highResLoaded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = Theme.of(context).colorScheme.surfaceVariant;
    final layers = <Widget>[
      Positioned.fill(
        child: widget.lowRes != null
            ? Image(
                image: CachedNetworkImageProvider(
                  widget.lowRes.toString(),
                  headers: _imageHeadersFor(widget.content),
                ),
                fit: widget.fit,
                alignment: widget.alignment,
                errorBuilder: (_, __, ___) => Container(color: backgroundColor),
              )
            : Container(color: backgroundColor),
      ),
    ];

    if (widget.highRes != null) {
      layers.add(
        Positioned.fill(
          child: AnimatedOpacity(
            opacity: _highResLoaded ? 1 : 0,
            duration: const Duration(milliseconds: 320),
            child: Image(
              image: CachedNetworkImageProvider(
                widget.highRes.toString(),
                headers: _imageHeadersFor(widget.content),
              ),
              fit: widget.fit,
              alignment: widget.alignment,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null && !_highResLoaded) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() => _highResLoaded = true);
                    }
                  });
                }
                return child;
              },
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: layers,
    );
  }
}

class _IllustrationFullscreenView extends StatelessWidget {
  const _IllustrationFullscreenView({required this.content});

  final FaioContent content;

  @override
  Widget build(BuildContext context) {
    final preview = content.previewUrl ?? content.sampleUrl ?? content.originalUrl;
    final highRes = content.originalUrl ?? content.sampleUrl ?? content.previewUrl;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: _ProgressiveIllustrationImage(
                content: content,
                lowRes: preview,
                highRes: highRes,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 12,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 32,
            left: 24,
            right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  content.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${content.authorName?.isNotEmpty == true ? content.authorName! : '匿名作者'} · ${content.rating.isNotEmpty ? content.rating : '未知评级'}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailLoadingPlaceholder extends StatelessWidget {
  const _DetailLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            '加载更多插画中…',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailEndOfListPlaceholder extends StatelessWidget {
  const _DetailEndOfListPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        '已经是最后一张插画啦',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
