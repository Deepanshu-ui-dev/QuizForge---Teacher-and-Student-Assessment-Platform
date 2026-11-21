import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radii.dart';
import '../../app/theme/app_spacing.dart';

/// Green ≥ 75 %, amber ≥ 50 %, red below.
Color scoreColor(double percentage, {required bool isDark}) {
  if (percentage >= 75) return isDark ? AppColors.successDark : AppColors.success;
  if (percentage >= 50) return isDark ? AppColors.warningDark : AppColors.warning;
  return isDark ? AppColors.errorDark : AppColors.error;
}

class PercentageBadge extends StatelessWidget {
  const PercentageBadge({super.key, required this.percentage});
  final double percentage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = scoreColor(percentage, isDark: theme.brightness == Brightness.dark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadii.smRadius,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '${percentage.round()}%',
        style: theme.textTheme.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
