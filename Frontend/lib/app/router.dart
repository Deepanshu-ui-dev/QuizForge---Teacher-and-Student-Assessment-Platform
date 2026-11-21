import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/models/result.dart';
import '../core/providers/core_providers.dart';
import '../core/utils/app_role.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/onboarding/presentation/auth_choice_screen.dart';
import '../features/onboarding/presentation/onboarding_carousel_screen.dart';
import '../features/onboarding/presentation/splash_screen.dart';
import '../features/student/presentation/join_quiz_screen.dart';
import '../features/student/presentation/quiz_instructions_screen.dart';
import '../features/student/presentation/result_screen.dart';
import '../features/student/presentation/student_shell.dart';
import '../features/student/presentation/take_quiz_screen.dart';
import '../features/teacher/presentation/analytics_screen.dart';
import '../features/teacher/presentation/attempts_results_screen.dart';
import '../features/teacher/presentation/create_edit_quiz_screen.dart';
import '../features/teacher/presentation/edit_quiz_loader.dart';
import '../features/teacher/presentation/question_builder_screen.dart';
import '../features/teacher/presentation/quiz_detail_screen.dart';
import '../features/teacher/presentation/teacher_shell.dart';
import '../shared/widgets/not_found_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const splash = '/';
  static const onboarding = '/onboarding';
  static const authChoice = '/auth';
  static const login = '/auth/login';
  static const register = '/auth/register';

  static const teacherHome = '/teacher';
  static const createQuiz = '/teacher/quizzes/create';
  static String quizDetail(int id) => '/teacher/quizzes/$id';
  static String quizEdit(int id) => '/teacher/quizzes/$id/edit';
  static String quizQuestions(int id) => '/teacher/quizzes/$id/questions';
  static String quizResults(int id) => '/teacher/quizzes/$id/results';
  static String quizAnalytics(int id) => '/teacher/quizzes/$id/analytics';
  static String teacherResult(int id) => '/teacher/results/$id';

  static const studentHome = '/student';
  static const joinQuiz = '/student/join';
  static String quizInstructions(int id) => '/student/quizzes/instructions/$id';
  static String takeQuiz(int id) => '/student/quizzes/take/$id';
  static String studentResult(int id) => '/student/results/$id';
}

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(sessionProvider, (_, __) => notifyListeners());
  }
}

/// Builds a screen for a route with an integer `:id`, or a not-found page
/// for malformed deep links instead of throwing on `int.parse`.
GoRouterWidgetBuilder _withId(Widget Function(int id, GoRouterState state) builder) {
  return (context, state) {
    final id = int.tryParse(state.pathParameters['id'] ?? '');
    if (id == null) return const NotFoundScreen();
    return builder(id, state);
  };
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refreshNotifier,
    errorBuilder: (context, state) => const NotFoundScreen(),
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingCarouselScreen(),
      ),
      GoRoute(
        path: AppRoutes.authChoice,
        builder: (context, state) => const AuthChoiceScreen(),
        routes: [
          GoRoute(path: 'login', builder: (context, state) => const LoginScreen()),
          GoRoute(
            path: 'register',
            builder: (context, state) {
              final roleParam = state.uri.queryParameters['role'];
              final initialRole = roleParam == 'teacher' ? AppRole.teacher : AppRole.student;
              return RegisterScreen(initialRole: initialRole);
            },
          ),
        ],
      ),

      // Teacher routes are nested under the shell so the back stack always
      // returns to the dashboard rather than exiting the app.
      GoRoute(
        path: AppRoutes.teacherHome,
        builder: (context, state) => const TeacherShell(),
        routes: [
          GoRoute(
            path: 'quizzes/create',
            builder: (context, state) => const CreateEditQuizScreen(),
          ),
          GoRoute(
            path: 'quizzes/:id',
            builder: _withId((id, _) => QuizDetailScreen(quizId: id)),
            routes: [
              GoRoute(path: 'edit', builder: _withId((id, _) => EditQuizLoader(quizId: id))),
              GoRoute(
                path: 'questions',
                builder: _withId((id, _) => QuestionBuilderScreen(quizId: id)),
              ),
              GoRoute(
                path: 'results',
                builder: _withId((id, _) => AttemptsResultsScreen(quizId: id)),
              ),
              GoRoute(
                path: 'analytics',
                builder: _withId((id, _) => AnalyticsScreen(quizId: id)),
              ),
            ],
          ),
          GoRoute(
            path: 'results/:id',
            builder: _withId(
              (id, state) => ResultScreen(resultId: id, initial: state.extra as QuizResult?),
            ),
          ),
        ],
      ),

      GoRoute(
        path: AppRoutes.studentHome,
        builder: (context, state) => const StudentShell(),
        routes: [
          GoRoute(path: 'join', builder: (context, state) => const JoinQuizScreen(standalone: true)),
          GoRoute(
            path: 'quizzes/instructions/:id',
            builder: _withId((id, _) => QuizInstructionsScreen(quizId: id)),
          ),
          GoRoute(
            path: 'quizzes/take/:id',
            builder: _withId((id, _) => TakeQuizScreen(quizId: id)),
          ),
          GoRoute(
            path: 'results/:id',
            builder: _withId(
              (id, state) => ResultScreen(resultId: id, initial: state.extra as QuizResult?),
            ),
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      final sessionAsync = ref.read(sessionProvider);
      final location = state.matchedLocation;
      final onSplash = location == AppRoutes.splash;

      if (!sessionAsync.hasValue) {
        return onSplash ? null : AppRoutes.splash;
      }

      final session = sessionAsync.requireValue;
      final onOnboarding = location == AppRoutes.onboarding;
      final onAuthFlow = location == AppRoutes.authChoice ||
          location == AppRoutes.login ||
          location == AppRoutes.register;
      final onTeacherRoute = location.startsWith(AppRoutes.teacherHome);
      final onStudentRoute = location.startsWith(AppRoutes.studentHome);

      if (session.isAuthenticated) {
        final isTeacher = session.role == AppRole.teacher;
        final roleHome = isTeacher ? AppRoutes.teacherHome : AppRoutes.studentHome;
        final onOtherRoleRoute = isTeacher ? onStudentRoute : onTeacherRoute;

        if (onSplash || onOnboarding || onAuthFlow || onOtherRoleRoute) {
          return roleHome;
        }
        return null;
      }

      if (!session.onboardingSeen) {
        return onOnboarding ? null : AppRoutes.onboarding;
      }

      if (onSplash || onOnboarding || onTeacherRoute || onStudentRoute) {
        return AppRoutes.authChoice;
      }

      return null;
    },
  );
});
