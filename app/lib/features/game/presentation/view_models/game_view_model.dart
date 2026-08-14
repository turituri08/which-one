import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/use_cases/start_challenge_use_case.dart';
import '../../application/use_cases/submit_answer_use_case.dart';
import '../../domain/entities/challenge_session.dart';
import '../../domain/value_objects/game_phase.dart';
import '../../domain/value_objects/hand_id.dart';
import 'game_ui_state.dart';

/// `duration`後に`callback`を1回実行する処理を差し替え可能にする関数型。
///
/// 本番実装では`Timer`を使うが、ユニットテストでは実時間を待たずに
/// 即時実行できる偽実装へ差し替えることで、フェーズ自動遷移を高速に検証する。
typedef GameScheduler = void Function(Duration duration, void Function() callback);

void _timerScheduler(Duration duration, void Function() callback) {
  Timer(duration, callback);
}

/// 本番用スケジューラのProvider。テストでは偽実装へoverrideする。
final Provider<GameScheduler> gameSchedulerProvider = Provider<GameScheduler>(
  (ref) => _timerScheduler,
);

final NotifierProvider<GameViewModel, GameUiState> gameViewModelProvider =
    NotifierProvider<GameViewModel, GameUiState>(GameViewModel.new);

/// 1チャレンジの進行を管理するViewModel。
///
/// `confirming`/`shuffling`/`correct`/`incorrect`は入力を受け付けず、
/// 固定時間またはシャッフル尺の経過で自動的に次フェーズへ進む。
///
/// アプリが非アクティブになっても、ここで動くタイマーは一切止めない（ADR 0004）。
/// そのため`GameScreen`側もアプリライフサイクルを監視せず、`_scheduler`は常に
/// 実時間ベースで進行し続ける。
class GameViewModel extends Notifier<GameUiState> {
  late final StartChallengeUseCase _startChallengeUseCase;
  late final SubmitAnswerUseCase _submitAnswerUseCase;
  late final GameScheduler _scheduler;

  // 数値は未確定のため暫定値（Roadmap方針に従い後続フェーズのプレイテストで調整）。
  static const Duration _confirmingDuration = Duration(seconds: 2);
  static const Duration _correctDuration = Duration(milliseconds: 800);
  static const Duration _incorrectDuration = Duration(seconds: 2);

  // 回答タイマー。初期リリースは全レベル固定30秒とする。
  static const Duration _answeringDuration = Duration(seconds: 30);
  // 残り時間表示を1秒刻みで更新するための間隔。
  static const Duration _answeringTickInterval = Duration(seconds: 1);

  ChallengeSession? _session;

  @override
  GameUiState build() {
    // Providerからの注入により、テストではuse case/schedulerをoverrideできる。
    _startChallengeUseCase = ref.watch(startChallengeUseCaseProvider);
    _submitAnswerUseCase = ref.watch(submitAnswerUseCaseProvider);
    _scheduler = ref.watch(gameSchedulerProvider);
    return const GameUiState();
  }

  /// Level 1からチャレンジを開始する。
  void startChallenge() {
    final ChallengeSession session = _startChallengeUseCase();
    _session = session;
    state = GameUiState(
      phase: session.phase,
      level: session.level,
      highestLevel: session.highestLevel,
      plan: session.plan,
    );
    _scheduleConfirmingToShuffling();
  }

  void _scheduleConfirmingToShuffling() {
    _scheduler(_confirmingDuration, () {
      // 遅延実行の間に別の遷移が起きていれば、古いコールバックとして無視する。
      if (state.phase != GamePhase.confirming) {
        return;
      }
      state = state.copyWith(phase: GamePhase.shuffling);
      _scheduleShufflingToAnswering();
    });
  }

  void _scheduleShufflingToAnswering() {
    final Duration shuffleDuration = _session!.plan.totalDuration;
    _scheduler(shuffleDuration, () {
      if (state.phase != GamePhase.shuffling) {
        return;
      }
      state = state.copyWith(
        phase: GamePhase.answering,
        remainingSeconds: _answeringDuration.inSeconds,
      );
      _scheduleAnsweringTick(_answeringDuration.inSeconds);
    });
  }

  /// 回答フェーズの残り時間を1秒ごとに減算し、UIへ公開する。
  ///
  /// `Timer.periodic`のような繰り返しタイマーは使わず、1回だけ発火する
  /// `_scheduler`呼び出しをこのメソッド自身が再帰的に呼び直すことで、
  /// 「1秒ごとに発火し続ける」動きを実現している。ガードで`return`した
  /// 分岐（フェーズがanswering以外／残り0秒）では再帰しないため、
  /// そこで連鎖が止まる。
  void _scheduleAnsweringTick(int secondsRemainingAtSchedule) {
    _scheduler(_answeringTickInterval, () {
      if (state.phase != GamePhase.answering) {
        return;
      }
      final int next = secondsRemainingAtSchedule - 1;
      if (next <= 0) {
        state = state.copyWith(remainingSeconds: 0);
        // 時間切れはnullの回答としてsubmitAnswerへ委譲し、判定経路を1本化する。
        submitAnswer(null);
        return;
      }
      state = state.copyWith(remainingSeconds: next);
      // まだanswering中なら、次の1秒後ティックを新たに1つ予約する（自己再帰）。
      _scheduleAnsweringTick(next);
    });
  }

  /// プレイヤーが選択した手を提出する。時間切れの場合は`null`を渡す。
  void submitAnswer(HandId? selectedHand) {
    // answering以外からの入力（二重入力・遅延イベント）は受け付けない。
    if (state.phase != GamePhase.answering) {
      return;
    }

    final outcome = _submitAnswerUseCase(session: _session!, selectedHand: selectedHand);
    _session = outcome.session;
    state = state.copyWith(
      phase: outcome.session.phase,
      level: outcome.session.level,
      highestLevel: outcome.session.highestLevel,
      plan: outcome.session.plan,
      lastAnswerResult: outcome.result,
    );

    if (outcome.session.phase == GamePhase.correct) {
      _scheduleCorrectToNextConfirming();
    } else {
      _scheduleIncorrectToResult();
    }
  }

  void _scheduleCorrectToNextConfirming() {
    _scheduler(_correctDuration, () {
      if (state.phase != GamePhase.correct) {
        return;
      }
      state = state.copyWith(phase: GamePhase.confirming);
      _scheduleConfirmingToShuffling();
    });
  }

  void _scheduleIncorrectToResult() {
    _scheduler(_incorrectDuration, () {
      if (state.phase != GamePhase.incorrect) {
        return;
      }
      state = state.copyWith(phase: GamePhase.result);
    });
  }
}
