import 'package:app/features/game/application/use_cases/submit_answer_use_case.dart';
import 'package:app/features/game/domain/entities/answer_result.dart';
import 'package:app/features/game/domain/entities/challenge_session.dart';
import 'package:app/features/game/domain/value_objects/hand_id.dart';
import 'package:app/features/game/presentation/game_screen.dart';
import 'package:app/features/game/presentation/view_models/game_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// `SubmitAnswerUseCase`の呼び出し回数を数える偽実装。
class _CountingSubmitAnswerUseCase extends SubmitAnswerUseCase {
  int callCount = 0;

  @override
  ({ChallengeSession session, AnswerResult result}) call({
    required ChallengeSession session,
    required HandId? selectedHand,
  }) {
    callCount++;
    return super.call(session: session, selectedHand: selectedHand);
  }
}

/// スケジュールされたコールバックを溜め込み、テストから手動実行する偽のスケジューラ。
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
  testWidgets('answeringフェーズで手をタップすると1回だけ回答が受理される', (WidgetTester tester) async {
    final _FakeScheduler scheduler = _FakeScheduler();
    final _CountingSubmitAnswerUseCase countingUseCase = _CountingSubmitAnswerUseCase();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameSchedulerProvider.overrideWithValue(scheduler.call),
          submitAnswerUseCaseProvider.overrideWithValue(countingUseCase),
        ],
        child: const MaterialApp(home: GameScreen()),
      ),
    );
    await tester.pump();

    scheduler.runNext(); // confirming -> shuffling
    await tester.pump();
    scheduler.runNext(); // shuffling -> answering
    await tester.pump();

    final Finder handTap0 = find.byKey(const ValueKey<String>('hand-tap-0'));
    await tester.tap(handTap0);
    await tester.pump();
    await tester.tap(handTap0);
    await tester.pump();

    expect(countingUseCase.callCount, 1);
  });
}
