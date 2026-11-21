import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/models/quiz.dart';
import '../../../core/providers/quiz_data_providers.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/difficulty_style.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/confirm_bottom_sheet.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../student/providers/student_result_providers.dart';

enum _MenuAction { edit, delete }

class QuizDetailScreen extends ConsumerStatefulWidget {
  const QuizDetailScreen({super.key, required this.quizId});
  final int quizId;

  @override
  ConsumerState<QuizDetailScreen> createState() => _QuizDetailScreenState();
}

class _QuizDetailScreenState extends ConsumerState<QuizDetailScreen> {
  bool _deleting = false;

  Future<void> _confirmDelete(Quiz quiz) async {
    final attempts = quiz.stats.totalResults;
    final confirmed = await showConfirmBottomSheet(
      context,
      title: 'Delete "${quiz.title}"?',
      message: 'This permanently deletes the quiz, its ${quiz.stats.totalQuestions} questions'
          '${attempts > 0 ? ' and $attempts student attempt${attempts == 1 ? '' : 's'}' : ''}. '
          'This cannot be undone.',
      confirmLabel: 'Delete quiz',
    );
    if (!confirmed || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ref.read(quizRepositoryProvider).deleteQuiz(widget.quizId);
      // Drop the deleted quiz from every list that may be showing it.
      ref.invalidate(quizListProvider);
      ref.invalidate(allResultsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleted "${quiz.title}"')));
      context.canPop() ? context.pop() : context.go(AppRoutes.teacherHome);
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorView.from(e).failure.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final quizAsync = ref.watch(quizDetailProvider(widget.quizId));
    final quiz = quizAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz details'),
        actions: [
          if (quiz != null && _deleting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (quiz != null)
            PopupMenuButton<_MenuAction>(
              tooltip: 'More',
              onSelected: (action) => switch (action) {
                _MenuAction.edit => context.push(AppRoutes.quizEdit(quiz.id)),
                _MenuAction.delete => _confirmDelete(quiz),
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _MenuAction.edit,
                  child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit details')),
                ),
                PopupMenuItem(
                  value: _MenuAction.delete,
                  child: ListTile(
                    leading: Icon(Icons.delete_outline_rounded, color: AppColors.error),
                    title: Text('Delete quiz', style: TextStyle(color: AppColors.error)),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: quizAsync.when(
        skipLoadingOnRefresh: true,
        loading: () => const LoadingView(),
        error: (e, __) => ErrorView.from(e, onRetry: () => ref.invalidate(quizDetailProvider(widget.quizId))),
        data: (quiz) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(quizDetailProvider(widget.quizId));
            try {
              await ref.read(quizDetailProvider(widget.quizId).future);
            } catch (_) {}
          },
          child: _DetailBody(quiz: quiz),
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.quiz});
  final Quiz quiz;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl),
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            _Pill(color: quiz.difficulty.dotColor, label: quiz.difficulty.label),
            _Pill(color: theme.colorScheme.outline, label: '${quiz.duration} min'),
            _Pill(color: theme.colorScheme.outline, label: 'Created ${formatDate(quiz.createdAt)}'),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(quiz.title, style: theme.textTheme.displayMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(quiz.description, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Questions',
                value: '${quiz.stats.totalQuestions}',
                icon: Icons.help_outline_rounded,
                deltaColor: AppColors.accentIndigo,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: StatCard(
                label: 'Attempts',
                value: '${quiz.stats.totalResults}',
                icon: Icons.people_alt_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (!quiz.hasQuestions) ...[
          AppCard(
            color: AppColors.warning.withValues(alpha: 0.08),
            borderColor: AppColors.warning.withValues(alpha: 0.4),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.warning),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    "Students can't take this quiz until you add at least one question.",
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        AppButton(
          label: quiz.hasQuestions ? 'Manage questions' : 'Add questions',
          icon: quiz.hasQuestions ? Icons.list_alt_rounded : Icons.add_rounded,
          onPressed: () => context.push(AppRoutes.quizQuestions(quiz.id)),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Results',
                variant: AppButtonVariant.outlined,
                icon: Icons.bar_chart_rounded,
                onPressed: () => context.push(AppRoutes.quizResults(quiz.id)),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppButton(
                label: 'Analytics',
                variant: AppButtonVariant.outlined,
                icon: Icons.insights_outlined,
                onPressed: () => context.push(AppRoutes.quizAnalytics(quiz.id)),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          color: AppColors.accentIndigo.withValues(alpha: 0.06),
          borderColor: AppColors.accentIndigo.withValues(alpha: 0.25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Share with students', style: theme.textTheme.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Students can enter this quiz ID on their Browse tab to open it directly.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Material(
                color: theme.colorScheme.surface,
                borderRadius: AppRadii.mdRadius,
                child: InkWell(
                  borderRadius: AppRadii.mdRadius,
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: '${quiz.id}'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Quiz ID ${quiz.id} copied')),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.md),
                    child: Row(
                      children: [
                        Text('ID', style: theme.textTheme.bodySmall),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            '${quiz.id}',
                            style: theme.textTheme.displaySmall
                                ?.copyWith(fontFamily: 'monospace', letterSpacing: 2),
                          ),
                        ),
                        const Icon(Icons.copy_rounded, size: 18),
                        const SizedBox(width: AppSpacing.xs),
                        Text('Copy', style: theme.textTheme.labelLarge),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 12)),
    );
  }
}
