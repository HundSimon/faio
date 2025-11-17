import 'dart:math' as math;

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:faio/core/preferences/content_safety_settings.dart';
import 'package:faio/data/pixiv/pixiv_image_cache.dart';
import 'package:faio/domain/models/content_item.dart';
import 'package:faio/domain/utils/pixiv_image_utils.dart';
import 'package:faio/features/common/utils/content_warning.dart';
import 'package:faio/features/common/widgets/categorized_tags.dart';
import 'package:faio/features/common/widgets/content_warning_banner.dart';
import 'package:faio/features/common/widgets/detail_info_row.dart';
import 'package:faio/features/common/widgets/detail_section_card.dart';
import 'package:faio/features/common/widgets/summary_placeholder.dart';
import 'package:faio/features/library/providers/library_providers.dart';

import '../providers/feed_providers.dart';
import 'illustration_hero.dart';
import 'widgets/progressive_illustration_image.dart';

Uri? _primarySourceLink(FaioContent content) {
  if (content.source == 'e621') {
    final rawId = content.id.split(':').last;
    final numericId = int.tryParse(rawId);
    if (numericId != null) {
      return Uri.parse('https://e621.net/posts/$numericId');
    }
  }
  if (content.sourceLinks.isNotEmpty) {
    return content.sourceLinks.first;
  }
  if (content.originalUrl != null) {
    return content.originalUrl;
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

class IllustrationDetailRouteArgs {
  const IllustrationDetailRouteArgs({
    required this.source,
    required this.initialIndex,
  });

  final IllustrationSource source;
  final int initialIndex;
}

class IllustrationDetailScreen extends ConsumerStatefulWidget {
  const IllustrationDetailScreen({
    required this.source,
    required this.initialIndex,
    super.key,
  });

  final IllustrationSource source;
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
      ref
          .read(feedSelectionProvider.notifier)
          .select(widget.source, _currentIndex);
      ref
          .read(illustrationFeedControllerProvider(widget.source).notifier)
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
    selection.select(widget.source, index);
    final controller = ref.read(
      illustrationFeedControllerProvider(widget.source).notifier,
    );
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
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无法打开链接：${url.host}')));
    }
  }

  void _requestScrollBack() {
    if (!mounted) return;
    ref
        .read(feedSelectionProvider.notifier)
        .requestScrollTo(widget.source, _currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(
      illustrationFeedControllerProvider(widget.source),
    );

    ref.listen<FeedSelectionState>(feedSelectionProvider, (prev, next) {
      if (!mounted) return;
      if (next.selectedSource != widget.source) {
        return;
      }
      final selected = next.selectedIndex;
      if (selected != null && selected != _currentIndex) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _animateToIndex(selected);
        });
      }
    });

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
                      .read(
                        illustrationFeedControllerProvider(
                          widget.source,
                        ).notifier,
                      )
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
              safetySettings: ref.watch(contentSafetySettingsProvider),
            );
          },
        ),
      ),
    );
  }
}

class _IllustrationDetailView extends StatefulWidget {
  const _IllustrationDetailView({
    super.key,
    required this.content,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onOpenSource,
    required this.primaryLink,
    required this.safetySettings,
  });

  final FaioContent content;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final void Function(Uri url) onOpenSource;
  final Uri? primaryLink;
  final ContentSafetySettings safetySettings;

  @override
  State<_IllustrationDetailView> createState() =>
      _IllustrationDetailViewState();
}

