import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:faio/domain/models/novel_detail.dart';
import 'package:faio/domain/models/novel_reader.dart';
import 'package:faio/features/common/widgets/skeleton_theme.dart';

import '../providers/novel_providers.dart';
import 'novel_reader_scroll_metrics.dart';

class NovelReaderScreen extends ConsumerStatefulWidget {
  const NovelReaderScreen({required this.novelId, super.key});

  final int novelId;

  @override
  ConsumerState<NovelReaderScreen> createState() => _NovelReaderScreenState();
}

class _NovelReaderScreenState extends ConsumerState<NovelReaderScreen> {
  late final ScrollController _scrollController;
  Timer? _saveDebounce;
  Timer? _controlsAutoHideTimer;
  bool _appliedInitialProgress = false;
  double? _pendingProgressRatio;
  double? _pendingAbsoluteOffset;
  int _pendingRestoreAttempts = 0;
  double _currentScrollRatio = 0;
  double _scrollThumbExtentRatio = 1;
  bool _hasScrollableContent = false;
  List<_ReaderBlock>? _cachedBlocks;
  int? _cachedNovelId;
  String? _cachedBody;
  double? _cachedContentExtent;
  NovelReaderSettings? _cachedLayoutSettings;
  double? _cachedLayoutWidth;
  bool _controlsVisible = true;

