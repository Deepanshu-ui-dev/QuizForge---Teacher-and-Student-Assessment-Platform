import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/models/result.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/result_tile.dart';
import '../../student/providers/student_result_providers.dart';

/// All attempts across quizzes (Results tab), or one quiz's attempts.
class AttemptsResultsScreen extends ConsumerWidget {
  const AttemptsResultsScreen({super.key, this.quizId});
  final int? quizId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ProviderListenable<AsyncValue<List<QuizResult>>> provider =
        quizId != null ? quizResultsProvider(quizId!) : allResultsProvider;
    final resultsAsync = ref.watch(provider);

    void invalidate() =>
        quizId != null ? ref.invalidate(quizResultsProvider(quizId!)) : ref.invalidate(allResultsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(quizId != null ? 'Quiz attempts' : 'Student results'),
        automaticallyImplyLeading: quizId != null,
      ),
      body: resultsAsync.when(
        loading: () => const LoadingView(lines: 5),
        error: (e, __) => ErrorView.from(e, onRetry: invalidate),
        data: (results) {
          if (results.isEmpty) {
            return const EmptyView(
              icon: Icons.bar_chart_outlined,
              title: 'No attempts yet',
              message: 'When students submit a quiz, their scores will appear here.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => invalidate(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl),
              itemCount: results.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) {
                final r = results[i];
                return ResultTile(
                  result: r,
                  showStudent: quizId != null,
                  showQuizAndStudent: quizId == null,
                  onTap: () => context.push(AppRoutes.teacherResult(r.id), extra: r),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
