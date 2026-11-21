import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/app_spacing.dart';
import 'empty_view.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: EmptyView(
          icon: Icons.explore_off_outlined,
          title: 'Page not found',
          message: "This link doesn't point to anything in QuizForge.",
          actionLabel: 'Go home',
          onAction: () => context.go('/'),
        ),
      ),
    );
  }
}
