import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/models/result.dart';
import '../../../core/providers/quiz_data_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/percentage_badge.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../student/providers/student_result_providers.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key, required this.quizId});
  final int quizId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(quizResultsProvider(quizId));
    final quizTitle = ref.watch(quizDetailProvider(quizId)).valueOrNull?.title;

    return Scaffold(
      appBar: AppBar(title: Text(quizTitle == null ? 'Analytics' : 'Analytics · $quizTitle')),
      body: resultsAsync.when(
        loading: () => const LoadingView(lines: 4),
        error: (e, __) => ErrorView.from(e, onRetry: () => ref.invalidate(quizResultsProvider(quizId))),
        data: (results) {
          if (results.isEmpty) {
            return const EmptyView(
              icon: Icons.insights_outlined,
              title: 'No data yet',
              message: 'Analytics appear once students start submitting this quiz.',
            );
          }
          return _AnalyticsBody(results: results);
        },
      ),
    );
  }
}

class _AnalyticsBody extends StatelessWidget {
  const _AnalyticsBody({required this.results});
  final List<QuizResult> results;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = results.length;
    final scores = results.map((r) => r.percentage).toList();
    final average = scores.reduce((a, b) => a + b) / count;
    final highest = scores.reduce((a, b) => a > b ? a : b);
    final lowest = scores.reduce((a, b) => a < b ? a : b);
    final passed = scores.where((s) => s >= 50).length;
    final uniqueStudents = results.map((r) => r.studentEmail ?? r.studentName).toSet().length;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Attempts · $uniqueStudents student${uniqueStudents == 1 ? '' : 's'}',
                value: '$count',
                icon: Icons.people_alt_outlined,
                deltaColor: AppColors.accentIndigo,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: StatCard(
                label: 'Average score',
                value: '${average.round()}%',
                icon: Icons.percent_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Highest / lowest',
                value: '${highest.round()}% / ${lowest.round()}%',
                icon: Icons.unfold_more_rounded,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: StatCard(
                label: 'Pass rate (≥ 50%)',
                value: '${(passed / count * 100).round()}%',
                icon: Icons.check_circle_outline_rounded,
                deltaColor: AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Score distribution', style: theme.textTheme.displaySmall),
        const SizedBox(height: AppSpacing.sm),
        _DistributionCard(scores: scores),
      ],
    );
  }
}

/// Horizontal bars for three score bands. Each bar is labelled with its
/// range and count, so colour is never the only cue.
class _DistributionCard extends StatelessWidget {
  const _DistributionCard({required this.scores});
  final List<double> scores;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bands = [
      ('75–100%', 'Strong', scores.where((s) => s >= 75).length, 90.0),
      ('50–74%', 'Passing', scores.where((s) => s >= 50 && s < 75).length, 60.0),
      ('0–49%', 'Below pass', scores.where((s) => s < 50).length, 10.0),
    ];
    final maxCount = bands.map((b) => b.$3).reduce((a, b) => a > b ? a : b);

    return AppCard(
      child: Column(
        children: [
          for (final (range, name, n, sample) in bands)
            Semantics(
              label: '$name, $range: $n attempt${n == 1 ? '' : 's'}',
              excludeSemantics: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    SizedBox(
                      width: 92,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: theme.textTheme.labelLarge),
                          Text(range, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final fraction = maxCount == 0 ? 0.0 : n / maxCount;
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: fraction),
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeOutCubic,
                              builder: (context, v, _) => Container(
                                height: 14,
                                width: n == 0 ? 2 : (c.maxWidth * v).clamp(4.0, c.maxWidth),
                                decoration: BoxDecoration(
                                  color: scoreColor(sample, isDark: isDark),
                                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    SizedBox(
                      width: 28,
                      child: Text('$n', textAlign: TextAlign.end, style: theme.textTheme.labelLarge),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
