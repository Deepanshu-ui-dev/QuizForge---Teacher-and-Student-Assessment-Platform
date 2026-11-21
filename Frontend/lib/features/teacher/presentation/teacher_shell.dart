import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/app_nav_bar.dart';
import '../../profile/presentation/profile_screen.dart';
import 'attempts_results_screen.dart';
import 'quiz_list_screen.dart';
import 'teacher_dashboard_screen.dart';

final teacherTabProvider = StateProvider.autoDispose<int>((ref) => 0);

class TeacherTabs {
  static const home = 0;
  static const quizzes = 1;
  static const results = 2;
  static const profile = 3;
}

class TeacherShell extends ConsumerWidget {
  const TeacherShell({super.key});

  static const _screens = [
    TeacherDashboardScreen(),
    QuizListScreen(),
    AttemptsResultsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(teacherTabProvider);
    return PopScope(
      canPop: index == TeacherTabs.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(teacherTabProvider.notifier).state = TeacherTabs.home;
      },
      child: Scaffold(
        body: IndexedStack(index: index, children: _screens),
        bottomNavigationBar: AppNavBar(
          selectedIndex: index,
          onDestinationSelected: (i) => ref.read(teacherTabProvider.notifier).state = i,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book_rounded),
              label: 'Quizzes',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart_rounded),
              label: 'Results',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
