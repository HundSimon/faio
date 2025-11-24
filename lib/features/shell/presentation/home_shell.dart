import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../feed/providers/feed_providers.dart';

// Routes where an immersive experience is desirable (hide the bottom nav).
final List<RegExp> _navHiddenRoutePatterns = [
  RegExp(r'^/feed/detail$'),
  RegExp(r'^/feed/novel/\d+$'),
  RegExp(r'^/feed/novel/\d+/reader$'),
];

bool _isNavHiddenRoute(String location) {
  if (location.isEmpty) {
    return false;
  }
  final normalized = location.contains('?')
      ? location.substring(0, location.indexOf('?'))
      : location;
  return _navHiddenRoutePatterns.any((pattern) => pattern.hasMatch(normalized));
}

/// Shell widget that renders the bottom navigation scaffold.
class HomeShell extends StatelessWidget {
  const HomeShell({
    super.key,
    required this.navigationShell,
    required this.currentState,
  });

  final StatefulNavigationShell navigationShell;
  final GoRouterState currentState;

  void _onDestinationSelected(int index) {
    if (index == navigationShell.currentIndex) {
      navigationShell.goBranch(index, initialLocation: true);
    } else {
      navigationShell.goBranch(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hideNavBar = _isNavHiddenRoute(currentState.uri.toString());
    final destinations = _navDestinations;
    return Scaffold(
      body: Stack(children: [navigationShell, const _FeedPreloader()]),
      bottomNavigationBar: hideNavBar
          ? null
          : Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: List.generate(destinations.length, (index) {
                    final data = destinations[index];
                    final selected = navigationShell.currentIndex == index;
                    return Expanded(
                      child: _BottomNavItem(
                        data: data,
                        selected: selected,
                        onTap: () => _onDestinationSelected(index),
                      ),
                    );
                  }),
                ),
              ),
            ),
    );
  }
}

class _FeedPreloader extends ConsumerStatefulWidget {
  const _FeedPreloader();

  @override
  ConsumerState<_FeedPreloader> createState() => _FeedPreloaderState();
}

class _FeedPreloaderState extends ConsumerState<_FeedPreloader> {
  ProviderSubscription<FeedState>? _illustrationSubscription;
  ProviderSubscription<FeedState>? _novelSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _illustrationSubscription ??= ref.listenManual<FeedState>(
        illustrationFeedControllerProvider(IllustrationSource.mixed),
        (_, __) {},
      );
      _novelSubscription ??= ref.listenManual<FeedState>(
        pixivNovelFeedControllerProvider,
        (_, __) {},
      );
    });
  }

  @override
  void dispose() {
    _illustrationSubscription?.close();
    _novelSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _NavDestinationData {
  const _NavDestinationData({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _navDestinations = <_NavDestinationData>[
  _NavDestinationData(
    label: '信息流',
    icon: Icons.view_agenda_outlined,
    selectedIcon: Icons.view_agenda,
  ),
  _NavDestinationData(
    label: '搜索',
    icon: Icons.search_outlined,
    selectedIcon: Icons.search,
  ),
  _NavDestinationData(
    label: '库',
    icon: Icons.collections_bookmark_outlined,
    selectedIcon: Icons.collections_bookmark,
  ),
  _NavDestinationData(
    label: '设置',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
  ),
];

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _NavDestinationData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? data.selectedIcon : data.icon, color: color),
            const SizedBox(height: 4),
            Text(
              data.label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 3,
              width: 24,
              decoration: BoxDecoration(
                color: selected ? color : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
