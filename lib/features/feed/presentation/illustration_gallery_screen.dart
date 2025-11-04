import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:faio/domain/models/content_item.dart';

import '../providers/feed_providers.dart';

Map<String, String>? _imageHeadersFor(FaioContent content) {
  final source = content.source.toLowerCase();
  if (source.startsWith('pixiv')) {
    return const {
      'Referer': 'https://app-api.pixiv.net/',
      'User-Agent': 'PixivAndroidApp/5.0.234 (Android 11; Pixel 5)',
    };
  }
  return null;
}

class IllustrationGalleryScreen extends ConsumerStatefulWidget {
  const IllustrationGalleryScreen({required this.initialIndex, super.key});

  final int initialIndex;

  @override
  ConsumerState<IllustrationGalleryScreen> createState() =>
      _IllustrationGalleryScreenState();
}

class _IllustrationGalleryScreenState
    extends ConsumerState<IllustrationGalleryScreen> {
  late final PageController _pageController;
  late int _currentIndex;
  final Set<int> _showOriginalIndexes = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(feedSelectionProvider.notifier).select(_currentIndex);
      ref
          .read(feedControllerProvider.notifier)
          .ensureIndexLoaded(_currentIndex);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    _currentIndex = index;
    final selection = ref.read(feedSelectionProvider.notifier);
    selection.select(index);
    _showOriginalIndexes.removeWhere((entry) => entry != index);

    final controller = ref.read(feedControllerProvider.notifier);
    controller.ensureIndexLoaded(index);
    controller.ensureIndexLoaded(index + 1);
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedControllerProvider);
    final items = feedState.items;
    final itemCount = feedState.hasMore ? items.length + 1 : items.length;

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context, rootNavigator: true).pop(_currentIndex);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: itemCount,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                if (index >= items.length) {
                  if (feedState.hasMore && !feedState.isLoadingMore) {
                    ref
                        .read(feedControllerProvider.notifier)
                        .ensureIndexLoaded(index);
                  }
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }

                final item = items[index];
                final useOriginal = _showOriginalIndexes.contains(index);
                final imageUrl = useOriginal
                    ? item.originalUrl ?? item.sampleUrl ?? item.previewUrl
                    : item.sampleUrl ?? item.previewUrl;
                if (imageUrl == null) {
                  return const Center(
                    child: Icon(Icons.broken_image, color: Colors.white),
                  );
                }
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: Image.network(
                      imageUrl.toString(),
                      fit: BoxFit.contain,
                      headers: _imageHeadersFor(item),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) {
                          return child;
                        }
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image, color: Colors.white),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(
                  context,
                  rootNavigator: true,
                ).pop(_currentIndex),
              ),
            ),
            if (_currentIndex < items.length)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 32,
                right: 24,
                child: _OriginalToggleButton(
                  item: items[_currentIndex],
                  isShowingOriginal: _showOriginalIndexes.contains(
                    _currentIndex,
                  ),
                  onShowOriginal: () {
                    final item = items[_currentIndex];
                    if (item.originalUrl == null) return;
                    setState(() {
                      _showOriginalIndexes.add(_currentIndex);
                    });
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OriginalToggleButton extends StatelessWidget {
  const _OriginalToggleButton({
    required this.item,
    required this.isShowingOriginal,
    required this.onShowOriginal,
  });

  final FaioContent item;
  final bool isShowingOriginal;
  final VoidCallback onShowOriginal;

  @override
  Widget build(BuildContext context) {
    if (item.originalUrl == null || isShowingOriginal) {
      return const SizedBox.shrink();
    }

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white70,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      onPressed: onShowOriginal,
      child: const Text('显示原图'),
    );
  }
}
