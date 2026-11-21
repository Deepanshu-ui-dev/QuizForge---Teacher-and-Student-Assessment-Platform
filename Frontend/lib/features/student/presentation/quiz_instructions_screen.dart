import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/models/quiz.dart';
import '../../../core/providers/quiz_data_providers.dart';
import '../../../core/utils/difficulty_style.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/form_error_banner.dart';
import '../../../shared/widgets/loading_view.dart';

class QuizInstructionsScreen extends ConsumerWidget {
  const QuizInstructionsScreen({super.key, required this.quizId});
  final int quizId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quizAsync = ref.watch(quizDetailProvider(quizId));

    return Scaffold(
      appBar: AppBar(title: const Text('Before you start')),
      body: quizAsync.when(
        loading: () => const LoadingView(),
        error: (e, __) => ErrorView.from(e, onRetry: () => ref.invalidate(quizDetailProvider(quizId))),
        data: (quiz) => _InstructionsBody(quiz: quiz),
      ),
    );
  }
}

class _InstructionsBody extends StatelessWidget {
  const _InstructionsBody({required this.quiz});
  final Quiz quiz;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rules = [
      'You have ${quiz.duration} minute${quiz.duration == 1 ? '' : 's'}. The timer starts as soon as you tap Start.',
      'Move between questions freely and change answers until you submit.',
      'When time runs out, your answers are submitted automatically.',
      'Unanswered questions are marked incorrect.',
    ];

    return SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(quiz.title, style: theme.textTheme.displayMedium),
                if (quiz.creator != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text('by ${quiz.creator!.name}', style: theme.textTheme.bodySmall),
                ],
                const SizedBox(height: AppSpacing.sm),
                Text(quiz.description, style: theme.textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: _MetaTile(
                        icon: Icons.help_outline_rounded,
                        value: '${quiz.stats.totalQuestions}',
                        label: 'Questions',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _MetaTile(
                        icon: Icons.timer_outlined,
                        value: '${quiz.duration}',
                        label: 'Minutes',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _MetaTile(
                        icon: Icons.speed_rounded,
                        value: quiz.difficulty.label,
                        label: 'Difficulty',
                        color: quiz.difficulty.dotColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('How it works', style: theme.textTheme.labelLarge),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  child: Column(
                    children: [
                      for (final (i, rule) in rules.indexed)
                        Padding(
                          padding: EdgeInsets.only(bottom: i == rules.length - 1 ? 0 : AppSpacing.sm + 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.check_circle_outline_rounded,
                                  size: 18, color: AppColors.accentIndigo),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(child: Text(rule, style: theme.textTheme.bodyMedium)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!quiz.hasQuestions) ...[
                  const FormErrorBanner(
                    message: "This quiz doesn't have any questions yet, so it can't be started.",
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                AppButton(
                  label: 'Start quiz',
                  icon: Icons.play_arrow_rounded,
                  onPressed: quiz.hasQuestions
                      ? () => context.pushReplacement(AppRoutes.takeQuiz(quiz.id))
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaTile extends StatelessWidget {
  const _MetaTile({required this.icon, required this.value, required this.label, this.color});
  final IconData icon;
  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = color ?? AppColors.accentIndigo;
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: AppRadii.smRadius,
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(value, style: theme.textTheme.labelLarge?.copyWith(fontSize: 16), maxLines: 1),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
