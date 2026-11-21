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
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/confirm_bottom_sheet.dart';
import '../../../shared/widgets/form_error_banner.dart';
import '../../../shared/widgets/segmented_control.dart';

const _durationPresets = [5, 10, 15, 30, 45, 60];
const _maxDuration = 300;

class CreateEditQuizScreen extends ConsumerStatefulWidget {
  const CreateEditQuizScreen({super.key, this.existingQuiz});
  final Quiz? existingQuiz;

  @override
  ConsumerState<CreateEditQuizScreen> createState() => _CreateEditQuizScreenState();
}

class _CreateEditQuizScreenState extends ConsumerState<CreateEditQuizScreen> {
  late final _title = TextEditingController(text: widget.existingQuiz?.title);
  late final _description = TextEditingController(text: widget.existingQuiz?.description);
  late final _duration =
      TextEditingController(text: (widget.existingQuiz?.duration ?? 15).toString());
  late QuizDifficulty _difficulty = widget.existingQuiz?.difficulty ?? QuizDifficulty.medium;

  bool _isSaving = false;
  bool _attempted = false;
  Failure? _failure;
  String? _titleError;
  String? _descError;
  String? _durationError;

  bool get isEdit => widget.existingQuiz != null;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _duration.dispose();
    super.dispose();
  }

  bool get _isDirty {
    final q = widget.existingQuiz;
    return _title.text.trim() != (q?.title ?? '') ||
        _description.text.trim() != (q?.description ?? '') ||
        _duration.text.trim() != (q?.duration ?? 15).toString() ||
        _difficulty != (q?.difficulty ?? QuizDifficulty.medium);
  }

  bool _validate() {
    setState(() {
      _titleError = Validators.minLength(_title.text, 3, 'Title');
      _descError = Validators.minLength(_description.text, 10, 'Description');
      _durationError = Validators.positiveInt(_duration.text, 'Duration', max: _maxDuration);
    });
    return _titleError == null && _descError == null && _durationError == null;
  }

  void _revalidate([String? _]) {
    if (_attempted) _validate();
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    _attempted = true;
    if (!_validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final repo = ref.read(quizRepositoryProvider);
    final duration = int.parse(_duration.text.trim());
    try {
      if (isEdit) {
        final id = widget.existingQuiz!.id;
        await repo.updateQuiz(
          id: id,
          title: _title.text.trim(),
          description: _description.text.trim(),
          duration: duration,
          difficulty: _difficulty,
        );
        invalidateQuizData(ref, quizId: id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quiz updated')));
        context.pop();
      } else {
        final quiz = await repo.createQuiz(
          title: _title.text.trim(),
          description: _description.text.trim(),
          duration: duration,
          difficulty: _difficulty,
        );
        invalidateQuizData(ref);
        if (!mounted) return;
        // Next step for a new quiz is always adding questions.
        context.pushReplacement(AppRoutes.quizDetail(quiz.id));
        context.push(AppRoutes.quizQuestions(quiz.id));
      }
    } catch (e) {
      if (mounted) setState(() => _failure = FailureMapper.fromException(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _maybeLeave() async {
    final leave = await showConfirmBottomSheet(
      context,
      title: 'Discard changes?',
      message: "You have unsaved changes that will be lost.",
      confirmLabel: 'Discard',
      cancelLabel: 'Keep editing',
    );
    // Navigator.pop bypasses this screen's PopScope; the user already confirmed.
    if (leave && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentDuration = int.tryParse(_duration.text.trim());

    return PopScope(
      canPop: _isSaving || !_isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _maybeLeave();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(isEdit ? 'Edit quiz' : 'New quiz')),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    if (_failure != null) ...[
                      FormErrorBanner(message: _failure!.message),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    AppCard(
                      child: Column(
                        children: [
                          AppTextField(
                            label: 'Title',
                            hintText: 'e.g. Photosynthesis basics',
                            controller: _title,
                            errorText: _titleError,
                            maxLength: 100,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.next,
                            onChanged: (v) => setState(() => _revalidate(v)),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          AppTextField(
                            label: 'Description',
                            hintText: 'What does this quiz cover?',
                            controller: _description,
                            errorText: _descError,
                            maxLines: 4,
                            minLines: 2,
                            textCapitalization: TextCapitalization.sentences,
                            onChanged: (v) => setState(() => _revalidate(v)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppTextField(
                            label: 'Time limit (minutes)',
                            controller: _duration,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3),
                            ],
                            errorText: _durationError,
                            prefixIcon: Icons.timer_outlined,
                            onChanged: (v) => setState(() => _revalidate(v)),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.xs,
                            children: [
                              for (final m in _durationPresets)
                                ChoiceChip(
                                  label: Text('$m min'),
                                  selected: currentDuration == m,
                                  onSelected: (_) => setState(() {
                                    _duration.text = '$m';
                                    _revalidate();
                                  }),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text('Difficulty', style: theme.textTheme.labelLarge),
                          const SizedBox(height: AppSpacing.xs),
                          SegmentedControl<QuizDifficulty>(
                            options: QuizDifficulty.values,
                            labels: [for (final d in QuizDifficulty.values) d.label],
                            selected: _difficulty,
                            onChanged: (v) => setState(() => _difficulty = v),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
                child: AppButton(
                  label: isEdit ? 'Save changes' : 'Create & add questions',
                  isLoading: _isSaving,
                  onPressed: isEdit && !_isDirty ? null : _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
