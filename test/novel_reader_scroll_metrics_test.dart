import 'package:faio/features/novel/presentation/novel_reader_scroll_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('novel_reader_scroll_metrics', () {
    test('effectiveContentExtent falls back to scroll metrics', () {
      final viewport = 600.0;
      final maxScrollExtent = 1400.0;

      final effective = effectiveContentExtent(
        viewport: viewport,
        maxScrollExtent: maxScrollExtent,
      );

      expect(effective, maxScrollExtent + viewport);
    });

    test('effectiveContentExtent uses cached value when available', () {
      final viewport = 600.0;
      final maxScrollExtent = 1400.0;
      final cachedContentExtent = 1600.0;

      final effective = effectiveContentExtent(
        viewport: viewport,
        maxScrollExtent: maxScrollExtent,
        cachedContentExtent: cachedContentExtent,
      );

      expect(effective, cachedContentExtent);
    });

    test('effectiveContentExtent clamps cached to viewport', () {
      final viewport = 600.0;
      final maxScrollExtent = 1400.0;

      final effective = effectiveContentExtent(
        viewport: viewport,
        maxScrollExtent: maxScrollExtent,
        cachedContentExtent: 200.0,
      );

      expect(effective, viewport);
    });

    test('resolveScrollRatio prefers cached extent over sliver estimates', () {
      final viewport = 600.0;
      final cachedContentExtent = 1600.0;

      final ratio = resolveScrollRatio(
        pixels: 900.0,
        viewport: viewport,
        maxScrollExtent: 2000.0,
        cachedContentExtent: cachedContentExtent,
      );

      expect(ratio, closeTo(0.9, 0.0001));
    });
  });
}