class _IllustrationDetailViewState extends State<_IllustrationDetailView>
    with SingleTickerProviderStateMixin {
  late final ContentWarning? _warning;
  late bool _warningAcknowledged;
  late final AnimationController _favoriteBurstController;
  late final Animation<double> _burstOpacity;
  late final Animation<double> _burstScale;
  var _isSavingImage = false;

  @override
  void initState() {
    super.initState();
    _warning = evaluateContentWarning(
      rating: widget.content.rating,
      tags: widget.content.tags,
    );
    _warningAcknowledged = widget.safetySettings.isAutoApproved(
      _warning?.level,
    );
    _favoriteBurstController = AnimationController(
      duration: const Duration(milliseconds: 420),
      vsync: this,
    );
    _burstOpacity = CurvedAnimation(
      parent: _favoriteBurstController,
      curve: const Interval(0, 0.8, curve: Curves.easeOut),
    );
    _burstScale = Tween<double>(begin: 0.6, end: 1.2).animate(
      CurvedAnimation(
        parent: _favoriteBurstController,
        curve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _favoriteBurstController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _IllustrationDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.safetySettings != widget.safetySettings) {
      final allowed = widget.safetySettings.isAutoApproved(_warning?.level);
      if (allowed != _warningAcknowledged) {
        setState(() {
          _warningAcknowledged = allowed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = widget.content;
    final aspectRatio = (content.previewAspectRatio ?? 1).clamp(0.4, 1.8);
    final heroPreview =
        content.previewUrl ?? content.sampleUrl ?? content.originalUrl;
    final heroHighRes =
        content.sampleUrl ?? content.originalUrl ?? content.previewUrl;
    final hasSummary = content.summary.trim().isNotEmpty;
    final warning = _warning;
    final isBlocked = widget.safetySettings.isBlocked(warning?.level);
    final shouldGate =
        warning?.requiresConfirmation == true && !_warningAcknowledged;

    if (isBlocked && warning != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.visibility_off_outlined,
                color: theme.colorScheme.onSurfaceVariant,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                '${warning.label} 内容已被屏蔽',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '可在设置中允许显示该分级后重新查看。',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final body = ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _buildHero(context, aspectRatio, heroPreview, heroHighRes),
        const SizedBox(height: 20),
        Text(
          content.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content.authorName?.isNotEmpty == true ? content.authorName! : '匿名作者',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (warning != null) ...[
          const SizedBox(height: 20),
          ContentWarningBanner(warning: warning),
        ],
        const SizedBox(height: 20),
        _buildPrimaryActions(context),
        const SizedBox(height: 20),
        _buildMetaCard(context),
        const SizedBox(height: 20),
        _buildSummaryCard(context, hasSummary),
        if (content.tags.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildTagsCard(),
        ],
        if (content.sourceLinks.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildSourceCard(context),
        ],
      ],
    );

    return Stack(
      children: [
        body,
        if (shouldGate && warning != null)
          Positioned.fill(
            child: ContentWarningOverlay(
              warning: warning,
              onConfirm: () => setState(() => _warningAcknowledged = true),
              onDismiss: () {
                Navigator.of(context).maybePop();
              },
            ),
          ),
      ],
    );
  }

  Widget _buildHero(
    BuildContext context,
    double aspectRatio,
    Uri? heroPreview,
    Uri? heroHighRes,
  ) {
    final theme = Theme.of(context);
    if (heroPreview == null && heroHighRes == null) {
      return Container(
        height: 280,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Icon(
          Icons.image,
          color: theme.colorScheme.onSurfaceVariant,
          size: 48,
        ),
      );
    }
    final content = widget.content;
    final heroChild = OpenContainer(
      closedElevation: 0,
      openElevation: 0,
      closedColor: Colors.transparent,
      openColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 420),
      transitionType: ContainerTransitionType.fadeThrough,
      closedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      tappable: false,
      openBuilder: (context, _) =>
          _IllustrationFullscreenView(content: widget.content),
      closedBuilder: (context, openContainer) {
        return GestureDetector(
          onTap: openContainer,
          onDoubleTap: _handleDoubleTapFavorite,
          onLongPress: () => _handleLongPressHero(context),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: AspectRatio(
              aspectRatio: aspectRatio > 0 ? aspectRatio : 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ProgressiveIllustrationImage(
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
                            Colors.black.withOpacity(0.45),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: FadeTransition(
                        opacity: _burstOpacity,
                        child: ScaleTransition(
                          scale: _burstScale,
                          child: const Icon(
                            Icons.favorite,
                            color: Colors.white,
                            size: 96,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_isSavingImage)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              '保存中…',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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

  Widget _buildPrimaryActions(BuildContext context) {
    final baseCount = widget.content.favoriteCount;
    final displayCount = baseCount + (widget.isFavorite ? 1 : 0);
    final favoriteLabel = '${widget.isFavorite ? '已收藏' : '收藏'}（$displayCount）';
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            ),
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Icon(
                widget.isFavorite ? Icons.favorite : Icons.favorite_border,
                key: ValueKey(widget.isFavorite),
              ),
            ),
            label: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Text(favoriteLabel, key: ValueKey(favoriteLabel)),
            ),
            onPressed: () {
              widget.onToggleFavorite();
              _favoriteBurstController.forward(from: 0);
            },
          ),
        ),
        if (widget.primaryLink != null) ...[
          const SizedBox(width: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: const Text('查看原站'),
            onPressed: () => widget.onOpenSource(widget.primaryLink!),
          ),
        ],
      ],
    );
  }

  Widget _buildMetaCard(BuildContext context) {
    final content = widget.content;
    final published = _formatDateTime(content.publishedAt);
    final updated = content.updatedAt != null
        ? _formatDateTime(content.updatedAt)
        : null;
    final rating = content.rating.isNotEmpty ? content.rating : '未评级';
    final author = content.authorName?.isNotEmpty == true
        ? content.authorName!
        : '匿名作者';

    return DetailSectionCard(
      title: '作品信息',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DetailInfoRow(icon: Icons.person_outline, label: '作者', value: author),
          const SizedBox(height: 12),
          DetailInfoRow(icon: Icons.schedule, label: '发布时间', value: published),
          if (updated != null) ...[
            const SizedBox(height: 8),
            DetailInfoRow(
              icon: Icons.update,
              label: '最近更新',
              value: updated,
              subtle: true,
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoBadge(icon: Icons.shield, label: '评级 $rating'),
              _InfoBadge(
                icon: Icons.favorite,
                label: '收藏 ${content.favoriteCount}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, bool hasSummary) {
    final theme = Theme.of(context);
    return DetailSectionCard(
      title: '简介',
      child: hasSummary
          ? SelectableText(
              widget.content.summary,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
            )
          : SummaryPlaceholder(
              onAction: widget.primaryLink == null
                  ? null
                  : () => widget.onOpenSource(widget.primaryLink!),
              actionLabel: widget.primaryLink == null ? null : '前往原站填写',
            ),
    );
  }

  Widget _buildTagsCard() {
    return DetailSectionCard(
      title: '标签',
      child: CategorizedTagList(tags: widget.content.tags),
    );
  }

  Widget _buildSourceCard(BuildContext context) {
    final theme = Theme.of(context);
    return DetailSectionCard(
      title: '来源链接',
      child: Column(
        children: [
          for (var i = 0; i < widget.content.sourceLinks.length; i++) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                widget.content.sourceLinks[i].host,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                widget.content.sourceLinks[i].toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => widget.onOpenSource(widget.content.sourceLinks[i]),
            ),
            if (i < widget.content.sourceLinks.length - 1)
              const Divider(height: 12),
          ],
        ],
      ),
    );
  }

  void _handleDoubleTapFavorite() {
    widget.onToggleFavorite();
    _favoriteBurstController.forward(from: 0);
  }

  Future<void> _handleLongPressHero(BuildContext context) async {
    final action = await showModalBottomSheet<_HeroAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('保存图片到相册'),
                onTap: () => Navigator.of(sheetContext).pop(_HeroAction.save),
              ),
              if (widget.primaryLink != null)
                ListTile(
                  leading: const Icon(Icons.link_outlined),
                  title: const Text('复制原站链接'),
                  onTap: () =>
                      Navigator.of(sheetContext).pop(_HeroAction.copyLink),
                ),
            ],
          ),
        );
      },
    );

    if (!context.mounted || action == null) {
      return;
    }
    if (action == _HeroAction.save) {
      await _saveIllustration(context);
    } else if (action == _HeroAction.copyLink && widget.primaryLink != null) {
      await Clipboard.setData(
        ClipboardData(text: widget.primaryLink.toString()),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(const SnackBar(content: Text('已复制来源链接')));
    }
  }

  Future<void> _saveIllustration(BuildContext context) async {
    if (_isSavingImage) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    final imageUrl =
        widget.content.originalUrl ??
        widget.content.sampleUrl ??
        widget.content.previewUrl;
    if (imageUrl == null) {
      messenger?.showSnackBar(const SnackBar(content: Text('暂无可保存的图片')));
      return;
    }
    setState(() => _isSavingImage = true);
    try {
      final headers = pixivImageHeaders(content: widget.content, url: imageUrl);
      final cacheManager =
          pixivImageCacheManagerForUrl(imageUrl) ?? DefaultCacheManager();
      final file = await cacheManager.getSingleFile(
        imageUrl.toString(),
        headers: headers ?? const <String, String>{},
      );
      final bytes = await file.readAsBytes();
      final result = await ImageGallerySaver.saveImage(
        Uint8List.fromList(bytes),
        quality: 100,
        name: 'faio_${widget.content.id.replaceAll(':', '_')}',
      );
      final success = _isSaveSuccessful(result);
      messenger?.showSnackBar(
        SnackBar(content: Text(success ? '已保存到相册' : '保存失败，请稍后重试')),
      );
    } catch (error) {
      messenger?.showSnackBar(SnackBar(content: Text('保存失败：$error')));
    } finally {
      if (mounted) {
        setState(() => _isSavingImage = false);
      }
    }
  }

  bool _isSaveSuccessful(dynamic result) {
    if (result is bool) {
      return result;
    }
    if (result is Map) {
      final success = result['isSuccess'];
      if (success is bool) {
        return success;
      }
    }
    return false;
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

enum _HeroAction { save, copyLink }

class _IllustrationFullscreenView extends StatelessWidget {
  const _IllustrationFullscreenView({required this.content});

  final FaioContent content;

  @override
  Widget build(BuildContext context) {
    final preview =
        content.previewUrl ?? content.sampleUrl ?? content.originalUrl;
    final highRes =
        content.originalUrl ?? content.sampleUrl ?? content.previewUrl;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: ProgressiveIllustrationImage(
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
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
