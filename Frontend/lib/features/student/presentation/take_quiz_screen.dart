import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/providers/quiz_data_providers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/confirm_bottom_sheet.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/option_tile.dart';
import '../../../shared/widgets/timer_ring.dart';
import '../providers/student_result_providers.dart';
import '../providers/take_quiz_provider.dart';

const _optionKeys = ['A', 'B', 'C', 'D'];

class TakeQuizScreen extends ConsumerWidget {
  const TakeQuizScreen({super.key, required this.quizId});
  final int quizId;

  Future<void> _confirmExit(BuildContext context) async {
    final leave = await showConfirmBottomSheet(
      context,
      title: 'Leave this quiz?',
      message: "Your answers won't be saved and no attempt will be recorded.",
      confirmLabel: 'Leave quiz',
      cancelLabel: 'Keep going',
    );
    // Navigator.pop bypasses the PopScope guarding the attempt.
    if (leave && context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = takeQuizControllerProvider(quizId);
    final stateAsync = ref.watch(provider);

    ref.listen(provider, (prev, next) {
      final before = prev?.valueOrNull;
      final now = next.valueOrNull;
      if (now == null) return;

      if (now.phase == AttemptPhase.submitted && before?.phase != AttemptPhase.submitted) {
        ref.invalidate(myResultsProvider);
        ref.invalidate(myStatsProvider);
        invalidateQuizData(ref, quizId: quizId);
        final result = now.result!;
        // `go` replaces the quiz in the stack, so back from the result
        // returns to the dashboard instead of a finished quiz.
        context.go(AppRoutes.studentResult(result.id), extra: result);
        return;
      }
      if (now.timeExpired && !(before?.timeExpired ?? false)) {
        HapticFeedback.heavyImpact();
      }
      if (now.remainingSeconds == 60 && (before?.remainingSeconds ?? 0) > 60) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('1 minute left')),
        );
      }
    });

    final inProgress = stateAsync.valueOrNull?.phase == AttemptPhase.inProgress ||
        stateAsync.valueOrNull?.phase == AttemptPhase.submitting;

    return PopScope(
      canPop: !inProgress,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && stateAsync.valueOrNull?.isSubmitting != true) _confirmExit(context);
      },
      child: stateAsync.when(
        loading: () => Scaffold(appBar: AppBar(), body: const LoadingView()),
        error: (e, __) => Scaffold(
          appBar: AppBar(title: const Text('Quiz')),
          body: ErrorView.from(e, onRetry: () => ref.invalidate(provider)),
        ),
        data: (state) => _QuizBody(
          quizId: quizId,
          state: state,
          onExit: () => _confirmExit(context),
        ),
      ),
    );
  }
}

