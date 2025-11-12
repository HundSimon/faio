import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:faio/domain/models/novel_detail.dart';
import 'package:faio/domain/models/novel_reader.dart';

import '../providers/novel_providers.dart';

class NovelReaderScreen extends ConsumerStatefulWidget {
  const NovelReaderScreen({required this.novelId, super.key});

  final int novelId;

  @override
  ConsumerState<NovelReaderScreen> createState() => _NovelReaderScreenState();
}

class _NovelReaderScreenState extends ConsumerState<NovelReaderScreen> {
  late final ScrollController _scrollController;
  Timer? _saveDebounce;
  bool _appliedInitialProgress = false;
  double? _pendingProgressRatio;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _scrollController.removeListener(_handleScroll);
    _persistProgress();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(seconds: 1), _persistProgress);
  }

  Future<void> _persistProgress() async {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    final max = position.maxScrollExtent;
    if (max <= 0) {
      return;
    }
    final ratio = (position.pixels / max).clamp(0.0, 1.0);
    final storage = ref.read(novelReadingStorageProvider);
    final progress = NovelReadingProgress(
      novelId: widget.novelId,
      relativeOffset: ratio,
      updatedAt: DateTime.now(),
    );
    await storage.saveProgress(progress);
    ref.invalidate(novelReadingProgressProvider(widget.novelId));
  }

  void _maybeRestoreProgress(NovelReadingProgress? progress) {
    if (_appliedInitialProgress) {
      return;
    }
    final ratio = progress?.relativeOffset ?? 0;
    if (ratio <= 0) {
      _appliedInitialProgress = true;
      return;
    }
    _pendingProgressRatio = ratio.clamp(0.0, 1.0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyPendingRestore());
  }

  void _applyPendingRestore() {
    if (!mounted || _appliedInitialProgress) {
      return;
    }
    final ratio = _pendingProgressRatio;
    if (ratio == null) {
      _appliedInitialProgress = true;
      return;
    }
    if (!_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 200), _applyPendingRestore);
      return;
    }
    final max = _scrollController.position.maxScrollExtent;
    if (max <= 0) {
      Future.delayed(const Duration(milliseconds: 200), _applyPendingRestore);
      return;
    }
    _scrollController.jumpTo(max * ratio);
    _appliedInitialProgress = true;
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
            final currentProgress = progressAsync.valueOrNull;
            final palette = _ReaderThemePreset.resolve(settings.themeId);
            final background = palette.background;
            final textColor = palette.textColor;
            final paragraphs = _splitParagraphs(detail.body);

            return Scaffold(
              backgroundColor: background,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                foregroundColor: textColor,
                elevation: 0,
                title: Text(
                  detail.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                actions: [
                  IconButton(
                    tooltip: '阅读设置',
                    onPressed: () => _openSettingsSheet(context, settings),
                    icon: const Icon(Icons.text_fields),
                  ),
                ],
              ),
              body: SafeArea(
                child: Scrollbar(
                  controller: _scrollController,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          detail.title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: textColor,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        if (detail.authorName != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            detail.authorName!,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: palette.subtleText),
                          ),
                        ],
                        const SizedBox(height: 16),
                        ...paragraphs.map(
                          (paragraph) => Padding(
                            padding: EdgeInsets.only(
                              bottom: settings.paragraphSpacing,
                            ),
                            child: Text(
                              paragraph,
                              style: TextStyle(
                                fontSize: settings.fontSize,
                                height: settings.lineHeight,
                                fontFamily: _fontFamilyFor(settings.fontFamily),
                                color: textColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        _ReaderFooter(
                          palette: palette,
                          progress: currentProgress,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, stackTrace) =>
              Scaffold(body: Center(child: Text('加载阅读设置失败：$error'))),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(title: const Text('小说阅读器')),
        body: Center(child: Text('加载小说失败：$error')),
      ),
    );
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

class _ReaderFooter extends StatelessWidget {
  const _ReaderFooter({required this.palette, required this.progress});

  final _ReaderThemePreset palette;
  final NovelReadingProgress? progress;

  @override
  Widget build(BuildContext context) {
    final ratio = progress?.relativeOffset ?? 0;
    final percent = (ratio * 100).clamp(0, 100).toStringAsFixed(0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: ratio > 0 ? ratio : null,
          backgroundColor: palette.subtleText.withOpacity(0.2),
          color: palette.accent,
        ),
        const SizedBox(height: 8),
        Text(
          progress == null ? '开始阅读吧' : '阅读进度：$percent%',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: palette.subtleText),
        ),
      ],
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
    final panelColor = baseColor.withOpacity(_isAdjustingSlider ? 0.6 : 1.0);

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

List<String> _splitParagraphs(String text) {
  final normalized = text.replaceAll('\r\n', '\n');
  final paragraphs = normalized
      .split(RegExp(r'\n{2,}'))
      .map((block) => block.trim())
      .where((block) => block.isNotEmpty)
      .toList();
  if (paragraphs.isNotEmpty) {
    return paragraphs;
  }
  final fallback = normalized
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  if (fallback.isNotEmpty) {
    return fallback;
  }
  return [normalized.trim()];
}
