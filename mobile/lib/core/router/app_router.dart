import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Import semua screen yang sudah kita buat
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

    // LOGIKA AUTO-LOGIN (AUTH GUARD)
    redirect: (context, state) {
      // Cek apakah ada sesi aktif di Supabase
      final session = Supabase.instance.client.auth.currentSession;

      // Cek apakah user sedang berada di halaman login
      final isGoingToLogin = state.matchedLocation == '/login';

      if (session == null && !isGoingToLogin) {
        // Kasus 1: Belum login tapi mencoba buka halaman lain -> Paksa ke Login
        return '/login';
      }

      if (session != null && isGoingToLogin) {
        // Kasus 2: Sudah login tapi mencoba buka halaman Login -> Lempar ke Home
        return '/';
      }

      // Kasus 3: Sesi valid, biarkan lewat
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
        builder: (context, state) {
          final materialId = state.pathParameters['id']!;
          return SummaryScreen(materialId: materialId);
        },
      ),
      GoRoute(
        path: '/materials/:id/flashcards',
        builder: (context, state) {
          final materialId = state.pathParameters['id']!;
          return FlashcardsScreen(materialId: materialId);
        },
      ),
      GoRoute(
        path: '/materials/:id/quiz',
        builder: (context, state) {
          final materialId = state.pathParameters['id']!;
          return QuizScreen(materialId: materialId);
        },
      ),
      GoRoute(
        path: '/materials/:id/chat',
        builder: (context, state) {
          final materialId = state.pathParameters['id']!;
          return ChatScreen(materialId: materialId);
        },
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
    body: navigationShell,
    bottomNavigationBar: AppNavigationBar(
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: (index) => navigationShell.goBranch(index),
    ),
  );
}

class AppNavigationBar extends StatelessWidget {
  const AppNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF4F46E5);
    const destinations = [
      (Icons.home_rounded, 'Beranda'),
      (Icons.menu_book_outlined, 'Materi'),
      (Icons.add_rounded, 'Upload'),
      (Icons.quiz_outlined, 'Kuis'),
      (Icons.person_outline_rounded, 'Profil'),
    ];
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var index = 0; index < destinations.length; index++)
                Expanded(
                  child: Semantics(
                    selected: selectedIndex == index,
                    button: true,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onDestinationSelected(index),
                        borderRadius: BorderRadius.circular(18),
                        splashFactory: reducedMotion
                            ? NoSplash.splashFactory
                            : InkRipple.splashFactory,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedContainer(
                                duration: reducedMotion
                                    ? Duration.zero
                                    : const Duration(milliseconds: 220),
                                width: index == 2 ? 56 : 52,
                                height: index == 2 ? 56 : 32,
                                margin: EdgeInsets.only(
                                  bottom: index == 2 ? 6 : 4,
                                ),
                                decoration: BoxDecoration(
                                  color: index == 2
                                      ? primary
                                      : selectedIndex == index
                                      ? const Color(0xFFEEF2FF)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: index == 2
                                      ? const [
                                          BoxShadow(
                                            color: Color(0x334F46E5),
                                            blurRadius: 12,
                                            offset: Offset(0, 4),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Icon(
                                  destinations[index].$1,
                                  size: index == 2 ? 28 : 22,
                                  color: index == 2
                                      ? Colors.white
                                      : selectedIndex == index
                                      ? primary
                                      : const Color(0xFF64748B),
                                ),
                              ),
                              Text(
                                destinations[index].$2,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: selectedIndex == index
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: selectedIndex == index
                                      ? primary
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
