import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/failure.dart';
import '../../../core/utils/app_role.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/auth_scaffold.dart';
import '../../../shared/widgets/form_error_banner.dart';
import '../../../shared/widgets/segmented_control.dart';
import '../providers/auth_providers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, this.initialRole = AppRole.student});
  final AppRole initialRole;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late AppRole _role = widget.initialRole;

  String? _nameError;
  String? _emailError;
  String? _passwordError;
  Failure? _failure;
  bool _submitting = false;
  bool _attempted = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _validate() {
    setState(() {
      _nameError = Validators.minLength(_name.text, 3, 'Name');
      _emailError = Validators.email(_email.text);
      _passwordError = _password.text.length < 8 ? 'Password must be at least 8 characters' : null;
    });
    return _nameError == null && _emailError == null && _passwordError == null;
  }

  void _revalidate(String _) {
    if (_attempted) _validate();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    _attempted = true;
    if (!_validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _failure = null;
    });
    try {
      // On success the router redirects to the role's home automatically.
      await ref.read(authServiceProvider).registerAndLogin(
            name: _name.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
            role: _role.backendRole,
          );
    } on Failure catch (f) {
      if (mounted) setState(() => _failure = f);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AuthScaffold(
      title: 'Create account',
      subtitle: 'Join as a student or a teacher',
      onBack: () => context.canPop() ? context.pop() : context.go(AppRoutes.authChoice),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_failure != null) ...[
              FormErrorBanner(message: _failure!.message),
              const SizedBox(height: AppSpacing.md),
            ],
            Text("I'm a", style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            SegmentedControl<AppRole>(
              options: const [AppRole.student, AppRole.teacher],
              labels: const ['Student', 'Teacher'],
              selected: _role,
              onChanged: (r) => setState(() => _role = r),
            ),
            const SizedBox(height: AppSpacing.xs),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Text(
                _role == AppRole.teacher
                    ? 'Create quizzes, add questions and track student results.'
                    : 'Join quizzes, get instant scores and track your progress.',
                key: ValueKey(_role),
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Full name',
              controller: _name,
              errorText: _nameError,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              prefixIcon: Icons.person_outline_rounded,
              onChanged: _revalidate,
              enabled: !_submitting,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Email',
              hintText: 'you@school.edu',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              errorText: _emailError,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              prefixIcon: Icons.mail_outline_rounded,
              onChanged: _revalidate,
              enabled: !_submitting,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Password',
              controller: _password,
              obscureText: true,
              errorText: _passwordError,
              helperText: _passwordError == null ? 'At least 8 characters' : null,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              prefixIcon: Icons.lock_outline_rounded,
              onChanged: _revalidate,
              onSubmitted: (_) => _submit(),
              enabled: !_submitting,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(label: 'Create account', isLoading: _submitting, onPressed: _submit),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: TextButton(
                onPressed: _submitting ? null : () => context.pushReplacement(AppRoutes.login),
                child: const Text('Already have an account? Log in'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
