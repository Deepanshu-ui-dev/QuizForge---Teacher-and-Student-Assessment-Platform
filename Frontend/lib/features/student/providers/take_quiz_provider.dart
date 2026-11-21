import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/models/question.dart';
import '../../../core/models/quiz.dart';
import '../../../core/models/result.dart';
import '../../../core/repositories/repository_providers.dart';

/// Injectable clock so the countdown can be tested deterministically.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Lifecycle of a single attempt.
///
/// ```
///  inProgress ──submit()/timer expiry──▶ submitting ──ok──▶ submitted
///      ▲                                     │
///      └────────────── error ────────────────┘
/// ```
/// Answers are only editable in [inProgress] and before the timer expires.
/// [submitting] and [submitted] reject further submits, which prevents the
/// double-submits that tapping "Submit" during expiry used to cause.
enum AttemptPhase { inProgress, submitting, submitted }

class TakeQuizState {
  const TakeQuizState({
    required this.quiz,
    required this.questions,
    required this.answers,
    required this.currentIndex,
    required this.deadline,
    required this.remainingSeconds,
    this.phase = AttemptPhase.inProgress,
    this.timeExpired = false,
    this.result,
    this.submitError,
  });

  final Quiz quiz;
  final List<Question> questions;
  final Map<int, String> answers;
  final int currentIndex;
  final DateTime deadline;
  final int remainingSeconds;
  final AttemptPhase phase;
  final bool timeExpired;
  final QuizResult? result;
  final Failure? submitError;

  int get totalSeconds => quiz.duration * 60;
  int get answeredCount => answers.length;
  int get unansweredCount => questions.length - answers.length;
  bool get allAnswered => unansweredCount == 0;
  bool get isFirst => currentIndex == 0;
  bool get isLast => currentIndex == questions.length - 1;
  Question get currentQuestion => questions[currentIndex];
  bool get canEditAnswers => phase == AttemptPhase.inProgress && !timeExpired;
  bool get isSubmitting => phase == AttemptPhase.submitting;

  TakeQuizState copyWith({
    Map<int, String>? answers,
    int? currentIndex,
    int? remainingSeconds,
    AttemptPhase? phase,
    bool? timeExpired,
    QuizResult? result,
    Failure? submitError,
    bool clearSubmitError = false,
  }) {
    return TakeQuizState(
      quiz: quiz,
      questions: questions,
      deadline: deadline,
      answers: answers ?? this.answers,
      currentIndex: currentIndex ?? this.currentIndex,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      phase: phase ?? this.phase,
      timeExpired: timeExpired ?? this.timeExpired,
      result: result ?? this.result,
      submitError: clearSubmitError ? null : (submitError ?? this.submitError),
    );
  }
}

class TakeQuizController extends AutoDisposeFamilyAsyncNotifier<TakeQuizState, int> {
  Timer? _timer;

  @override
  Future<TakeQuizState> build(int quizId) async {
    ref.onDispose(() => _timer?.cancel());

    final results = await Future.wait([
      ref.read(quizRepositoryProvider).getQuizById(quizId),
      ref.read(questionRepositoryProvider).getQuestionsByQuiz(quizId),
    ]);
    final quiz = results[0] as Quiz;
    final questions = results[1] as List<Question>;

    if (questions.isEmpty) {
      throw const ValidationFailure(
        "This quiz doesn't have any questions yet. Check back once your teacher adds some.",
      );
    }

    final totalSeconds = quiz.duration * 60;
    final now = ref.read(clockProvider)();
    _startTimer();
    return TakeQuizState(
      quiz: quiz,
      questions: questions,
      answers: const {},
      currentIndex: 0,
      // Deadline-based rather than decrementing a counter: Timer ticks drift
      // and pause while the app is backgrounded, which let students gain time.
      deadline: now.add(Duration(seconds: totalSeconds)),
      remainingSeconds: totalSeconds,
    );
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) => _tick());
  }

  void _tick() {
    final current = state.valueOrNull;
    if (current == null) return;
    if (current.phase == AttemptPhase.submitted) {
      _timer?.cancel();
      return;
    }

    final now = ref.read(clockProvider)();
    final remaining = current.deadline.difference(now).inMilliseconds;
    final seconds = remaining <= 0 ? 0 : (remaining / 1000).ceil();

    if (seconds <= 0 && !current.timeExpired) {
      _timer?.cancel();
      state = AsyncData(current.copyWith(remainingSeconds: 0, timeExpired: true));
      // Auto-submit whatever was answered; the backend grades blanks as wrong.
      submit();
      return;
    }
    if (seconds != current.remainingSeconds) {
      state = AsyncData(current.copyWith(remainingSeconds: seconds));
    }
  }

  void selectAnswer(int questionId, String answer) {
    final current = state.valueOrNull;
    if (current == null || !current.canEditAnswers) return;
    final updated = Map<int, String>.from(current.answers)..[questionId] = answer;
    state = AsyncData(current.copyWith(answers: updated, clearSubmitError: true));
  }

  void goToIndex(int index) {
    final current = state.valueOrNull;
    if (current == null) return;
    if (index < 0 || index >= current.questions.length) return;
    state = AsyncData(current.copyWith(currentIndex: index));
  }

  void next() {
    final current = state.valueOrNull;
    if (current != null) goToIndex(current.currentIndex + 1);
  }

  void previous() {
    final current = state.valueOrNull;
    if (current != null) goToIndex(current.currentIndex - 1);
  }

  /// Safe to call repeatedly; only the first call while [AttemptPhase.inProgress]
  /// does anything. The outcome lands in state ([TakeQuizState.result] or
  /// [TakeQuizState.submitError]).
  Future<void> submit() async {
    final current = state.valueOrNull;
    if (current == null || current.phase != AttemptPhase.inProgress) return;

    state = AsyncData(current.copyWith(phase: AttemptPhase.submitting, clearSubmitError: true));

    try {
      final result = await ref.read(resultRepositoryProvider).submitQuiz(
            quizId: current.quiz.id,
            answers: current.answers.entries
                .map((e) => (questionId: e.key, answer: e.value))
                .toList(),
          );
      _timer?.cancel();
      final latest = state.valueOrNull ?? current;
      state = AsyncData(latest.copyWith(phase: AttemptPhase.submitted, result: result));
    } catch (e) {
      final latest = state.valueOrNull ?? current;
      state = AsyncData(
        latest.copyWith(
          phase: AttemptPhase.inProgress,
          submitError: FailureMapper.fromException(e),
        ),
      );
    }
  }
}

final takeQuizControllerProvider =
    AsyncNotifierProvider.autoDispose.family<TakeQuizController, TakeQuizState, int>(
  TakeQuizController.new,
);
