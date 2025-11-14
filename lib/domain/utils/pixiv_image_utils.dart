import 'package:faio/domain/models/content_item.dart';

const Map<String, String> _pixivWebImageHeaders = {
  'Referer': 'https://www.pixiv.net/',
  'User-Agent': 'PixivAndroidApp/5.0.234 (Android 11; Pixel 5)',
};

const Map<String, String> _pixivAppImageHeaders = {
  'Referer': 'https://app-api.pixiv.net/',
  'User-Agent': 'PixivAndroidApp/5.0.234 (Android 11; Pixel 5)',
};

/// Builds the appropriate HTTP headers needed for Pixiv images.
///
/// Accepts either a [FaioContent] instance, a [source], or a direct [url].
/// When a Pixiv CDN (`*.pximg.net`) URL is detected, we send the regular
/// Pixiv web Referer header. Otherwise, sources that start with `pixiv` will
/// fall back to the Pixiv app Referer header. Non-Pixiv URLs return `null`.
Map<String, String>? pixivImageHeaders({
  FaioContent? content,
  Uri? url,
  String? source,
}) {
  final resolvedUrl =
      url ?? content?.previewUrl ?? content?.sampleUrl ?? content?.originalUrl;
  final resolvedSource = source ?? content?.source;
  final host = resolvedUrl?.host.toLowerCase();
  if (host != null && host.endsWith('pximg.net')) {
    return _pixivWebImageHeaders;
  }
  final normalizedSource = resolvedSource?.toLowerCase();
  if (normalizedSource != null && normalizedSource.startsWith('pixiv')) {
    return _pixivAppImageHeaders;
  }
  return null;
}

/// Returns the list of candidate URLs for a Pixiv image.
///
/// We currently only use the provided URL without rewriting to mirror hosts.
List<Uri> pixivImageUrlCandidates(Uri url) => [url];
