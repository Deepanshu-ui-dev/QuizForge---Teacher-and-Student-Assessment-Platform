import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/models/question.dart';
import '../../../core/models/result.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/providers/quiz_data_providers.dart';
import '../../../core/utils/app_role.dart';
import '../../../core/utils/date_format.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/percentage_badge.dart';
import '../../../shared/widgets/segmented_control.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../../shared/widgets/stat_ring.dart';

/// Shows one graded attempt. [initial] (passed as route `extra`) renders
/// instantly; if it lacks per-answer detail (list endpoints omit it) the
/// full result is fetched.
class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key, required this.resultId, this.initial});
  final int resultId;
  final QuizResult? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasDetail = initial != null && initial!.answers.isNotEmpty;
    final AsyncValue<QuizResult> resultAsync =
        hasDetail ? AsyncData(initial!) : ref.watch(resultDetailProvider(resultId));

    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: resultAsync.when(
        loading: () => const LoadingView(lines: 5),
        error: (e, __) => ErrorView.from(e, onRetry: () => ref.invalidate(resultDetailProvider(resultId))),
        data: (result) => _ResultBody(result: result),
      ),
    );
  }
}

enum _ReviewFilter { all, incorrect }

class _ResultBody extends ConsumerStatefulWidget {
  const _ResultBody({required this.result});
  final QuizResult result;

  @override
  ConsumerState<_ResultBody> createState() => _ResultBodyState();
}

class _ResultBodyState extends ConsumerState<_ResultBody> {
  _ReviewFilter _filter = _ReviewFilter.all;

  String _headline(double pct) {
    if (pct >= 90) return 'Outstanding!';
    if (pct >= 75) return 'Great job!';
    if (pct >= 50) return 'Good effort';
    return 'Keep practicing';
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final theme = Theme.of(context);
    final isTeacher = ref.watch(sessionProvider.select((s) => s.valueOrNull?.role)) == AppRole.teacher;
    final color = scoreColor(result.percentage, isDark: theme.brightness == Brightness.dark);

    // Best-effort enrichment: show option text next to the chosen letter.
    final questions = ref.watch(questionsByQuizProvider(result.quizId)).valueOrNull;
    final questionById = {for (final q in questions ?? const <Question>[]) q.id: q};

    final answers = _filter == _ReviewFilter.all
        ? result.answers
        : result.answers.where((a) => !a.isCorrect).toList();
    final unanswered = result.unansweredCount;

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl),
      children: [
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: result.percentage.clamp(0, 100).toDouble()),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => StatRing(
              progress: value / 100,
              centerText: '${value.round()}%',
              subLabel: '${result.score}/${result.totalMarks} marks',
              color: color,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          isTeacher ? (result.studentName ?? 'Student') : _headline(result.percentage),
          textAlign: TextAlign.center,
          style: theme.textTheme.displayMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${result.quizTitle ?? 'Quiz #${result.quizId}'} · ${formatDateTime(result.submittedAt)}',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Correct',
                value: '${result.correctAnswers}',
                icon: Icons.check_circle_outline_rounded,
                deltaColor: AppColors.success,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: StatCard(
                label: 'Incorrect',
                value: '${result.wrongAnswers - unanswered}',
                icon: Icons.cancel_outlined,
                deltaColor: AppColors.error,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: StatCard(
                label: 'Skipped',
                value: '$unanswered',
                icon: Icons.remove_circle_outline_rounded,
                deltaColor: unanswered > 0 ? AppColors.warning : null,
              ),
            ),
          ],
        ),
        if (result.answers.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(child: Text('Answer review', style: theme.textTheme.displaySmall)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SegmentedControl<_ReviewFilter>(
            options: const [_ReviewFilter.all, _ReviewFilter.incorrect],
            labels: [
              'All (${result.answers.length})',
              'Incorrect (${result.answers.where((a) => !a.isCorrect).length})',
            ],
            selected: _filter,
            onChanged: (f) => setState(() => _filter = f),
          ),
          const SizedBox(height: AppSpacing.md),
          if (answers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text(
                'No incorrect answers — perfect score! 🎉',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          for (final answer in answers)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _AnswerCard(
                index: result.answers.indexOf(answer) + 1,
                answer: answer,
                question: questionById[answer.questionId],
              ),
            ),
        ],
        if (!isTeacher) ...[
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Back to home',
            icon: Icons.home_outlined,
            onPressed: () => context.go(AppRoutes.studentHome),
          ),
        ],
      ],
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.index, required this.answer, this.question});
  final int index;
  final QuizAttemptAnswerDetail answer;
  final Question? question;

  String _describe(String key) {
    final text = question?.options.forKey(key) ?? '';
    return text.isEmpty ? key : '$key · $text';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (Color color, IconData icon, String status) = !answer.isAnswered
        ? (AppColors.warning, Icons.remove_circle_outline_rounded, 'Skipped')
        : answer.isCorrect
            ? (AppColors.success, Icons.check_circle_rounded, '+${answer.marksAwarded}')
            : (AppColors.error, Icons.cancel_rounded, '0');

    return AppCard(
      borderColor: color.withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Q$index. ${answer.questionText ?? question?.text ?? 'Question ${answer.questionId}'}',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: AppRadii.smRadius,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: color),
                    const SizedBox(width: 4),
                    Text(status, style: theme.textTheme.labelLarge?.copyWith(color: color)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _AnswerLine(
            label: 'Your answer',
            value: answer.isAnswered ? _describe(answer.selectedAnswer) : 'Not answered',
            color: answer.isCorrect ? AppColors.success : (answer.isAnswered ? AppColors.error : null),
          ),
          if (!answer.isCorrect) ...[
            const SizedBox(height: 4),
            _AnswerLine(label: 'Correct', value: _describe(answer.correctAnswer), color: AppColors.success),
          ],
        ],
      ),
    );
  }
}

class _AnswerLine extends StatelessWidget {
  const _AnswerLine({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 96, child: Text(label, style: theme.textTheme.bodySmall)),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
