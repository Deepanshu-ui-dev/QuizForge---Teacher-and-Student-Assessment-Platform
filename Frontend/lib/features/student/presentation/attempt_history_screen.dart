import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/result_tile.dart';
import '../providers/student_result_providers.dart';
import 'student_shell.dart';

class AttemptHistoryScreen extends ConsumerWidget {
  const AttemptHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(myResultsProvider);

    Future<void> refresh() async {
      ref.invalidate(myResultsProvider);
      try {
        await ref.read(myResultsProvider.future);
      } catch (_) {}
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Attempt history'), automaticallyImplyLeading: false),
      body: resultsAsync.when(
        loading: () => const LoadingView(lines: 5),
        error: (e, __) => ErrorView.from(e, onRetry: () => ref.invalidate(myResultsProvider)),
        data: (results) {
          if (results.isEmpty) {
            return EmptyView(
              icon: Icons.history_rounded,
              title: 'No attempts yet',
              message: 'Take your first quiz and your scores will appear here.',
              actionLabel: 'Find a quiz',
              onAction: () => ref.read(studentTabProvider.notifier).state = StudentTabs.join,
            );
          }
          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl),
              itemCount: results.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) {
                final r = results[i];
                return ResultTile(
                  result: r,
                  onTap: () => context.push(AppRoutes.studentResult(r.id), extra: r),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
