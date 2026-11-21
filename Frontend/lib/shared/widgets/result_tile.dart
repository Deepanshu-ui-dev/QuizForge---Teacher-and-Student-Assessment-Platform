import 'package:flutter/material.dart';
import '../../app/theme/app_radii.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/models/result.dart';
import '../../core/utils/date_format.dart';
import 'app_card.dart';
import 'percentage_badge.dart';

/// A row summarising one attempt. Shows the quiz title by default, or the
/// student when [showStudent] is set (teacher views of a single quiz).
class ResultTile extends StatelessWidget {
  const ResultTile({
    super.key,
    required this.result,
    this.onTap,
    this.showStudent = false,
    this.showQuizAndStudent = false,
  });

  final QuizResult result;
  final VoidCallback? onTap;
  final bool showStudent;
  final bool showQuizAndStudent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = scoreColor(result.percentage, isDark: theme.brightness == Brightness.dark);
    final quizTitle = result.quizTitle ?? 'Quiz #${result.quizId}';
    final student = result.studentName ?? result.studentEmail ?? 'Student';

    final title = showStudent ? student : quizTitle;
    final details = <String>[
      if (showQuizAndStudent) student,
      '${result.score}/${result.totalMarks} marks',
      formatRelativeDate(result.submittedAt),
    ].join(' · ');

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + 4),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppRadii.mdRadius,
            ),
            child: showStudent
                ? Text(
                    student.isNotEmpty ? student[0].toUpperCase() : '?',
                    style: theme.textTheme.labelLarge?.copyWith(color: color, fontSize: 16),
                  )
                : Icon(Icons.assignment_turned_in_outlined, size: 20, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(details, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          PercentageBadge(percentage: result.percentage),
          if (onTap != null) ...[
            const SizedBox(width: AppSpacing.xs),
            Icon(Icons.chevron_right_rounded, color: theme.colorScheme.outline),
          ],
        ],
      ),
    );
  }
}
