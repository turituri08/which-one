import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_route_paths.dart';
import '../../../core/constants/app_strings.dart';
import '../domain/value_objects/game_phase.dart';
import 'view_models/game_ui_state.dart';
import 'view_models/game_view_model.dart';
import 'widgets/hands_view.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  @override
  void initState() {
    super.initState();
    // build中はProviderの状態を変更できないため、マイクロタスクへ遅延させる。
    // 画面遷移直後にコイン確認フェーズへ入る。
    Future.microtask(() => ref.read(gameViewModelProvider.notifier).startChallenge());
  }

  @override
  Widget build(BuildContext context) {
    final GameUiState state = ref.watch(gameViewModelProvider);
    final GameViewModel notifier = ref.read(gameViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.gameTitle)),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${AppStrings.levelLabel} ${state.level}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            // 残り時間はanswering中のみ意味を持つため、それ以外では表示しない。
            if (state.phase == GamePhase.answering)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '${AppStrings.remainingSecondsLabel} ${state.remainingSeconds}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            Expanded(
              child: HandsView(state: state, onHandTap: notifier.submitAnswer),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextButton(
                onPressed: () => context.go(AppRoutePaths.home),
                child: const Text(AppStrings.backToTitle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
