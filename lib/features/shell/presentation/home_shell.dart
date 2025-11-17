import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: hideNavBar
          ? null
          : NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _onDestinationSelected,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.view_agenda_outlined),
                  selectedIcon: Icon(Icons.view_agenda),
                  label: '信息流',
                ),
                NavigationDestination(
                  icon: Icon(Icons.search_outlined),
                  selectedIcon: Icon(Icons.search),
                  label: '搜索',
                ),
                NavigationDestination(
                  icon: Icon(Icons.collections_bookmark_outlined),
                  selectedIcon: Icon(Icons.collections_bookmark),
                  label: '库',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: '设置',
                ),
              ],
            ),
    );
  }
}
