double effectiveContentExtent({
  required double viewport,
  required double maxScrollExtent,
  double? cachedContentExtent,
}) {
  final fallback = (maxScrollExtent + viewport).clamp(viewport, double.infinity);
  final cached = cachedContentExtent;
  if (cached == null || !cached.isFinite) {
    return fallback;
  }
  return cached < viewport ? viewport : cached;
}

double scrollableExtent({
  required double viewport,
  required double maxScrollExtent,
  double? cachedContentExtent,
}) {
  final contentExtent = effectiveContentExtent(
    viewport: viewport,
    maxScrollExtent: maxScrollExtent,
    cachedContentExtent: cachedContentExtent,
  );
  return (contentExtent - viewport).clamp(0.0, double.infinity);
}

double resolveScrollRatio({
  required double pixels,
  required double viewport,
  required double maxScrollExtent,
  double? cachedContentExtent,
}) {
  final scrollable = scrollableExtent(
    viewport: viewport,
    maxScrollExtent: maxScrollExtent,
    cachedContentExtent: cachedContentExtent,
  );
  if (scrollable <= 0) {
    return pixels <= 0 ? 0.0 : 1.0;
  }
  return (pixels / scrollable).clamp(0.0, 1.0);
}
