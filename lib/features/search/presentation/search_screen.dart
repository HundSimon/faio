import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/preferences/content_safety_settings.dart';
import '../../../domain/models/content_item.dart';
import '../../../domain/utils/content_id.dart';
import '../../common/utils/content_gate.dart';
import '../../common/utils/content_warning.dart';
import '../../feed/presentation/illustration_detail_screen.dart'
    show IllustrationDetailRouteArgs;
import '../../feed/presentation/illustration_hero.dart';
import '../../feed/presentation/widgets/progressive_illustration_image.dart';
import '../../feed/providers/feed_providers.dart' show IllustrationSource;
import '../../novel/presentation/novel_hero.dart';
import '../../common/widgets/blurred_gate_overlay.dart';
import '../providers/search_providers.dart';

/// Early prototype of unified search UI.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submitSearch() {
    final query = _controller.text.trim();
    ref.read(searchQueryProvider.notifier).state = query;
  }

  Future<void> _handleResultTap(FaioContent item) async {
    final warning = evaluateContentWarning(
      rating: item.rating,
      tags: item.tags,
    );
    final safetySettings = ref.read(contentSafetySettingsProvider);
    final gate = evaluateContentGate(warning, safetySettings);
    final allowed = await ensureContentAllowed(
      context: context,
      ref: ref,
      gate: gate,
    );
    if (!allowed || !mounted) {
      return;
    }

    if (item.type == ContentType.novel) {
      final novelId = parseContentNumericId(item);
      if (novelId == null) {
        _showSnackBar('无法解析小说 ID');
        return;
      }
      if (!mounted) return;
      context.push('/feed/novel/$novelId', extra: item);
      return;
    }

    if (item.type == ContentType.illustration ||
        item.type == ContentType.comic) {
      final source = _mapIllustrationSource(item.source);
      if (source != null) {
        final args = IllustrationDetailRouteArgs(
          source: source,
          initialIndex: 0,
          initialContent: item,
          skipInitialWarningPrompt: true,
        );
        if (!mounted) return;
        context.push('/feed/detail', extra: args);
        return;
      }
    }

    final uri = _resolveDetailUri(item);
    if (uri == null) {
      _showSnackBar('未找到可打开的原站链接');
      return;
    }
    final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!success && mounted) {
      final host = uri.host.isNotEmpty ? uri.host : uri.toString();
      _showSnackBar('无法打开链接：$host');
    }
  }

  Uri? _resolveDetailUri(FaioContent item) {
    if (item.sourceLinks.isNotEmpty) {
      return item.sourceLinks.first;
    }
    return item.originalUrl ??
        item.sampleUrl ??
        item.previewUrl ??
        _fallbackSourceUri(item);
  }

  Uri? _fallbackSourceUri(FaioContent item) {
    final id = parseContentNumericId(item);
    if (id == null) {
      return null;
    }
    switch (item.source.toLowerCase()) {
      case 'e621':
        return Uri.parse('https://e621.net/posts/$id');
      case 'pixiv':
        return item.type == ContentType.novel
            ? Uri.parse('https://www.pixiv.net/novel/show.php?id=$id')
            : Uri.parse('https://www.pixiv.net/artworks/$id');
      case 'furrynovel':
        return Uri.parse('https://furrynovel.ink/pixiv/novel/$id');
      default:
        return null;
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(searchResultsProvider);
    final submittedQuery = ref.watch(searchQueryProvider).trim();
    final safetySettings = ref.watch(contentSafetySettingsProvider);

    ref.listen(searchResultsProvider, (previous, next) {
      next.whenOrNull(
        error: (error, stackTrace) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('搜索失败：$error')));
        },
      );
    });

    return Scaffold(
      appBar: AppBar(title: const Text('搜索')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: '搜索关键字、作者或标签',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _submitSearch(),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: resultsAsync.when(
                data: (items) {
                  if (submittedQuery.isEmpty) {
                    return const Center(child: Text('输入关键词并点击搜索以跨站点查找内容'));
                  }
                  final filtered = items
                      .map(
                        (item) => _SearchResultEntry(
                          item: item,
                          gate: evaluateContentGate(
                            evaluateContentWarning(
                              rating: item.rating,
                              tags: item.tags,
                            ),
                            safetySettings,
                          ),
                        ),
                      )
                      .where((entry) => !entry.gate.isBlocked)
                      .toList();

                  if (filtered.isEmpty) {
                    return const Center(child: Text('没有匹配结果，试试其他关键词或标签'));
                  }

                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final entry = filtered[index];
                      return _SearchResultTile(
                        item: entry.item,
                        gate: entry.gate,
                        onTap: () => _handleResultTap(entry.item),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) =>
                    Center(child: Text('搜索出现问题：$error')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.item, required this.gate, this.onTap});

  final FaioContent item;
  final ContentGateState gate;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = item.summary.trim().isEmpty ? null : item.summary.trim();
    final author = item.authorName?.trim();
    final metadataStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final isBlocked = gate.isBlocked;
    final blurLabel = gate.requiresPrompt
        ? gate.warning?.label ?? 'R-18'
        : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: isBlocked ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CoverPreview(
                item: item,
                blurLabel: blurLabel,
                isBlocked: isBlocked,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.source} · ${_typeLabel(item.type)} · ${item.rating}',
                      style: metadataStyle,
                    ),
                    if (author != null && author.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(author, style: theme.textTheme.bodySmall),
                      ),
                    if (summary != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: metadataStyle,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _typeLabel(ContentType type) {
    return switch (type) {
      ContentType.novel => '小说',
      ContentType.comic => '漫画',
      ContentType.audio => '音频',
      _ => '插画',
    };
  }
}

class _SearchResultEntry {
  const _SearchResultEntry({required this.item, required this.gate});

  final FaioContent item;
  final ContentGateState gate;
}

class _CoverPreview extends StatelessWidget {
  const _CoverPreview({
    required this.item,
    this.blurLabel,
    this.isBlocked = false,
  });

  final FaioContent item;
  final String? blurLabel;
  final bool isBlocked;

  @override
  Widget build(BuildContext context) {
    final preview = item.previewUrl ?? item.sampleUrl ?? item.originalUrl;
    final highRes = item.sampleUrl ?? item.originalUrl ?? item.previewUrl;
    final aspectRatio = switch (item.type) {
      ContentType.novel => 0.75,
      _ => (item.previewAspectRatio ?? 1).clamp(0.5, 1.6),
    };
    final borderRadius = BorderRadius.circular(16);
    Widget baseChild;
    if (preview == null && highRes == null) {
      baseChild = Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Icon(
          Icons.photo_size_select_actual_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    } else {
      baseChild = ProgressiveIllustrationImage(
        content: item,
        lowRes: preview,
        highRes: highRes,
        fit: BoxFit.cover,
      );
    }

    Widget framed = ClipRRect(borderRadius: borderRadius, child: baseChild);

    if (isBlocked) {
      framed = ClipRRect(
        borderRadius: borderRadius,
        child: Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: Icon(
            Icons.lock_outline,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    } else if (blurLabel != null) {
      framed = BlurredGateOverlay(
        label: blurLabel!,
        borderRadius: borderRadius,
        child: framed,
      );
    }

    framed = AspectRatio(aspectRatio: aspectRatio.toDouble(), child: framed);

    final heroTag = item.type == ContentType.novel
        ? novelHeroTag(item.id)
        : illustrationHeroTag(item.id);
    final rectTween = item.type == ContentType.novel
        ? novelHeroRectTween
        : illustrationHeroRectTween;

    return SizedBox(
      width: 110,
      child: Hero(
        tag: heroTag,
        transitionOnUserGestures: true,
        createRectTween: rectTween,
        child: framed,
      ),
    );
  }
}
