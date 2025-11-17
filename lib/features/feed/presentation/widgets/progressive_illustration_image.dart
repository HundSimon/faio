import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

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
  });

  final FaioContent content;
  final Uri? lowRes;
  final Uri? highRes;
  final BoxFit fit;

  @override
  State<ProgressiveIllustrationImage> createState() =>
      _ProgressiveIllustrationImageState();
}

class _ProgressiveIllustrationImageState
    extends State<ProgressiveIllustrationImage> {
  bool _highResLoaded = false;

  @override
  void didUpdateWidget(covariant ProgressiveIllustrationImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highRes?.toString() != oldWidget.highRes?.toString()) {
      _highResLoaded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final layers = <Widget>[
      Positioned.fill(
        child: widget.lowRes != null
            ? Image(
                image: CachedNetworkImageProvider(
                  widget.lowRes.toString(),
                  headers: pixivImageHeaders(url: widget.lowRes),
                  cacheManager: pixivImageCacheManagerForUrl(widget.lowRes),
                ),
                fit: widget.fit,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              )
            : const SizedBox.shrink(),
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
                headers: pixivImageHeaders(url: widget.highRes),
                cacheManager: pixivImageCacheManagerForUrl(widget.highRes),
              ),
              fit: widget.fit,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null && !_highResLoaded) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    setState(() => _highResLoaded = true);
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

    return Stack(fit: StackFit.expand, children: layers);
  }
}
