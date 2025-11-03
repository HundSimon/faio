import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/feed/presentation/feed_screen.dart';
import '../features/feed/presentation/illustration_detail_screen.dart';
import '../features/library/presentation/library_screen.dart';
import '../features/search/presentation/search_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/shell/presentation/home_shell.dart';

/// Route names centralised for consistency and deep linking.
abstract final class AppRoute {
  static const feed = '/feed';
  static const feedDetail = 'feed_detail';
  static const search = '/search';
  static const library = '/library';
  static const settings = '/settings';
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Provides the `GoRouter` instance so it can react to state changes.
final appRouterProvider = Provider<GoRouter>(
  (ref) => GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoute.feed,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.feed,
                name: AppRoute.feed,
                builder: (context, state) => const FeedScreen(),
                routes: [
                  GoRoute(
                    path: 'detail',
                    name: AppRoute.feedDetail,
                    builder: (context, state) {
                      int? index;
                      final extra = state.extra;
                      if (extra is int) {
                        index = extra;
                      } else {
                        final indexParam = state.uri.queryParameters['index'];
                        if (indexParam != null) {
                          index = int.tryParse(indexParam);
                        }
                      }

                      if (index == null) {
                        return const _RouteErrorScreen();
                      }
                      return IllustrationDetailScreen(initialIndex: index);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.search,
                name: AppRoute.search,
                builder: (context, state) => const SearchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.library,
                name: AppRoute.library,
                builder: (context, state) => const LibraryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.settings,
                name: AppRoute.settings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  ),
);

class _RouteErrorScreen extends StatelessWidget {
  const _RouteErrorScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: const Center(child: Text('未找到内容')),
    );
  }
}
