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
class GameViewModel extends Notifier<GameUiState> {
  late final StartChallengeUseCase _startChallengeUseCase;
  late final SubmitAnswerUseCase _submitAnswerUseCase;
  late final GameScheduler _scheduler;

  // 数値は未確定のため暫定値（Roadmap方針に従い後続フェーズのプレイテストで調整）。
  static const Duration _confirmingDuration = Duration(seconds: 2);
  static const Duration _correctDuration = Duration(milliseconds: 800);
  static const Duration _incorrectDuration = Duration(seconds: 2);

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
      state = state.copyWith(phase: GamePhase.answering);
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
