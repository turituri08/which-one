import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_route_paths.dart';
import '../../../core/constants/app_strings.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.gameTitle)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(AppStrings.gamePlaceholder),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(AppRoutePaths.home),
              child: const Text(AppStrings.backToTitle),
            ),
          ],
        ),
      ),
    );
  }
}
