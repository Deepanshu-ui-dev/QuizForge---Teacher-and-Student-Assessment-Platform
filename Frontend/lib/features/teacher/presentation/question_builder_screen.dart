import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/models/question.dart';
import '../../../core/providers/quiz_data_providers.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/confirm_bottom_sheet.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/form_error_banner.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/question_card.dart';

const _keys = ['A', 'B', 'C', 'D'];

class QuestionBuilderScreen extends ConsumerWidget {
  const QuestionBuilderScreen({super.key, required this.quizId});
  final int quizId;

  Future<void> _openEditor(BuildContext context, {Question? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _QuestionEditorSheet(quizId: quizId, existing: existing),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(existing == null ? 'Question added' : 'Question updated')),
      );
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Question question) async {
    final confirmed = await showConfirmBottomSheet(
      context,
      title: 'Delete question?',
      message: 'This cannot be undone. Questions that students have already answered cannot be deleted.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    try {
      await ref.read(questionRepositoryProvider).deleteQuestion(question.id);
      invalidateQuizData(ref, quizId: quizId);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(FailureMapper.fromException(e).message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questionsAsync = ref.watch(questionsByQuizProvider(quizId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Questions')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add question'),
      ),
      body: questionsAsync.when(
        skipLoadingOnRefresh: true,
        loading: () => const LoadingView(lines: 4),
        error: (e, __) => ErrorView.from(e, onRetry: () => ref.invalidate(questionsByQuizProvider(quizId))),
        data: (questions) {
          if (questions.isEmpty) {
            return EmptyView(
              icon: Icons.quiz_outlined,
              title: 'No questions yet',
              message: 'Add multiple-choice questions with four options and one correct answer.',
              actionLabel: 'Add first question',
              onAction: () => _openEditor(context),
            );
          }
          final totalMarks = questions.fold<int>(0, (s, q) => s + q.marks);
          return ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 96),
            children: [
              Text(
                '${questions.length} question${questions.length == 1 ? '' : 's'} · $totalMarks marks total',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              for (final (i, q) in questions.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: QuestionCard(
                    question: q,
                    index: i + 1,
                    onEdit: () => _openEditor(context, existing: q),
                    onDelete: () => _delete(context, ref, q),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Add/edit form. Pops `true` once saved.
class _QuestionEditorSheet extends ConsumerStatefulWidget {
  const _QuestionEditorSheet({required this.quizId, this.existing});
  final int quizId;
  final Question? existing;

  @override
  ConsumerState<_QuestionEditorSheet> createState() => _QuestionEditorSheetState();
}

class _QuestionEditorSheetState extends ConsumerState<_QuestionEditorSheet> {
  late final _question = TextEditingController(text: widget.existing?.text);
  late final _options = {
    for (final k in _keys) k: TextEditingController(text: widget.existing?.options.forKey(k)),
  };
  late final _marks = TextEditingController(text: '${widget.existing?.marks ?? 1}');
  late String _correct = widget.existing?.correctAnswer ?? 'A';

  bool _saving = false;
  String? _formError;
  String? _questionError;
  final Map<String, String?> _optionErrors = {};
  String? _marksError;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _question.dispose();
    for (final c in _options.values) {
      c.dispose();
    }
    _marks.dispose();
    super.dispose();
  }

  bool _validate() {
    setState(() {
      _questionError = Validators.minLength(_question.text, 3, 'Question');
      for (final k in _keys) {
        _optionErrors[k] = _options[k]!.text.trim().isEmpty ? 'Option $k is required' : null;
      }
      _marksError = Validators.positiveInt(_marks.text, 'Marks', max: 100);
      final texts = _options.values.map((c) => c.text.trim().toLowerCase()).where((t) => t.isNotEmpty);
      _formError = texts.toSet().length < texts.length ? 'Each option should be different.' : null;
    });
    return _questionError == null &&
        _optionErrors.values.every((e) => e == null) &&
        _marksError == null &&
        _formError == null;
  }

  Future<void> _save() async {
    if (_saving || !_validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(questionRepositoryProvider);
    final text = _question.text.trim();
    final opts = {for (final k in _keys) k: _options[k]!.text.trim()};
    final marks = int.parse(_marks.text.trim());
    try {
      if (_isEdit) {
        await repo.updateQuestion(
          id: widget.existing!.id,
          question: text,
          optionA: opts['A'],
          optionB: opts['B'],
          optionC: opts['C'],
          optionD: opts['D'],
          correctAnswer: _correct,
          marks: marks,
        );
      } else {
        await repo.createQuestion(
          quizId: widget.quizId,
          question: text,
          optionA: opts['A']!,
          optionB: opts['B']!,
          optionC: opts['C']!,
          optionD: opts['D']!,
          correctAnswer: _correct,
          marks: marks,
        );
      }
      invalidateQuizData(ref, quizId: widget.quizId);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _formError = FailureMapper.fromException(e).message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        children: [
          Text(_isEdit ? 'Edit question' : 'New question', style: theme.textTheme.displaySmall),
          const SizedBox(height: AppSpacing.md),
          if (_formError != null) ...[
            FormErrorBanner(message: _formError!),
            const SizedBox(height: AppSpacing.md),
          ],
          AppTextField(
            label: 'Question',
            controller: _question,
            errorText: _questionError,
            maxLines: 4,
            minLines: 2,
            autofocus: !_isEdit,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Options', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          Text('Tap the circle to mark the correct answer.', style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          for (final k in _keys)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: IconButton(
                      tooltip: 'Mark option $k as correct',
                      isSelected: _correct == k,
                      selectedIcon: Icon(Icons.check_circle_rounded, color: theme.colorScheme.secondary),
                      icon: const Icon(Icons.radio_button_unchecked_rounded),
                      onPressed: () => setState(() => _correct = k),
                    ),
                  ),
                  Expanded(
                    child: AppTextField(
                      label: 'Option $k',
                      showLabel: false,
                      controller: _options[k],
                      errorText: _optionErrors[k],
                      textInputAction: k == 'D' ? TextInputAction.done : TextInputAction.next,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.lg),
                  child: Text(
                    'Correct answer: $_correct',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              SizedBox(
                width: 96,
                child: AppTextField(
                  label: 'Marks',
                  controller: _marks,
                  errorText: _marksError,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: _isEdit ? 'Save changes' : 'Add question',
            isLoading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
