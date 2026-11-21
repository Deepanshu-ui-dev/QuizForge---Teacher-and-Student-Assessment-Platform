import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/app_nav_bar.dart';
import '../../profile/presentation/profile_screen.dart';
import 'attempt_history_screen.dart';
import 'join_quiz_screen.dart';
import 'student_dashboard_screen.dart';

/// Selected bottom-nav tab. Lets screens (e.g. the dashboard's "Join"
/// button) switch tabs instead of pushing a duplicate of a tab's screen.
final studentTabProvider = StateProvider.autoDispose<int>((ref) => 0);

class StudentTabs {
  static const home = 0;
  static const join = 1;
  static const history = 2;
  static const profile = 3;
}

class StudentShell extends ConsumerWidget {
  const StudentShell({super.key});

  static const _screens = [
    StudentDashboardScreen(),
    JoinQuizScreen(),
    AttemptHistoryScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(studentTabProvider);
    return PopScope(
      // Back on a secondary tab returns to Home before leaving the app.
      canPop: index == StudentTabs.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(studentTabProvider.notifier).state = StudentTabs.home;
      },
      child: Scaffold(
        body: IndexedStack(index: index, children: _screens),
        bottomNavigationBar: AppNavBar(
          selectedIndex: index,
          onDestinationSelected: (i) => ref.read(studentTabProvider.notifier).state = i,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore_rounded),
              label: 'Browse',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_rounded),
              selectedIcon: Icon(Icons.history_rounded),
              label: 'History',
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
