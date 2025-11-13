import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

const _pixivFallbackHosts = ['i.pixiv.re', 'i.pixiv.nl', 'i.pixiv.cat'];

Map<String, String>? imageHeadersForUrl(Uri? url) {
  final host = url?.host.toLowerCase();
  if (host != null && host.endsWith('pximg.net')) {
    return const {
      'Referer': 'https://www.pixiv.net/',
      'User-Agent': 'PixivAndroidApp/5.0.234 (Android 11; Pixel 5)',
    };
  }
  return null;
}

List<Uri> imageUrlCandidates(Uri url) {
  final candidates = <Uri>[url];
  final host = url.host.toLowerCase();
  if (host == 'i.pximg.net') {
    for (final fallbackHost in _pixivFallbackHosts) {
      final candidate = url.replace(host: fallbackHost);
      final alreadyExists = candidates.any(
        (existing) => existing.toString() == candidate.toString(),
      );
      if (!alreadyExists) {
        candidates.add(candidate);
      }
    }
  }
  return candidates;
}

class ResilientNetworkImage extends StatefulWidget {
  const ResilientNetworkImage({
    required this.urls,
    this.headers,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.errorBuilder,
  }) : assert(urls.length > 0, 'urls must not be empty');

  final List<Uri> urls;
  final Map<String, String>? headers;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  @override
  State<ResilientNetworkImage> createState() => _ResilientNetworkImageState();
}

class _ResilientNetworkImageState extends State<ResilientNetworkImage> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final currentUrl = widget.urls[_index].toString();
    final imageProvider = CachedNetworkImageProvider(
      currentUrl,
      headers: widget.headers,
    );
    return Image(
      image: imageProvider,
      fit: widget.fit,
      alignment: widget.alignment,
      errorBuilder: (context, error, stackTrace) {
        if (_index < widget.urls.length - 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _index += 1);
          });
          return const SizedBox.expand();
        }
        final builder = widget.errorBuilder;
        if (builder != null) {
          return builder(context, error, stackTrace);
        }
        return const SizedBox.expand();
      },
    );
  }
}
