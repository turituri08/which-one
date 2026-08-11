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

      // 回答提出前に予約されていた回答タイマーのティックが残っているため、
      // 先にそれを無害に消化してから、correct -> confirmingの遷移を実行する。
      scheduler.runNext();
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

      // 回答提出前に予約されていた回答タイマーのティックが残っているため、
      // 先にそれを無害に消化してから、incorrect -> resultの遷移を実行する。
      scheduler.runNext();
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

    test('answeringへ遷移すると残り時間が30秒になる', () {
      viewModel().startChallenge();
      scheduler.runNext(); // confirming -> shuffling
      scheduler.runNext(); // shuffling -> answering

      expect(container.read(gameViewModelProvider).remainingSeconds, 30);
    });

    test('残り時間は回答フェーズ中、1秒ごとに更新される', () {
      viewModel().startChallenge();
      scheduler.runNext(); // confirming -> shuffling
      scheduler.runNext(); // shuffling -> answering

      scheduler.runNext(); // 1ティック経過
      expect(container.read(gameViewModelProvider).remainingSeconds, 29);

      scheduler.runNext(); // 2ティック経過
      expect(container.read(gameViewModelProvider).remainingSeconds, 28);
    });

    test('残り時間が尽きると自動的に時間切れとして判定される', () {
      viewModel().startChallenge();
      scheduler.runNext(); // confirming -> shuffling
      scheduler.runNext(); // shuffling -> answering

      for (int i = 0; i < 30; i++) {
        scheduler.runNext();
      }

      final state = container.read(gameViewModelProvider);
      expect(state.phase, GamePhase.incorrect);
      expect(state.lastAnswerResult!.isTimedOut, isTrue);
      expect(state.remainingSeconds, 0);
    });

    test('時間切れ確定後にタップが届いても無視される（競合防止）', () {
      viewModel().startChallenge();
      scheduler.runNext(); // confirming -> shuffling
      scheduler.runNext(); // shuffling -> answering

      final HandId correctHand = container.read(gameViewModelProvider).plan!.finalHolder;
      for (int i = 0; i < 30; i++) {
        scheduler.runNext();
      }

      // 時間切れで既にincorrectへ遷移した後の遅延タップは、二重の結果遷移を起こしてはならない。
      viewModel().submitAnswer(correctHand);

      final state = container.read(gameViewModelProvider);
      expect(state.phase, GamePhase.incorrect);
      expect(state.lastAnswerResult!.isTimedOut, isTrue);
    });

    test('タップで回答確定後に残っていた時間切れティックは無視される（競合防止）', () {
      viewModel().startChallenge();
      scheduler.runNext(); // confirming -> shuffling
      scheduler.runNext(); // shuffling -> answering

      final HandId correctHand = container.read(gameViewModelProvider).plan!.finalHolder;
      viewModel().submitAnswer(correctHand);

      final afterTap = container.read(gameViewModelProvider);
      expect(afterTap.phase, GamePhase.correct);

      // 回答確定前に予約されていた時間切れティックが後から発火しても、状態は変化しない。
      scheduler.runNext();

      final state = container.read(gameViewModelProvider);
      expect(state.phase, GamePhase.correct);
      expect(state.lastAnswerResult!.isCorrect, isTrue);
    });
  });
}
