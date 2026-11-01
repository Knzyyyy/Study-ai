import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/app_navigation_bar.dart';
export '../widgets/app_navigation_bar.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/materials/presentation/materials_screen.dart';
import '../../features/summary/presentation/summary_screen.dart';
import '../../features/flashcard/presentation/flashcards_screen.dart';
import '../../features/quiz/presentation/quiz_screen.dart';
import '../../features/tutor_chat/presentation/chat_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/quiz/presentation/quiz_hub_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';

final authStateChangeProvider = StreamProvider.autoDispose((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

final routerProvider = Provider<GoRouter>((ref) {
  final authRefresh = ValueNotifier(false);
  final subscription = Supabase.instance.client.auth.onAuthStateChange.listen(
    (_) => authRefresh.value = !authRefresh.value,
  );
  final router = GoRouter(
    initialLocation: '/login',
    refreshListenable: authRefresh,
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isGoingToLogin = state.matchedLocation == '/login';
      if (session == null && !isGoingToLogin) return '/login';
      if (session != null && isGoingToLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
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
        builder: (context, state) =>
            QuizScreen(materialId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/materials/:id/chat',
        builder: (context, state) =>
            ChatScreen(materialId: state.pathParameters['id']!),
      ),
    ],
  );
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
