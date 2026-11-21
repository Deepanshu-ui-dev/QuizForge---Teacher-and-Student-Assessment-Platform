import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/models/quiz.dart';
import '../../../core/providers/quiz_data_providers.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/quiz_card.dart';
import '../../../shared/widgets/segmented_control.dart';

/// Join by ID, or browse/search every quiz that has questions.
class JoinQuizScreen extends ConsumerStatefulWidget {
  const JoinQuizScreen({super.key, this.standalone = false});

  /// True when pushed as its own route (shows a back button); false when
  /// hosted as a tab in the student shell.
  final bool standalone;

  @override
  ConsumerState<JoinQuizScreen> createState() => _JoinQuizScreenState();
}

class _JoinQuizScreenState extends ConsumerState<JoinQuizScreen> {
  final _idController = TextEditingController();
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';
  QuizDifficulty? _difficulty;
  bool _isChecking = false;
  String? _idError;

  @override
  void dispose() {
    _debounce?.cancel();
    _idController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  Future<void> _joinById() async {
    if (_isChecking) return;
    final id = int.tryParse(_idController.text.trim());
    if (id == null || id <= 0) {
      setState(() => _idError = 'Enter the numeric quiz ID your teacher shared');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _isChecking = true;
      _idError = null;
    });
    try {
      final quiz = await ref.read(quizRepositoryProvider).getQuizById(id);
      if (!mounted) return;
      if (!quiz.hasQuestions) {
        setState(() => _idError = '"${quiz.title}" has no questions yet. Ask your teacher to add some.');
        return;
      }
      _idController.clear();
      context.push(AppRoutes.quizInstructions(id));
    } catch (e) {
      final failure = FailureMapper.fromException(e);
      if (mounted) {
        setState(() => _idError = failure is ServerFailure && failure.statusCode == 404
            ? 'No quiz found with ID $id'
            : failure.message);
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final params = QuizListParams(search: _query.isEmpty ? null : _query, difficulty: _difficulty);
    final quizzesAsync = ref.watch(quizListProvider(params));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Join a quiz'),
        automaticallyImplyLeading: widget.standalone,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(quizListProvider(params));
          try {
            await ref.read(quizListProvider(params).future);
          } catch (_) {}
        },
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Have a quiz ID?', style: theme.textTheme.displaySmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text('Enter the ID your teacher shared with you.', style: theme.textTheme.bodySmall),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AppTextField(
                          label: 'Quiz ID',
                          showLabel: false,
                          hintText: 'e.g. 42',
                          controller: _idController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          monospace: true,
                          errorText: _idError,
                          textInputAction: TextInputAction.go,
                          prefixIcon: Icons.tag_rounded,
                          onChanged: (_) {
                            if (_idError != null) setState(() => _idError = null);
                          },
                          onSubmitted: (_) => _joinById(),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      SizedBox(
                        height: 56,
                        child: AppButton(
                          label: 'Go',
                          fullWidth: false,
                          isLoading: _isChecking,
                          onPressed: _joinById,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Browse quizzes', style: theme.textTheme.displaySmall),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              label: 'Search quizzes',
              showLabel: false,
              controller: _searchController,
              prefixIcon: Icons.search_rounded,
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
              suffix: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SegmentedControl<QuizDifficulty?>(
              options: const [null, QuizDifficulty.easy, QuizDifficulty.medium, QuizDifficulty.hard],
              labels: const ['All', 'Easy', 'Medium', 'Hard'],
              selected: _difficulty,
              onChanged: (v) => setState(() => _difficulty = v),
            ),
            const SizedBox(height: AppSpacing.md),
            quizzesAsync.when(
              skipLoadingOnReload: true,
              loading: () => const LoadingView(lines: 4),
              error: (e, __) => ErrorView.from(e, onRetry: () => ref.invalidate(quizListProvider(params))),
              data: (result) {
                final quizzes = result.data.where((q) => q.hasQuestions).toList();
                if (quizzes.isEmpty) {
                  return EmptyView(
                    icon: Icons.search_off_rounded,
                    message: _query.isEmpty && _difficulty == null
                        ? 'No quizzes are available yet.'
                        : 'No quizzes match your search.',
                  );
                }
                return Column(
                  children: [
                    for (final quiz in quizzes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: QuizCard(
                          quiz: quiz,
                          onTap: () => context.push(AppRoutes.quizInstructions(quiz.id)),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
