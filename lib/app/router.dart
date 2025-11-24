import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/models/content_item.dart';
import '../features/feed/presentation/feed_screen.dart';
import '../features/feed/presentation/illustration_detail_screen.dart';
import '../features/feed/providers/feed_providers.dart' show IllustrationSource;
import '../features/library/presentation/library_screen.dart';
import '../features/novel/presentation/novel_detail_screen.dart';
import '../features/novel/presentation/novel_reader_screen.dart';
import '../features/search/presentation/search_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/shell/presentation/home_shell.dart';

/// Route names centralised for consistency and deep linking.
abstract final class AppRoute {
  static const feed = '/feed';
  static const feedDetail = 'feed_detail';
  static const feedNovelDetail = 'feed_novel_detail';
  static const feedNovelReader = 'feed_novel_reader';
  static const search = '/search';
  static const library = '/library';
  static const libraryFavorites = 'library_favorites';
  static const libraryHistory = 'library_history';
  static const settings = '/settings';
}

IllustrationSource? _illustrationSourceFromParam(String? value) {
  switch (value?.toLowerCase()) {
    case 'mixed':
      return IllustrationSource.mixed;
    case 'pixiv':
      return IllustrationSource.pixiv;
    case 'e621':
      return IllustrationSource.e621;
    default:
      return null;
  }
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
            HomeShell(navigationShell: navigationShell, currentState: state),
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
                    pageBuilder: (context, state) {
                      IllustrationDetailRouteArgs? args;
                      final extra = state.extra;
                      if (extra is IllustrationDetailRouteArgs) {
                        args = extra;
                      } else {
                        final indexParam = state.uri.queryParameters['index'];
                        final sourceParam = state.uri.queryParameters['source'];
                        final index = indexParam != null
                            ? int.tryParse(indexParam)
                            : null;
                        final source = _illustrationSourceFromParam(
                          sourceParam,
                        );
                        if (index != null && source != null) {
                          args = IllustrationDetailRouteArgs(
                            source: source,
                            initialIndex: index,
                          );
                        }
                      }

                      if (args == null) {
                        return CustomTransitionPage<void>(
                          key: state.pageKey,
                          child: const _RouteErrorScreen(),
                          transitionsBuilder: _detailPageTransitionBuilder,
                        );
                      }
                      return CustomTransitionPage<void>(
                        key: state.pageKey,
                        child: IllustrationDetailScreen(
                          source: args.source,
                          initialIndex: args.initialIndex,
                          skipInitialWarningPrompt:
                              args.skipInitialWarningPrompt,
                          initialContent: args.initialContent,
                        ),
                        transitionsBuilder: _detailPageTransitionBuilder,
                      );
                    },
                  ),
                  GoRoute(
                    path: 'novel/:novelId',
                    name: AppRoute.feedNovelDetail,
                    pageBuilder: (context, state) {
                      final novelIdParam = state.pathParameters['novelId'];
                      final novelId = novelIdParam != null
                          ? int.tryParse(novelIdParam)
                          : null;
                      final indexParam = state.uri.queryParameters['index'];
                      int? initialIndex;
                      if (indexParam != null) {
                        initialIndex = int.tryParse(indexParam);
                      }
                      FaioContent? initialContent;
                      var skipInitialWarningPrompt = false;
                      final extra = state.extra;
                      if (extra is NovelDetailRouteExtra) {
                        initialContent = extra.initialContent;
                        initialIndex = extra.initialIndex ?? initialIndex;
                        skipInitialWarningPrompt =
                            extra.skipInitialWarningPrompt;
                      } else if (extra is FaioContent) {
                        initialContent = extra;
                      }
                      if (novelId == null) {
                        return CustomTransitionPage<void>(
                          key: state.pageKey,
                          child: const _RouteErrorScreen(),
                          transitionsBuilder: _detailPageTransitionBuilder,
                        );
                      }
                      return CustomTransitionPage<void>(
                        key: state.pageKey,
                        child: NovelDetailScreen(
                          novelId: novelId,
                          initialContent: initialContent,
                          initialIndex: initialIndex,
                          skipInitialWarningPrompt: skipInitialWarningPrompt,
                        ),
                        transitionsBuilder: _detailPageTransitionBuilder,
                      );
                    },
                    routes: [
                      GoRoute(
                        path: 'reader',
                        name: AppRoute.feedNovelReader,
                        builder: (context, state) {
                          final novelIdParam = state.pathParameters['novelId'];
                          final novelId = novelIdParam != null
                              ? int.tryParse(novelIdParam)
                              : null;
                          if (novelId == null) {
                            return const _RouteErrorScreen();
                          }
                          return NovelReaderScreen(novelId: novelId);
                        },
                      ),
                    ],
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
                routes: [
                  GoRoute(
                    path: 'favorites',
                    name: AppRoute.libraryFavorites,
                    builder: (context, state) => const LibraryFavoritesScreen(),
                  ),
                  GoRoute(
                    path: 'history',
                    name: AppRoute.libraryHistory,
                    builder: (context, state) => const LibraryHistoryScreen(),
                  ),
                ],
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

Widget _detailPageTransitionBuilder(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final curved = CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  return FadeTransition(
    opacity: curved,
    child: ScaleTransition(
      scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
      child: child,
    ),
  );
}
