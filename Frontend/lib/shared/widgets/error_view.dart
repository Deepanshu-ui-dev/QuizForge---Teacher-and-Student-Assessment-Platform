import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/errors/failure.dart';
import '../../core/errors/failure_mapper.dart';
import 'app_button.dart';

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.failure, this.onRetry});

  /// Convenience for `AsyncValue.when(error: ...)` callbacks.
  ErrorView.from(Object error, {super.key, this.onRetry})
      : failure = FailureMapper.fromException(error);

  final Failure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (IconData icon, String title) = switch (failure) {
      NetworkFailure() => (Icons.wifi_off_rounded, "You're offline"),
      UnauthorizedFailure() => (Icons.lock_outline_rounded, 'Session expired'),
      BackendNotImplementedFailure() => (Icons.hourglass_empty_rounded, 'Coming soon'),
      ServerFailure(statusCode: 404) => (Icons.search_off_rounded, 'Not found'),
      _ => (Icons.error_outline_rounded, 'Something went wrong'),
    };
    final canRetry = onRetry != null && failure is! BackendNotImplementedFailure;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: AppColors.error),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: theme.textTheme.displaySmall, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                failure.message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodySmall?.color),
              ),
            ),
            if (canRetry) ...[
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Try again',
                onPressed: onRetry,
                fullWidth: false,
                variant: AppButtonVariant.outlined,
                icon: Icons.refresh_rounded,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
