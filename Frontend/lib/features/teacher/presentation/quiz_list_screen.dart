import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/models/quiz.dart';
import '../../../core/providers/quiz_data_providers.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/quiz_card.dart';
import '../../../shared/widgets/segmented_control.dart';

class QuizListScreen extends ConsumerStatefulWidget {
  const QuizListScreen({super.key});

  @override
  ConsumerState<QuizListScreen> createState() => _QuizListScreenState();
}

class _QuizListScreenState extends ConsumerState<QuizListScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  QuizDifficulty? _difficulty;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    // Debounced so typing doesn't fire one request per keystroke.
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final params = QuizListParams(
      search: _query.isEmpty ? null : _query,
      difficulty: _difficulty,
      mine: true,
    );
    final quizzesAsync = ref.watch(quizListProvider(params));
    final filtering = _query.isNotEmpty || _difficulty != null;

    return Scaffold(
      appBar: AppBar(title: const Text('My quizzes'), automaticallyImplyLeading: false),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.createQuiz),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New quiz'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
            child: AppTextField(
              label: 'Search your quizzes',
              showLabel: false,
              controller: _search,
              prefixIcon: Icons.search_rounded,
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: SegmentedControl<QuizDifficulty?>(
              options: const [null, QuizDifficulty.easy, QuizDifficulty.medium, QuizDifficulty.hard],
              labels: const ['All', 'Easy', 'Medium', 'Hard'],
              selected: _difficulty,
              onChanged: (v) => setState(() => _difficulty = v),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: quizzesAsync.when(
              loading: () => const LoadingView(lines: 5),
              error: (e, __) => ErrorView.from(e, onRetry: () => ref.invalidate(quizListProvider(params))),
              data: (result) {
                if (result.data.isEmpty) {
                  return filtering
                      ? const EmptyView(
                          icon: Icons.search_off_rounded,
                          message: 'No quizzes match your filters.',
                        )
                      : EmptyView(
                          icon: Icons.menu_book_outlined,
                          title: 'No quizzes yet',
                          message: 'Quizzes you create will appear here.',
                          actionLabel: 'Create quiz',
                          onAction: () => context.push(AppRoutes.createQuiz),
                        );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(quizListProvider(params));
                    try {
                      await ref.read(quizListProvider(params).future);
                    } catch (_) {}
                  },
                  child: ListView.separated(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    // Bottom padding keeps the last card clear of the FAB.
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 96),
                    itemCount: result.data.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) {
                      final quiz = result.data[i];
                      return QuizCard(
                        quiz: quiz,
                        showTeacherMeta: true,
                        onTap: () => context.push(AppRoutes.quizDetail(quiz.id)),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