class _QuizBody extends ConsumerWidget {
  const _QuizBody({required this.quizId, required this.state, required this.onExit});
  final int quizId;
  final TakeQuizState state;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controller = ref.read(takeQuizControllerProvider(quizId).notifier);
    final question = state.currentQuestion;
    final selected = state.answers[question.id];
    final progress = state.answeredCount / state.questions.length;
    final lowTime = !state.timeExpired && state.remainingSeconds <= 60;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Leave quiz',
              icon: const Icon(Icons.close_rounded),
              onPressed: state.isSubmitting ? null : onExit,
            ),
            title: Text(
              state.quiz.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: Semantics(
                  label: 'Time remaining',
                  child: TimerRing(
                    remainingSeconds: state.remainingSeconds,
                    totalSeconds: state.totalSeconds,
                    size: 48,
                    strokeWidth: 4,
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, 0),
                  child: Row(
                    children: [
                      Text(
                        'Question ${state.currentIndex + 1} of ${state.questions.length}',
                        style: theme.textTheme.labelLarge,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _showOverview(context, ref),
                        icon: const Icon(Icons.grid_view_rounded, size: 18),
                        label: Text('${state.answeredCount}/${state.questions.length} answered'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: progress),
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOut,
                      builder: (context, value, _) => LinearProgressIndicator(value: value, minHeight: 6),
                    ),
                  ),
                ),
                if (state.timeExpired || lowTime || state.submitError != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                    child: _StatusBanner(state: state, onRetry: controller.submit),
                  ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero)
                            .animate(animation),
                        child: child,
                      ),
                    ),
                    child: ListView(
                      key: ValueKey(question.id),
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      children: [
                        Text(question.text, style: theme.textTheme.displaySmall),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '${question.marks} mark${question.marks == 1 ? '' : 's'}',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        for (final k in _optionKeys)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: OptionTile(
                              keyLabel: k,
                              text: question.options.forKey(k),
                              isSelected: selected == k,
                              onTap: state.canEditAnswers
                                  ? () {
                                      HapticFeedback.selectionClick();
                                      controller.selectAnswer(question.id, k);
                                    }
                                  : null,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
                  child: Row(
                    children: [
                      if (!state.isFirst) ...[
                        Expanded(
                          child: AppButton(
                            label: 'Previous',
                            icon: Icons.arrow_back_rounded,
                            variant: AppButtonVariant.outlined,
                            onPressed: controller.previous,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Expanded(
                        child: state.isLast
                            ? AppButton(
                                label: 'Review & submit',
                                onPressed: () => _showOverview(context, ref),
                              )
                            : AppButton(label: 'Next', onPressed: controller.next),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (state.isSubmitting) const _SubmittingOverlay(),
      ],
    );
  }

  void _showOverview(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _OverviewSheet(quizId: quizId),
    );
  }
}

/// Grid of every question (answered / unanswered / current) plus Submit.
/// Watches the provider itself so it stays live while open (timer expiry).
class _OverviewSheet extends ConsumerWidget {
  const _OverviewSheet({required this.quizId});
  final int quizId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(takeQuizControllerProvider(quizId)).valueOrNull;
    if (state == null || state.phase == AttemptPhase.submitted) return const SizedBox.shrink();
    final controller = ref.read(takeQuizControllerProvider(quizId).notifier);
    final theme = Theme.of(context);
    final unanswered = state.unansweredCount;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Review answers', style: theme.textTheme.displaySmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                unanswered == 0
                    ? 'All ${state.questions.length} questions answered. Nice work!'
                    : '$unanswered of ${state.questions.length} unanswered — these will be marked incorrect.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: unanswered == 0 ? AppColors.success : AppColors.warning,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 56,
                    mainAxisSpacing: AppSpacing.sm,
                    crossAxisSpacing: AppSpacing.sm,
                  ),
                  itemCount: state.questions.length,
                  itemBuilder: (context, i) {
                    final answered = state.answers.containsKey(state.questions[i].id);
                    final current = i == state.currentIndex;
                    final color = answered ? AppColors.success : AppColors.warning;
                    return Semantics(
                      button: true,
                      label: 'Question ${i + 1}, ${answered ? 'answered' : 'unanswered'}',
                      child: InkWell(
                        borderRadius: AppRadii.smRadius,
                        onTap: () {
                          controller.goToIndex(i);
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: answered ? 0.14 : 0.06),
                            border: Border.all(
                              color: current ? theme.colorScheme.onSurface : color.withValues(alpha: 0.6),
                              width: current ? 2 : 1,
                            ),
                            borderRadius: AppRadii.smRadius,
                          ),
                          child: Text('${i + 1}', style: theme.textTheme.labelLarge),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: unanswered == 0 ? 'Submit quiz' : 'Submit anyway',
                icon: Icons.send_rounded,
                isLoading: state.isSubmitting,
                onPressed: () {
                  Navigator.of(context).pop();
                  controller.submit();
                },
              ),
              if (state.canEditAnswers) ...[
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Keep answering',
                  variant: AppButtonVariant.text,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.state, required this.onRetry});
  final TakeQuizState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (Color color, IconData icon, String text) = switch (state) {
      TakeQuizState(submitError: final e?) => (
          AppColors.error,
          Icons.cloud_off_rounded,
          "Couldn't submit: ${e.message}",
        ),
      TakeQuizState(timeExpired: true) => (
          AppColors.error,
          Icons.timer_off_outlined,
          "Time's up! Submitting your answers…",
        ),
      _ => (
          AppColors.warning,
          Icons.timer_outlined,
          'Less than a minute left — wrap up and submit.',
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadii.mdRadius,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: color))),
          if (state.submitError != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _SubmittingOverlay extends StatelessWidget {
  const _SubmittingOverlay();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.35),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: AppRadii.lgRadius,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: AppSpacing.md),
                Text('Grading your answers…', style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
