import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_platform/core/errors/failure.dart';
import 'package:quiz_platform/core/models/question.dart';
import 'package:quiz_platform/core/models/quiz.dart';
import 'package:quiz_platform/core/models/result.dart';
import 'package:quiz_platform/core/repositories/question_repository.dart';
import 'package:quiz_platform/core/repositories/quiz_repository.dart';
import 'package:quiz_platform/core/repositories/repository_providers.dart';
import 'package:quiz_platform/core/repositories/result_repository.dart';
import 'package:quiz_platform/features/student/providers/take_quiz_provider.dart';

Quiz _quiz({int durationMinutes = 1}) => Quiz(
      id: 1,
      title: 'Q',
      description: 'desc',
      duration: durationMinutes,
      difficulty: QuizDifficulty.easy,
      createdAt: DateTime(2026),
      stats: const QuizStats(totalQuestions: 2, totalResults: 0),
    );

Question _question(int id) => Question(
      id: id,
      text: 'Question $id',
      options: const QuestionOptions(a: 'a', b: 'b', c: 'c', d: 'd'),
      marks: 1,
    );

QuizResult _result() => QuizResult(
      id: 99,
      quizId: 1,
      score: 1,
      totalMarks: 2,
      percentage: 50,
      correctAnswers: 1,
      wrongAnswers: 1,
      submittedAt: DateTime(2026),
    );

class _FakeQuizRepo extends QuizRepository {
  _FakeQuizRepo(this.quiz) : super(Dio());
  final Quiz quiz;
  @override
  Future<Quiz> getQuizById(int id) async => quiz;
}

class _FakeQuestionRepo extends QuestionRepository {
  _FakeQuestionRepo(this.questions) : super(Dio());
  final List<Question> questions;
  @override
  Future<List<Question>> getQuestionsByQuiz(int quizId) async => questions;
}

class _FakeResultRepo extends ResultRepository {
  _FakeResultRepo() : super(Dio());
  int submitCalls = 0;
  List<({int questionId, String answer})>? lastAnswers;
  Completer<QuizResult>? pending;
  Object? failWith;

  @override
  Future<QuizResult> submitQuiz({
    required int quizId,
    required List<({int questionId, String answer})> answers,
  }) {
    submitCalls++;
    lastAnswers = answers;
    if (failWith != null) return Future.error(failWith!);
    pending = Completer<QuizResult>();
    return pending!.future;
  }
}

void main() {
  late DateTime now;
  late _FakeResultRepo results;

  ProviderContainer makeContainer({List<Question>? questions, int durationMinutes = 1}) {
    final container = ProviderContainer(overrides: [
      clockProvider.overrideWithValue(() => now),
      quizRepositoryProvider.overrideWithValue(_FakeQuizRepo(_quiz(durationMinutes: durationMinutes))),
      questionRepositoryProvider
          .overrideWithValue(_FakeQuestionRepo(questions ?? [_question(10), _question(11)])),
      resultRepositoryProvider.overrideWithValue(results),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    now = DateTime(2026, 1, 1, 12);
    results = _FakeResultRepo();
  });

  Future<TakeQuizState> start(ProviderContainer c) {
    // Keep the autoDispose provider alive for the duration of the test.
    c.listen(takeQuizControllerProvider(1), (_, __) {});
    return c.read(takeQuizControllerProvider(1).future);
  }

  TakeQuizState read(ProviderContainer c) => c.read(takeQuizControllerProvider(1)).requireValue;
  TakeQuizController ctrl(ProviderContainer c) => c.read(takeQuizControllerProvider(1).notifier);

  test('starts in progress with a deadline from the quiz duration', () async {
    final c = makeContainer(durationMinutes: 2);
    final s = await start(c);
    expect(s.phase, AttemptPhase.inProgress);
    expect(s.remainingSeconds, 120);
    expect(s.deadline, now.add(const Duration(minutes: 2)));
  });

  test('a quiz without questions errors instead of crashing', () async {
    final c = makeContainer(questions: []);
    c.listen(takeQuizControllerProvider(1), (_, __) {});
    await expectLater(c.read(takeQuizControllerProvider(1).future), throwsA(isA<ValidationFailure>()));
  });

  test('double submit only sends one request', () async {
    final c = makeContainer();
    await start(c);
    ctrl(c).selectAnswer(10, 'A');

    final first = ctrl(c).submit();
    final second = ctrl(c).submit();
    expect(read(c).phase, AttemptPhase.submitting);
    expect(results.submitCalls, 1);

    results.pending!.complete(_result());
    await Future.wait([first, second]);
    expect(read(c).phase, AttemptPhase.submitted);
    expect(read(c).result?.id, 99);
  });

  test('a failed submit returns to in-progress with the error and can be retried', () async {
    final c = makeContainer();
    await start(c);
    results.failWith = const NetworkFailure();

    await ctrl(c).submit();
    expect(read(c).phase, AttemptPhase.inProgress);
    expect(read(c).submitError, isA<NetworkFailure>());

    results.failWith = null;
    final retry = ctrl(c).submit();
    expect(read(c).submitError, isNull);
    results.pending!.complete(_result());
    await retry;
    expect(read(c).phase, AttemptPhase.submitted);
    expect(results.submitCalls, 2);
  });

  test('answers are locked while submitting', () async {
    final c = makeContainer();
    await start(c);
    ctrl(c).selectAnswer(10, 'A');
    final pending = ctrl(c).submit();
    ctrl(c).selectAnswer(10, 'B');
    expect(read(c).answers[10], 'A');
    results.pending!.complete(_result());
    await pending;
  });

  test('timer expiry locks answers and auto-submits the partial attempt', () async {
    final c = makeContainer();
    await start(c);
    ctrl(c).selectAnswer(10, 'C');

    now = now.add(const Duration(minutes: 1, seconds: 1));
    await Future<void>.delayed(const Duration(milliseconds: 700));

    final s = read(c);
    expect(s.timeExpired, isTrue);
    expect(s.remainingSeconds, 0);
    expect(s.phase, AttemptPhase.submitting);
    expect(results.submitCalls, 1);
    expect(results.lastAnswers, [(questionId: 10, answer: 'C')]);

    ctrl(c).selectAnswer(11, 'A');
    expect(read(c).answers.containsKey(11), isFalse);
    results.pending!.complete(_result());
  });

  test('countdown follows the wall clock, not tick count', () async {
    final c = makeContainer(durationMinutes: 5);
    await start(c);
    // Simulate the app being backgrounded for 2 minutes with no ticks.
    now = now.add(const Duration(minutes: 2));
    await Future<void>.delayed(const Duration(milliseconds: 700));
    expect(read(c).remainingSeconds, 180);
  });

  test('navigation stays within bounds', () async {
    final c = makeContainer();
    await start(c);
    ctrl(c).previous();
    expect(read(c).currentIndex, 0);
    ctrl(c).next();
    ctrl(c).next();
    expect(read(c).currentIndex, 1);
    expect(read(c).isLast, isTrue);
  });
}
