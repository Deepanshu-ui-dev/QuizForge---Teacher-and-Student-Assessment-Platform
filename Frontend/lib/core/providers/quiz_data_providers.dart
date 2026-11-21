import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/paginated.dart';
import '../models/question.dart';
import '../models/quiz.dart';
import '../models/result.dart';
import '../repositories/repository_providers.dart';

class QuizListParams {
  const QuizListParams({this.search, this.difficulty, this.mine = false});
  final String? search;
  final QuizDifficulty? difficulty;

  /// Only quizzes created by the signed-in teacher.
  final bool mine;

  @override
  bool operator ==(Object other) =>
      other is QuizListParams &&
      other.search == search &&
      other.difficulty == difficulty &&
      other.mine == mine;

  @override
  int get hashCode => Object.hash(search, difficulty, mine);
}

final quizListProvider =
    FutureProvider.autoDispose.family<PaginatedResult<Quiz>, QuizListParams>((ref, params) {
  final repo = ref.watch(quizRepositoryProvider);
  return repo.getQuizzes(
    search: params.search,
    difficulty: params.difficulty,
    mine: params.mine,
  );
});

final quizDetailProvider = FutureProvider.autoDispose.family<Quiz, int>((ref, quizId) {
  final repo = ref.watch(quizRepositoryProvider);
  return repo.getQuizById(quizId);
});

final questionsByQuizProvider =
    FutureProvider.autoDispose.family<List<Question>, int>((ref, quizId) {
  final repo = ref.watch(questionRepositoryProvider);
  return repo.getQuestionsByQuiz(quizId);
});

final resultDetailProvider = FutureProvider.autoDispose.family<QuizResult, int>((ref, resultId) {
  return ref.watch(resultRepositoryProvider).getResultById(resultId);
});

/// Call after any quiz/question mutation so every screen showing quiz
/// metadata (lists, detail, question counts) refetches.
void invalidateQuizData(WidgetRef ref, {int? quizId}) {
  ref.invalidate(quizListProvider);
  if (quizId != null) {
    ref.invalidate(quizDetailProvider(quizId));
    ref.invalidate(questionsByQuizProvider(quizId));
  }
}
