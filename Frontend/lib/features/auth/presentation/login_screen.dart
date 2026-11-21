import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/failure.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/auth_scaffold.dart';
import '../../../shared/widgets/form_error_banner.dart';
import '../providers/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _emailError;
  String? _passwordError;
  Failure? _failure;
  bool _submitting = false;
  bool _attempted = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _validate() {
    setState(() {
      _emailError = Validators.email(_email.text);
      _passwordError = _password.text.isEmpty ? 'Enter your password' : null;
    });
    return _emailError == null && _passwordError == null;
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
      await ref.read(authServiceProvider).login(
            email: _email.text.trim(),
            password: _password.text,
          );
    } on Failure catch (f) {
      if (mounted) setState(() => _failure = f);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _revalidate(String _) {
    if (_attempted) _validate();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Log in to continue to QuizForge',
      onBack: () => context.canPop() ? context.pop() : context.go(AppRoutes.authChoice),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_failure != null) ...[
              FormErrorBanner(message: _failure!.message),
              const SizedBox(height: AppSpacing.md),
            ],
            AppTextField(
              label: 'Email',
              hintText: 'you@school.edu',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              errorText: _emailError,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
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
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              prefixIcon: Icons.lock_outline_rounded,
              onChanged: _revalidate,
              onSubmitted: (_) => _submit(),
              enabled: !_submitting,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(label: 'Log in', isLoading: _submitting, onPressed: _submit),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: TextButton(
                onPressed: _submitting ? null : () => context.pushReplacement(AppRoutes.register),
                child: const Text("Don't have an account? Create one"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
