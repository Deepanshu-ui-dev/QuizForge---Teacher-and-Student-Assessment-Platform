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
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/staggered_fade_in.dart';
import '../../../shared/widgets/stat_card.dart';
import 'teacher_shell.dart';

const myQuizzesParams = QuizListParams(mine: true);

class TeacherDashboardScreen extends ConsumerWidget {
  const TeacherDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstName = ref.watch(sessionProvider.select((s) => s.valueOrNull?.firstName ?? ''));
    final quizzesAsync = ref.watch(quizListProvider(myQuizzesParams));

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(quizListProvider);
          try {
            await ref.read(quizListProvider(myQuizzesParams).future);
          } catch (_) {}
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [
            HeroHeader(
              title: firstName.isEmpty ? 'Welcome back' : 'Hi, $firstName 👋',
              subtitle: "Here's how your quizzes are doing.",
              trailing: AppButton(
                label: 'New',
                icon: Icons.add_rounded,
                fullWidth: false,
                onPressed: () => context.push(AppRoutes.createQuiz),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: quizzesAsync.when(
                loading: () => const SizedBox(height: 112, child: LoadingView(lines: 1)),
                error: (_, __) => const SizedBox.shrink(),
                data: (result) {
                  final totalQuestions = result.data.fold<int>(0, (s, q) => s + q.stats.totalQuestions);
                  final totalAttempts = result.data.fold<int>(0, (s, q) => s + q.stats.totalResults);
                  return Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          label: 'Quizzes',
                          value: '${result.pagination.total}',
                          icon: Icons.menu_book_rounded,
                          deltaColor: AppColors.accentIndigo,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: StatCard(
                          label: 'Questions',
                          value: '$totalQuestions',
                          icon: Icons.help_outline_rounded,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: StatCard(
                          label: 'Attempts',
                          value: '$totalAttempts',
                          icon: Icons.people_alt_outlined,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionHeader(
              title: 'Your quizzes',
              actionLabel: 'See all',
              onAction: () => ref.read(teacherTabProvider.notifier).state = TeacherTabs.quizzes,
            ),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: quizzesAsync.when(
                loading: () => const LoadingView(lines: 3),
                error: (e, __) => ErrorView.from(e, onRetry: () => ref.invalidate(quizListProvider)),
                data: (result) {
                  if (result.data.isEmpty) {
                    return EmptyView(
                      icon: Icons.auto_awesome_outlined,
                      title: 'Create your first quiz',
                      message: 'Set a title and duration, then add multiple-choice questions.',
                      actionLabel: 'Create quiz',
                      onAction: () => context.push(AppRoutes.createQuiz),
                    );
                  }
                  return Column(
                    children: [
                      for (final (i, quiz) in result.data.take(5).indexed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: StaggeredFadeIn(
                            index: i,
                            child: QuizCard(
                              quiz: quiz,
                              showTeacherMeta: true,
                              onTap: () => context.push(AppRoutes.quizDetail(quiz.id)),
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