  static const _restoreRetryDelay = Duration(milliseconds: 200);
  static const _restoreTolerance = 12.0;
  static const _restoreMaxAttempts = 12;
  static const _controlsAnimationDuration = Duration(milliseconds: 220);
  static const _controlsInitialAutoHideDelay = Duration(milliseconds: 800);
  static const _controlsAutoHideDelay = Duration(seconds: 3);
  static const _readerHorizontalPadding = 20.0;
  static const _readerVerticalPadding = 24.0;
  static const _edgeEpsilon = 0.5;
  static const _extentCalibrationTolerance = 1.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);
    _scheduleAutoHideControls(delay: _controlsInitialAutoHideDelay);
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _controlsAutoHideTimer?.cancel();
    _scrollController.removeListener(_handleScroll);
    _persistProgress();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    _updateScrollMetricsSnapshot();
    if (_controlsVisible) {
      _controlsAutoHideTimer?.cancel();
      setState(() {
        _controlsVisible = false;
      });
    }
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(seconds: 1), _persistProgress);
  }

  void _toggleControls() {
    setState(() {
      _controlsVisible = !_controlsVisible;
    });
    if (_controlsVisible) {
      _scheduleAutoHideControls();
    } else {
      _controlsAutoHideTimer?.cancel();
    }
  }

  void _scheduleAutoHideControls({Duration? delay}) {
    _controlsAutoHideTimer?.cancel();
    _controlsAutoHideTimer = Timer(delay ?? _controlsAutoHideDelay, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _controlsVisible = false;
      });
    });
  }

  Future<void> _persistProgress() async {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    final pixels = position.pixels;
    final viewport = position.viewportDimension;
    final max = position.maxScrollExtent;
    _calibrateContentExtent(position, viewport);
    var ratio = resolveScrollRatio(
      pixels: pixels,
      viewport: viewport,
      maxScrollExtent: max,
      cachedContentExtent: _cachedContentExtent,
    );
    if (pixels <= position.minScrollExtent + _edgeEpsilon) {
      ratio = 0.0;
    } else if (position.atEdge &&
        pixels >= position.maxScrollExtent - _edgeEpsilon) {
      ratio = 1.0;
    }
    final contentExtent = effectiveContentExtent(
      viewport: viewport,
      maxScrollExtent: max,
      cachedContentExtent: _cachedContentExtent,
    );
    final storage = ref.read(novelReadingStorageProvider);
    final progress = NovelReadingProgress(
      novelId: widget.novelId,
      relativeOffset: ratio,
      updatedAt: DateTime.now(),
      absoluteOffset: pixels,
      viewportExtent: viewport,
      contentExtent: contentExtent,
    );
    await storage.saveProgress(progress);
    ref.read(novelProgressEpochProvider.notifier).update((value) => value + 1);
    ref.invalidate(novelReadingProgressProvider(widget.novelId));
  }

  void _maybeRestoreProgress(NovelReadingProgress? progress) {
    if (_appliedInitialProgress) {
      return;
    }
    if (progress == null) {
      _appliedInitialProgress = true;
      return;
    }
    final ratio = progress.relativeOffset.clamp(0.0, 1.0);
    final absolute = progress.absoluteOffset;
    final savedContent = progress.contentExtent;
    if (_cachedContentExtent == null &&
        savedContent != null &&
        savedContent > 0) {
      _cachedContentExtent = savedContent;
    }
    if (ratio <= 0 && (absolute == null || absolute <= 0)) {
      _appliedInitialProgress = true;
      return;
    }
    _pendingProgressRatio = ratio > 0 ? ratio : null;
    _pendingAbsoluteOffset = absolute;
    if (_pendingProgressRatio != null) {
      _primeScrollIndicator(_pendingProgressRatio!);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyPendingRestore());
  }

  void _applyPendingRestore() {
    if (!mounted || _appliedInitialProgress) {
      return;
    }
    if (!_scrollController.hasClients) {
      _retryRestore();
      return;
    }
    final position = _scrollController.position;
    final max = position.maxScrollExtent;
    final ratio = _pendingProgressRatio;
    final absolute = _pendingAbsoluteOffset;
    if (max <= 0 && (absolute ?? 0) > 0) {
      _retryRestore();
      return;
    }
    if (absolute != null && max + _restoreTolerance < absolute) {
      if (_pendingRestoreAttempts >= _restoreMaxAttempts) {
        _pendingAbsoluteOffset = max;
      } else {
        _retryRestore();
        return;
      }
    }
    if (max <= 0 && (ratio == null || ratio <= 0)) {
      _finishInitialProgressRestore();
      return;
    }
    final target = absolute != null
        ? absolute.clamp(0.0, max)
        : (ratio ?? 0) * max;
    _scrollController.jumpTo(target.isFinite ? target : 0);
    _finishInitialProgressRestore();
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(novelDetailProvider(widget.novelId));
    final settingsAsync = ref.watch(novelReaderSettingsProvider);
    final progressAsync = ref.watch(
      novelReadingProgressProvider(widget.novelId),
    );

    return detailAsync.when(
      data: (detail) {
        return settingsAsync.when(
          data: (settings) {
            if (progressAsync.hasValue) {
              _maybeRestoreProgress(progressAsync.value);
            }
            final palette = _ReaderThemePreset.resolve(settings.themeId);
            final background = palette.background;
            final textColor = palette.textColor;
            final blocks = _blocksFor(detail);
            final contentCount = blocks.length + 1;

            return Scaffold(
              backgroundColor: background,
              body: Stack(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _toggleControls,
                    child: SafeArea(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final availableWidth = constraints.maxWidth.isFinite
                              ? constraints.maxWidth -
                                  (_readerHorizontalPadding * 2)
                              : constraints.maxWidth;
                          final contentWidth = availableWidth.isFinite
                              ? availableWidth.clamp(80.0, double.infinity)
                              : availableWidth;
                          _ensureLayoutMetrics(
                            context: context,
                            detail: detail,
                            settings: settings,
                            blocks: blocks,
                            maxWidth: contentWidth,
                          );
                          return Stack(
                            children: [
                              CustomScrollView(
                                controller: _scrollController,
                                slivers: [
                                  SliverPadding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: _readerHorizontalPadding,
                                      vertical: _readerVerticalPadding,
                                    ),
                                    sliver: SliverList(
                                      delegate: SliverChildBuilderDelegate((
                                        context,
                                        index,
                                      ) {
                                        if (index == 0) {
                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                detail.title,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleLarge
                                                    ?.copyWith(
                                                      color: textColor,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                              if (detail.authorName !=
                                                  null) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  detail.authorName!,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        color:
                                                            palette.subtleText,
                                                      ),
                                                ),
                                              ],
                                              const SizedBox(height: 16),
                                            ],
                                          );
                                        }
                                        final paragraphIndex = index - 1;
                                        final block = blocks[paragraphIndex];
                                        final previous = paragraphIndex > 0
                                            ? blocks[paragraphIndex - 1]
                                            : null;
                                        return Padding(
                                          padding: EdgeInsets.only(
                                            top: _blockTopSpacing(
                                              block,
                                              previous,
                                              settings,
                                            ),
                                            bottom: _blockBottomSpacing(
                                              block,
                                              settings,
                                            ),
                                          ),
                                          child: Text(
                                            block.text,
                                            style: _textStyleForBlock(
                                              block,
                                              settings,
                                              textColor,
                                            ),
                                          ),
                                        );
                                      }, childCount: contentCount),
                                    ),
                                  ),
                                ],
                              ),
                              Positioned.fill(
                                child: _ReaderScrollIndicator(
                                  palette: palette,
                                  progress: _currentScrollRatio,
                                  thumbExtentRatio: _scrollThumbExtentRatio,
                                  isScrollable: _hasScrollableContent,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _ReaderTopBar(
                      visible: _controlsVisible,
                      title: detail.title,
                      foregroundColor: textColor,
                      backgroundColor: background,
                      animationDuration: _controlsAnimationDuration,
                      onBackPressed: () => Navigator.of(context).maybePop(),
                      onSettingsPressed: () {
                        setState(() {
                          _controlsVisible = true;
                        });
                        _scheduleAutoHideControls();
                        _openSettingsSheet(context, settings);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const _NovelReaderSkeleton(),
          error: (error, stackTrace) =>
              Scaffold(body: Center(child: Text('加载阅读设置失败：$error'))),
        );
      },
      loading: () => const _NovelReaderSkeleton(),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(title: const Text('小说阅读器')),
        body: Center(child: Text('加载小说失败：$error')),
      ),
    );
  }

  List<_ReaderBlock> _blocksFor(NovelDetail detail) {
    final bodyChanged =
        _cachedNovelId != detail.novelId || _cachedBody != detail.body;
    if (_cachedBlocks == null || bodyChanged) {
      _cachedBlocks = _splitBlocks(detail.body);
      _cachedNovelId = detail.novelId;
      _cachedBody = detail.body;
      _invalidateLayoutMetrics();
    }
    return _cachedBlocks!;
  }

  void _ensureLayoutMetrics({
    required BuildContext context,
    required NovelDetail detail,
    required NovelReaderSettings settings,
    required List<_ReaderBlock> blocks,
    required double maxWidth,
  }) {
    if (maxWidth.isInfinite || maxWidth <= 0) {
      return;
    }
    final widthChanged =
        _cachedLayoutWidth == null ||
        (_cachedLayoutWidth! - maxWidth).abs() > 0.5;
    final settingsChanged =
        _cachedLayoutSettings == null || _cachedLayoutSettings != settings;
    final needsRecompute =
        _cachedContentExtent == null || widthChanged || settingsChanged;
    if (!needsRecompute) {
      return;
    }

    final theme = Theme.of(context);
    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final painter = TextPainter(
      textDirection: textDirection,
      textAlign: TextAlign.start,
      textScaler: textScaler,
    );
    double paragraphTotal = 0;
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      final previous = i > 0 ? blocks[i - 1] : null;
      painter
        ..text = TextSpan(
          text: block.text,
          style: _textStyleForBlock(block, settings),
        )
        ..layout(maxWidth: maxWidth);
      final blockHeight = painter.size.height;
      final topSpacing = _blockTopSpacing(block, previous, settings);
      final bottomSpacing = _blockBottomSpacing(block, settings);
      paragraphTotal += blockHeight + topSpacing + bottomSpacing;
    }

    double headerHeight = 0;
    final titleStyle =
        theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700) ??
        TextStyle(fontSize: settings.fontSize + 2, fontWeight: FontWeight.w700);
    painter
      ..text = TextSpan(text: detail.title, style: titleStyle)
      ..layout(maxWidth: maxWidth);
    headerHeight += painter.size.height;
    if (detail.authorName != null) {
      headerHeight += 4;
      final authorStyle =
          theme.textTheme.bodyMedium ??
          TextStyle(
            fontSize: settings.fontSize - 2,
            height: settings.lineHeight,
          );
      painter
        ..text = TextSpan(text: detail.authorName!, style: authorStyle)
        ..layout(maxWidth: maxWidth);
      headerHeight += painter.size.height;
    }
    headerHeight += 16;

    _cachedContentExtent =
        headerHeight + paragraphTotal + (_readerVerticalPadding * 2);
    _cachedLayoutSettings = settings;
    _cachedLayoutWidth = maxWidth;

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _updateScrollMetricsSnapshot(force: true),
    );
  }

  void _invalidateLayoutMetrics() {
    _cachedContentExtent = null;
    _cachedLayoutSettings = null;
    _cachedLayoutWidth = null;
  }

  void _retryRestore() {
    if (!mounted) {
      return;
    }
    _pendingRestoreAttempts += 1;
    Future.delayed(_restoreRetryDelay, _applyPendingRestore);
  }

  void _finishInitialProgressRestore() {
    _appliedInitialProgress = true;
    _pendingProgressRatio = null;
    _pendingAbsoluteOffset = null;
    _pendingRestoreAttempts = 0;
    _updateScrollMetricsSnapshot(force: true);
  }

  void _primeScrollIndicator(double ratio) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _currentScrollRatio = ratio;
      });
    });
  }

  void _updateScrollMetricsSnapshot({bool force = false}) {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    final max = position.maxScrollExtent;
    final viewport = position.viewportDimension;
    _calibrateContentExtent(position, viewport);
    var ratio = resolveScrollRatio(
      pixels: position.pixels,
      viewport: viewport,
      maxScrollExtent: max,
      cachedContentExtent: _cachedContentExtent,
    );
    final contentExtent = effectiveContentExtent(
      viewport: viewport,
      maxScrollExtent: max,
      cachedContentExtent: _cachedContentExtent,
    );
    if (position.pixels <= position.minScrollExtent + _edgeEpsilon) {
      ratio = 0.0;
    } else if (position.atEdge &&
        position.pixels >= position.maxScrollExtent - _edgeEpsilon) {
      ratio = 1.0;
    }
    final scrollableExtent = (contentExtent - viewport).clamp(
      0.0,
      double.infinity,
    );
    final thumbExtent = contentExtent <= 0
        ? 1.0
        : (viewport / contentExtent).clamp(0.05, 1.0);
    final hasScrollable = scrollableExtent > 1;
    final shouldUpdate =
        force ||
        !_nearEquals(_currentScrollRatio, ratio) ||
        !_nearEquals(_scrollThumbExtentRatio, thumbExtent) ||
        _hasScrollableContent != hasScrollable;
    if (!shouldUpdate || !mounted) {
      return;
    }
    setState(() {
      _currentScrollRatio = ratio;
      _scrollThumbExtentRatio = thumbExtent;
      _hasScrollableContent = hasScrollable;
    });
  }

  bool _nearEquals(double a, double b, [double epsilon = 0.001]) {
    return (a - b).abs() < epsilon;
  }

  void _calibrateContentExtent(ScrollPosition position, double viewport) {
    final pixels = position.pixels;
    final cached = _cachedContentExtent;

    final atBottom =
        position.atEdge && pixels >= position.maxScrollExtent - _edgeEpsilon;
    if (atBottom) {
      final contentFromPosition = position.maxScrollExtent + viewport;
      if (contentFromPosition.isFinite && contentFromPosition > 0) {
        _cachedContentExtent = contentFromPosition;
      }
      return;
    }

    final minRequired = pixels + viewport;
    if (cached == null ||
        minRequired > cached + _extentCalibrationTolerance ||
        cached < viewport) {
      _cachedContentExtent = minRequired < viewport ? viewport : minRequired;
    }
  }

  Future<void> _openSettingsSheet(
    BuildContext context,
    NovelReaderSettings settings,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SafeArea(
            top: false,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: _ReaderSettingsSheet(
                initial: settings,
                onChanged: (updated) {
                  ref
                      .read(novelReaderSettingsProvider.notifier)
                      .update(updated);
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ReaderSettingsSheet extends StatefulWidget {
  const _ReaderSettingsSheet({required this.initial, required this.onChanged});

  final NovelReaderSettings initial;
  final ValueChanged<NovelReaderSettings> onChanged;

  @override
  State<_ReaderSettingsSheet> createState() => _ReaderSettingsSheetState();
}

class _ReaderSettingsSheetState extends State<_ReaderSettingsSheet> {
  late NovelReaderSettings _settings;
  bool _isAdjustingSlider = false;

  @override
  void initState() {
    super.initState();
    _settings = widget.initial;
  }

  void _update(NovelReaderSettings next) {
    setState(() {
      _settings = next;
    });
    widget.onChanged(next);
  }

  void _setSliderInteraction(bool isActive) {
    if (_isAdjustingSlider == isActive) {
      return;
    }
    setState(() {
      _isAdjustingSlider = isActive;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor =
        theme.bottomSheetTheme.backgroundColor ?? theme.colorScheme.surface;
    final panelColor = baseColor.withValues(
      alpha: _isAdjustingSlider ? 0.6 : 1.0,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: panelColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '阅读设置',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            _SettingsSection(
              label: '字体',
              child: Wrap(
                spacing: 8,
                children: _ReaderFontOption.values.map((option) {
                  final isSelected = option.id == _settings.fontFamily;
                  return ChoiceChip(
                    label: Text(option.label),
                    selected: isSelected,
                    onSelected: (_) =>
                        _update(_settings.copyWith(fontFamily: option.id)),
                  );
                }).toList(),
              ),
            ),
            _SettingsSection(
              label: '文字大小 (${_settings.fontSize.toStringAsFixed(0)}sp)',
              child: Slider(
                value: _settings.fontSize,
                min: 14,
                max: 28,
                onChanged: (value) =>
                    _update(_settings.copyWith(fontSize: value)),
                onChangeStart: (_) => _setSliderInteraction(true),
                onChangeEnd: (_) => _setSliderInteraction(false),
              ),
            ),
            _SettingsSection(
              label: '行距 (${_settings.lineHeight.toStringAsFixed(1)})',
              child: Slider(
                value: _settings.lineHeight,
                min: 1.2,
                max: 2.2,
                onChanged: (value) =>
                    _update(_settings.copyWith(lineHeight: value)),
                onChangeStart: (_) => _setSliderInteraction(true),
                onChangeEnd: (_) => _setSliderInteraction(false),
              ),
            ),
            _SettingsSection(
              label:
                  '段落间距 (${_settings.paragraphSpacing.toStringAsFixed(0)}dp)',
              child: Slider(
                value: _settings.paragraphSpacing,
                min: 6,
                max: 28,
                onChanged: (value) =>
                    _update(_settings.copyWith(paragraphSpacing: value)),
                onChangeStart: (_) => _setSliderInteraction(true),
                onChangeEnd: (_) => _setSliderInteraction(false),
              ),
            ),
            _SettingsSection(
              label: '背景主题',
              child: Wrap(
                spacing: 8,
                children: _ReaderThemePreset.presets.map((preset) {
                  final isSelected = preset.id == _settings.themeId;
                  return ChoiceChip(
                    label: Text(preset.label),
                    selected: isSelected,
                    onSelected: (_) =>
                        _update(_settings.copyWith(themeId: preset.id)),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _update(const NovelReaderSettings()),
                child: const Text('恢复默认'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NovelReaderSkeleton extends StatelessWidget {
  const _NovelReaderSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget line({double height = 14, double? width, double radius = 6}) {
      return Skeleton.leaf(
        child: Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('小说阅读器')),
      body: Skeletonizer(
        effect: kFaioSkeletonEffect,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          children: [
            line(height: 30, width: 220, radius: 10),
            const SizedBox(height: 12),
            line(height: 16, width: 140, radius: 10),
            const SizedBox(height: 24),
            ...List.generate(
              10,
              (index) => Padding(
                padding: EdgeInsets.only(bottom: index == 9 ? 0 : 12),
                child: line(),
              ),
            ),
            const SizedBox(height: 28),
            line(height: 8, radius: 999),
            const SizedBox(height: 8),
            line(height: 12, width: 120),
          ],
        ),
      ),
    );
  }
}

class _ReaderTopBar extends StatelessWidget {
  const _ReaderTopBar({
    required this.visible,
    required this.title,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.animationDuration,
    required this.onBackPressed,
    required this.onSettingsPressed,
  });

  final bool visible;
  final String title;
  final Color foregroundColor;
  final Color backgroundColor;
  final Duration animationDuration;
  final VoidCallback onBackPressed;
  final VoidCallback onSettingsPressed;

  @override
  Widget build(BuildContext context) {
    final paddingTop = MediaQuery.paddingOf(context).top;
    final height = paddingTop + kToolbarHeight;

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: animationDuration,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, -1),
          duration: animationDuration,
          child: SizedBox(
            height: height,
            child: Material(
              color: backgroundColor.withValues(alpha: 0.92),
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                  height: kToolbarHeight,
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: '返回',
                        onPressed: onBackPressed,
                        icon: Icon(Icons.arrow_back, color: foregroundColor),
                      ),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: foregroundColor,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      IconButton(
                        tooltip: '阅读设置',
                        onPressed: onSettingsPressed,
                        icon: Icon(Icons.text_fields, color: foregroundColor),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _ReaderScrollIndicator extends StatelessWidget {
  const _ReaderScrollIndicator({
    required this.palette,
    required this.progress,
    required this.thumbExtentRatio,
    required this.isScrollable,
  });

  final _ReaderThemePreset palette;
  final double progress;
  final double thumbExtentRatio;
  final bool isScrollable;

  @override
  Widget build(BuildContext context) {
    if (!isScrollable) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trackHeight = constraints.maxHeight;
          if (!trackHeight.isFinite || trackHeight <= 0) {
            return const SizedBox.shrink();
          }
          final clampedThumb = thumbExtentRatio.clamp(0.05, 1.0);
          final thumbHeight = trackHeight * clampedThumb;
          final travel = (trackHeight - thumbHeight).clamp(
            0.0,
            double.infinity,
          );
          final offset = travel * progress.clamp(0.0, 1.0);
          return Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: SizedBox(
                width: 4,
                height: trackHeight,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: palette.subtleText.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    Positioned(
                      top: offset,
                      child: Container(
                        width: 4,
                        height: thumbHeight,
                        decoration: BoxDecoration(
                          color: palette.accent.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReaderThemePreset {
  const _ReaderThemePreset({
    required this.id,
    required this.label,
    required this.background,
    required this.textColor,
    required this.subtleText,
    required this.accent,
  });

  final String id;
  final String label;
  final Color background;
  final Color textColor;
  final Color subtleText;
  final Color accent;

  static const presets = [
    _ReaderThemePreset(
      id: 'light',
      label: '日间',
      background: Color(0xFFFDF8EF),
      textColor: Color(0xFF1C1B1F),
      subtleText: Color(0xFF4C4C4F),
      accent: Color(0xFF4A6FF3),
    ),
    _ReaderThemePreset(
      id: 'sepia',
      label: '米黄',
      background: Color(0xFFF4ECD8),
      textColor: Color(0xFF2C1F11),
      subtleText: Color(0xFF6B5B49),
      accent: Color(0xFFB5742D),
    ),
    _ReaderThemePreset(
      id: 'dusk',
      label: '暮色',
      background: Color(0xFF1D1F2A),
      textColor: Color(0xFFE4E7F2),
      subtleText: Color(0xFF9EA3B5),
      accent: Color(0xFF5B8DEF),
    ),
    _ReaderThemePreset(
      id: 'dark',
      label: '夜间',
      background: Color(0xFF0F0F10),
      textColor: Color(0xFFE0E0E0),
      subtleText: Color(0xFF8E8E93),
      accent: Color(0xFFFFC857),
    ),
  ];

  static _ReaderThemePreset resolve(String id) {
    return presets.firstWhere(
      (preset) => preset.id == id,
      orElse: () => presets.first,
    );
  }
}

class _ReaderFontOption {
  const _ReaderFontOption({required this.id, required this.label});

  final String id;
  final String label;

  static const values = [
    _ReaderFontOption(id: 'sans', label: '无衬线'),
    _ReaderFontOption(id: 'serif', label: '衬线'),
    _ReaderFontOption(id: 'mono', label: '等宽'),
  ];
}

String? _fontFamilyFor(String id) {
  switch (id) {
    case 'serif':
      return 'serif';
    case 'mono':
      return 'monospace';
    default:
      return null;
  }
}

enum _ReaderBlockType { paragraph, chapter }

class _ReaderBlock {
  const _ReaderBlock._(this.text, this.type);

  const _ReaderBlock.paragraph(String text)
    : this._(text, _ReaderBlockType.paragraph);

  const _ReaderBlock.chapter(String text)
    : this._(text, _ReaderBlockType.chapter);

  final String text;
  final _ReaderBlockType type;

  bool get isChapter => type == _ReaderBlockType.chapter;
}

TextStyle _textStyleForBlock(
  _ReaderBlock block,
  NovelReaderSettings settings, [
  Color? textColor,
]) {
  return block.isChapter
      ? _chapterTextStyle(settings, textColor)
      : _paragraphTextStyle(settings, textColor);
}

TextStyle _paragraphTextStyle(
  NovelReaderSettings settings, [
  Color? textColor,
]) {
  return TextStyle(
    fontSize: settings.fontSize,
    height: settings.lineHeight,
    fontFamily: _fontFamilyFor(settings.fontFamily),
    color: textColor,
  );
}

TextStyle _chapterTextStyle(NovelReaderSettings settings, [Color? textColor]) {
  final chapterLineHeight = (settings.lineHeight * 0.95)
      .clamp(1.2, 2.5)
      .toDouble();
  return TextStyle(
    fontSize: settings.fontSize + 2,
    height: chapterLineHeight,
    fontFamily: _fontFamilyFor(settings.fontFamily),
    fontWeight: FontWeight.w700,
    color: textColor,
  );
}

double _blockTopSpacing(
  _ReaderBlock block,
  _ReaderBlock? previous,
  NovelReaderSettings settings,
) {
  if (previous != null && block.isChapter) {
    return settings.paragraphSpacing * 0.5;
  }
  return 0;
}

double _blockBottomSpacing(_ReaderBlock block, NovelReaderSettings settings) {
  if (block.isChapter) {
    return settings.paragraphSpacing * 1.2;
  }
  return settings.paragraphSpacing;
}

List<_ReaderBlock> _splitBlocks(String text) {
  final normalized = text.replaceAll('\r\n', '\n');
  final blocks = <_ReaderBlock>[];
  final chapterRegex = RegExp(r'\[chapter:([^\]\r\n]+)\]');
  var lastIndex = 0;

  void addParagraphs(String segment) {
    final trimmed = segment.trim();
    if (trimmed.isEmpty) {
      return;
    }
    blocks.addAll(_paragraphBlocksFrom(segment));
  }

  for (final match in chapterRegex.allMatches(normalized)) {
    if (match.start > lastIndex) {
      addParagraphs(normalized.substring(lastIndex, match.start));
    }
    final title = match.group(1)?.trim();
    if (title != null && title.isNotEmpty) {
      blocks.add(_ReaderBlock.chapter(title));
    }
    lastIndex = match.end;
  }

  if (lastIndex < normalized.length) {
    addParagraphs(normalized.substring(lastIndex));
  }

  if (blocks.isEmpty) {
    addParagraphs(normalized);
  }

  return blocks;
}

List<_ReaderBlock> _paragraphBlocksFrom(String text) {
  final normalized = text.replaceAll('\r\n', '\n');
  final paragraphs = normalized
      .split(RegExp(r'\n{2,}'))
      .map((block) => block.trim())
      .where((block) => block.isNotEmpty)
      .toList();
  if (paragraphs.isNotEmpty) {
    return paragraphs.map(_ReaderBlock.paragraph).toList();
  }
  final fallback = normalized
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  if (fallback.isNotEmpty) {
    return fallback.map(_ReaderBlock.paragraph).toList();
  }
  final trimmed = normalized.trim();
  return trimmed.isEmpty ? const [] : [_ReaderBlock.paragraph(trimmed)];
}
