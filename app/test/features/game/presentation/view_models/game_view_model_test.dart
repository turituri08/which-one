import 'package:app/features/game/domain/value_objects/game_phase.dart';
import 'package:app/features/game/domain/value_objects/hand_id.dart';
import 'package:app/features/game/presentation/view_models/game_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// スケジュールされたコールバックを実行せず溜め込み、テストから1つずつ
/// 手動実行できるようにする偽のスケジューラ。実時間を待たずに
/// フェーズの自動遷移を検証するために使う。
class _FakeScheduler {
  final List<void Function()> _pending = <void Function()>[];

  void call(Duration duration, void Function() callback) {
    _pending.add(callback);
  }

  void runNext() {
    final void Function() callback = _pending.removeAt(0);
    callback();
  }
}

void main() {
  group('GameViewModel', () {
    late _FakeScheduler scheduler;
    late ProviderContainer container;

    setUp(() {
      scheduler = _FakeScheduler();
      container = ProviderContainer(
        overrides: [gameSchedulerProvider.overrideWithValue(scheduler.call)],
      );
      addTearDown(container.dispose);
    });

    GameViewModel viewModel() => container.read(gameViewModelProvider.notifier);

    test('開始するとconfirmingへ遷移し、シャッフル計画が公開される', () {
      viewModel().startChallenge();

      final state = container.read(gameViewModelProvider);
      expect(state.phase, GamePhase.confirming);
      expect(state.level, 1);
      expect(state.highestLevel, 0);
      expect(state.plan, isNotNull);
    });

    test('confirming -> shuffling -> answeringへ自動遷移する', () {
      viewModel().startChallenge();

      scheduler.runNext();
      expect(container.read(gameViewModelProvider).phase, GamePhase.shuffling);

      scheduler.runNext();
      expect(container.read(gameViewModelProvider).phase, GamePhase.answering);
    });

    test('正解するとcorrectへ遷移してレベルが進み、その後confirmingへ自動で戻る', () {
      viewModel().startChallenge();
      scheduler.runNext();
      scheduler.runNext();

      final HandId correctHand = container.read(gameViewModelProvider).plan!.finalHolder;
      viewModel().submitAnswer(correctHand);

      final afterAnswer = container.read(gameViewModelProvider);
      expect(afterAnswer.phase, GamePhase.correct);
      expect(afterAnswer.level, 2);
      expect(afterAnswer.highestLevel, 1);
      expect(afterAnswer.lastAnswerResult!.isCorrect, isTrue);

      scheduler.runNext();
      expect(container.read(gameViewModelProvider).phase, GamePhase.confirming);
    });

    test('不正解するとincorrectへ遷移し、その後resultへ自動で進む', () {
      viewModel().startChallenge();
      scheduler.runNext();
      scheduler.runNext();

      final HandId correctHand = container.read(gameViewModelProvider).plan!.finalHolder;
      final HandId wrongHand = HandId(
        performerPosition: correctHand.performerPosition,
        handIndex: correctHand.handIndex == 0 ? 1 : 0,
      );
      viewModel().submitAnswer(wrongHand);

      expect(container.read(gameViewModelProvider).phase, GamePhase.incorrect);

      scheduler.runNext();
      expect(container.read(gameViewModelProvider).phase, GamePhase.result);
    });

    test('時間切れ（nullの回答）はincorrect扱いになる', () {
      viewModel().startChallenge();
      scheduler.runNext();
      scheduler.runNext();

      viewModel().submitAnswer(null);

      final state = container.read(gameViewModelProvider);
      expect(state.phase, GamePhase.incorrect);
      expect(state.lastAnswerResult!.isTimedOut, isTrue);
    });

    test('answering以外での回答提出は無視される（二重入力防止の最小ガード）', () {
      viewModel().startChallenge();

      viewModel().submitAnswer(null);

      expect(container.read(gameViewModelProvider).phase, GamePhase.confirming);
    });
  });
}
