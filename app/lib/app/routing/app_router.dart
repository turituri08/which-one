import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/game/presentation/game_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import 'app_route_paths.dart';

final GoRouter appRouter = GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: AppRoutePaths.home,
      builder: (BuildContext context, GoRouterState state) {
        return const HomeScreen();
      },
    ),
    GoRoute(
      path: AppRoutePaths.game,
      builder: (BuildContext context, GoRouterState state) {
        return const GameScreen();
      },
    ),
  ],
);
