import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'package:faio/data/pixiv/pixiv_image_cache.dart';
import 'package:faio/domain/models/content_item.dart';
import 'package:faio/domain/utils/pixiv_image_utils.dart';

class ProgressiveIllustrationImage extends StatefulWidget {
  const ProgressiveIllustrationImage({
    super.key,
    required this.content,
    this.lowRes,
    this.highRes,
    this.fit = BoxFit.cover,
    this.onFirstFrameShown,
  });

  final FaioContent content;
  final Uri? lowRes;
  final Uri? highRes;
  final BoxFit fit;
  final VoidCallback? onFirstFrameShown;

  @override
  State<ProgressiveIllustrationImage> createState() =>
      _ProgressiveIllustrationImageState();
}

class _ProgressiveIllustrationImageState
    extends State<ProgressiveIllustrationImage> {
  static const _fadeDuration = Duration(milliseconds: 240);

  bool _lowResVisible = false;
  bool _highResLoaded = false;
  bool _didNotifyFirstFrame = false;

  @override
  void didUpdateWidget(covariant ProgressiveIllustrationImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lowRes?.toString() != oldWidget.lowRes?.toString()) {
      _lowResVisible = false;
    }
    if (widget.highRes?.toString() != oldWidget.highRes?.toString()) {
      _highResLoaded = false;
    }
    if (widget.lowRes != oldWidget.lowRes ||
        widget.highRes != oldWidget.highRes) {
      _didNotifyFirstFrame = false;
    }
  }

  void _notifyFirstFrameIfNeeded() {
    if (_didNotifyFirstFrame) return;
    _didNotifyFirstFrame = true;
    widget.onFirstFrameShown?.call();
  }

  void _markLowResVisible() {
    if (_lowResVisible || !mounted) return;
    setState(() => _lowResVisible = true);
    _notifyFirstFrameIfNeeded();
  }

  void _markHighResLoaded() {
    if (_highResLoaded || !mounted) return;
    setState(() => _highResLoaded = true);
    _notifyFirstFrameIfNeeded();
  }

  Widget _buildFadingImage({
    required Uri url,
    required BaseCacheManager? cacheManager,
    required Map<String, String>? headers,
    required BoxFit fit,
    required bool isHighRes,
  }) {
    return Image(
      image: CachedNetworkImageProvider(
        url.toString(),
        headers: headers,
        cacheManager: cacheManager,
      ),
      fit: fit,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        final loadedNow = wasSynchronouslyLoaded || frame != null;
        if (loadedNow) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (isHighRes) {
              _markHighResLoaded();
            } else {
              _markLowResVisible();
            }
          });
        }
        final isVisible = isHighRes ? _highResLoaded : _lowResVisible;
        return AnimatedOpacity(
          opacity: isVisible ? 1 : 0,
          duration: _fadeDuration,
          curve: Curves.easeInOut,
          child: child,
        );
      },
      loadingBuilder: (_, child, __) => child,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final layers = <Widget>[
      Positioned.fill(
        child: widget.lowRes != null
            ? _buildFadingImage(
                url: widget.lowRes!,
                cacheManager: pixivImageCacheManagerForUrl(widget.lowRes),
                headers: pixivImageHeaders(url: widget.lowRes),
                fit: widget.fit,
                isHighRes: false,
              )
            : const SizedBox.shrink(),
      ),
    ];

    if (widget.highRes != null) {
      layers.add(
        Positioned.fill(
          child: _buildFadingImage(
            url: widget.highRes!,
            cacheManager: pixivImageCacheManagerForUrl(widget.highRes),
            headers: pixivImageHeaders(url: widget.highRes),
            fit: widget.fit,
            isHighRes: true,
          ),
        ),
      );
    }

    return Stack(fit: StackFit.expand, children: layers);
  }
}
