import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../view/screens/main_screen.dart';
import '../../view/screens/search/search_screen.dart';
import '../../view/screens/settings/settings_screen.dart';
import 'swipeable_page_route.dart';

part 'app_route.g.dart';

@TypedGoRoute<MainRoute>(
  path: '/',
  routes: [
    TypedGoRoute<SearchRoute>(path: 'search'),
    TypedGoRoute<SettingsRoute>(path: 'settings'),
  ],
)
class MainRoute extends GoRouteData with $MainRoute {
  const MainRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const MainScreen();
}

class SearchRoute extends GoRouteData with $SearchRoute {
  const SearchRoute();

  @override
  CustomTransitionPage<void> buildPage(BuildContext context, GoRouterState state) => CustomTransitionPage<void>(
    key: state.pageKey,
    child: const SearchScreen(),
    transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
  );
}

class SettingsRoute extends GoRouteData with $SettingsRoute {
  const SettingsRoute();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) => SwipeablePage<void>(builder: (context) => const SettingsScreen());
}
