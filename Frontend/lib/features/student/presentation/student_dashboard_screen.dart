import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/providers/quiz_data_providers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/hero_header.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/quiz_card.dart';
import '../../../shared/widgets/result_tile.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/staggered_fade_in.dart';
import '../../../shared/widgets/stat_card.dart';
import '../providers/student_result_providers.dart';
import 'student_shell.dart';

class StudentDashboardScreen extends ConsumerWidget {
  const StudentDashboardScreen({super.key});

  static const _maxQuizzes = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstName = ref.watch(sessionProvider.select((s) => s.valueOrNull?.firstName ?? ''));
    final quizzesAsync = ref.watch(quizListProvider(const QuizListParams()));
    final myResultsAsync = ref.watch(myResultsProvider);
    final statsAsync = ref.watch(myStatsProvider);

    void goToTab(int tab) => ref.read(studentTabProvider.notifier).state = tab;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(quizListProvider);
          ref.invalidate(myResultsProvider);
          ref.invalidate(myStatsProvider);
          try {
            await ref.read(myResultsProvider.future);
          } catch (_) {}
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [
            HeroHeader(
              title: firstName.isEmpty ? 'Welcome back' : 'Hi, $firstName 👋',
              subtitle: 'Ready to take on a new quiz?',
              trailing: AppButton(
                label: 'Join',
                icon: Icons.login_rounded,
                fullWidth: false,
                onPressed: () => goToTab(StudentTabs.join),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: statsAsync.when(
                loading: () => const SizedBox(height: 112, child: LoadingView(lines: 1)),
                error: (_, __) => const SizedBox.shrink(),
                data: (stats) => Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        label: 'Attempts',
                        value: '${stats.totalAttempts}',
                        icon: Icons.assignment_turned_in_outlined,
                        deltaColor: AppColors.accentIndigo,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: StatCard(
                        label: 'Average',
                        value: stats.totalAttempts == 0
                            ? '—'
                            : '${stats.averagePercentage.round()}%',
                        icon: Icons.percent_rounded,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: StatCard(
                        label: 'Best',
                        value: stats.totalAttempts == 0
                            ? '—'
                            : '${stats.highestPercentage.round()}%',
                        icon: Icons.emoji_events_outlined,
                        deltaColor: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionHeader(
              title: 'Recent attempts',
              actionLabel: 'See all',
              onAction: myResultsAsync.valueOrNull?.isNotEmpty == true
                  ? () => goToTab(StudentTabs.history)
                  : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: myResultsAsync.when(
                loading: () => const LoadingView(lines: 2),
                error: (e, __) => ErrorView.from(e, onRetry: () => ref.invalidate(myResultsProvider)),
                data: (results) {
                  if (results.isEmpty) {
                    return const EmptyView(
                      compact: true,
                      icon: Icons.history_rounded,
                      message: 'Your quiz attempts and scores will show up here.',
                    );
                  }
                  return Column(
                    children: [
                      for (final (i, r) in results.take(3).indexed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: StaggeredFadeIn(
                            index: i,
                            child: ResultTile(
                              result: r,
                              onTap: () => context.push(AppRoutes.studentResult(r.id), extra: r),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SectionHeader(
              title: 'Available quizzes',
              actionLabel: 'Browse all',
              onAction: () => goToTab(StudentTabs.join),
            ),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: quizzesAsync.when(
                loading: () => const LoadingView(lines: 3),
                error: (e, __) => ErrorView.from(e, onRetry: () => ref.invalidate(quizListProvider)),
                data: (result) {
                  // Quizzes without questions can't be attempted; hide them.
                  final quizzes = result.data.where((q) => q.hasQuestions).take(_maxQuizzes).toList();
                  if (quizzes.isEmpty) {
                    return const EmptyView(
                      compact: true,
                      icon: Icons.menu_book_outlined,
                      message: 'No quizzes are available yet. Check back soon!',
                    );
                  }
                  return Column(
                    children: [
                      for (final (i, quiz) in quizzes.indexed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: StaggeredFadeIn(
                            index: i,
                            child: QuizCard(
                              quiz: quiz,
                              onTap: () => context.push(AppRoutes.quizInstructions(quiz.id)),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
