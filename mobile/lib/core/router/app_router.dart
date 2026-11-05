import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../widgets/app_navigation_bar.dart';
export '../widgets/app_navigation_bar.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/materials/presentation/materials_screen.dart';
import '../../features/materials/presentation/material_detail_screen.dart';
import '../../features/summary/presentation/summary_screen.dart';
import '../../features/flashcard/presentation/flashcards_screen.dart';
import '../../features/quiz/presentation/quiz_screen.dart';
import '../../features/quiz/presentation/quiz_review_screen.dart';
import '../../features/tutor_chat/presentation/chat_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/quiz/presentation/quiz_hub_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';

final authStateChangeProvider = StreamProvider.autoDispose((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

final routerProvider = Provider<GoRouter>((ref) {
  final authRefresh = ValueNotifier(false);
  final router = GoRouter(
    initialLocation: '/login',
    refreshListenable: authRefresh,
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isRecovery = ref.read(passwordRecoveryModeProvider);
      final isRegisteringToLogIn = ref.read(registrationLoginFlowProvider);
      final isGoingToLogin = state.matchedLocation == '/login';
      final isRegistering = state.matchedLocation == '/register';
      final isPasswordRecoveryCallback =
          state.uri.scheme == 'io.supabase.tugaskhir' &&
          state.uri.host == 'password-reset';
      final isResettingPassword =
          state.matchedLocation == '/reset-password' ||
          state.matchedLocation == '/password-reset' ||
          state.matchedLocation == '/password-reset/reset-password' ||
          isPasswordRecoveryCallback;
      if (isPasswordRecoveryCallback &&
          state.matchedLocation != '/reset-password') {
        return '/reset-password';
      }
      if (isRecovery && !isResettingPassword) return '/reset-password';
      if (session == null &&
          !isGoingToLogin &&
          !isRegistering &&
          !isResettingPassword) {
        return '/login';
      }
      if (session != null &&
          (isGoingToLogin || isRegistering) &&
          !(isRegisteringToLogIn && isRegistering)) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: '/password-reset',
        redirect: (context, state) => '/reset-password',
      ),
      GoRoute(
        path: '/password-reset/reset-password',
        redirect: (context, state) => '/reset-password',
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            _NavigationShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/materials',
                builder: (context, state) => const MaterialsLibraryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            initialLocation: '/materials/upload/course-123',
            routes: [
              GoRoute(
                path: '/materials/upload/:courseId',
                builder: (context, state) => MaterialsScreen(
                  courseId: state.pathParameters['courseId']!,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/quiz',
                builder: (context, state) => const QuizHubScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/materials/:id/detail',
        builder: (context, state) =>
            MaterialDetailScreen(materialId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/materials/:id/summary',
        builder: (context, state) =>
            SummaryScreen(materialId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/materials/:id/flashcards',
        builder: (context, state) =>
            FlashcardsScreen(materialId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/materials/:id/quiz',
        builder: (context, state) => QuizScreen(
          materialId: state.pathParameters['id']!,
          amount: int.tryParse(state.uri.queryParameters['amount'] ?? '') ?? 10,
          difficulty: state.uri.queryParameters['difficulty'] ?? 'sedang',
          generateNew: state.uri.queryParameters['generate_new'] == 'true',
        ),
      ),
      GoRoute(
        path: '/materials/:id/chat',
        builder: (context, state) =>
            ChatScreen(materialId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/quiz-attempts/:attemptId/review',
        builder: (context, state) => QuizReviewScreen(
          attemptId: state.pathParameters['attemptId']!,
          materialId: state.uri.queryParameters['material_id'],
          durationSeconds: int.tryParse(
            state.uri.queryParameters['duration_seconds'] ?? '',
          ),
          difficulty: state.uri.queryParameters['difficulty'],
        ),
      ),
    ],
  );
  final subscription = Supabase.instance.client.auth.onAuthStateChange.listen((
    authState,
  ) {
    if (authState.event == AuthChangeEvent.passwordRecovery) {
      ref.read(passwordRecoveryModeProvider.notifier).state = true;
      router.go('/reset-password');
    } else if (authState.event == AuthChangeEvent.signedOut) {
      ref.read(passwordRecoveryModeProvider.notifier).state = false;
    }
    authRefresh.value = !authRefresh.value;
  });
  ref.onDispose(() {
    subscription.cancel();
    router.dispose();
    authRefresh.dispose();
  });
  return router;
});

class _NavigationShell extends StatelessWidget {
  const _NavigationShell({required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBody: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    body: navigationShell,
    bottomNavigationBar: AppNavigationBar(
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: (index) => navigationShell.goBranch(index),
    ),
  );
}
