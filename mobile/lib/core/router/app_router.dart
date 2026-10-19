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
    extendBody: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
    const primary = Color(0xFF7560B5);
    const destinations = [
      (Icons.home_rounded, 'Beranda'),
      (Icons.menu_book_outlined, 'Materi'),
      (Icons.add_rounded, 'Upload'),
      (Icons.quiz_outlined, 'Kuis'),
      (Icons.person_outline_rounded, 'Profil'),
    ];
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    const fabIndex = 2;

    Widget item(int index) {
      if (index == fabIndex) return const SizedBox(width: 68);
      return Expanded(
        child: _NavItem(
          icon: destinations[index].$1,
          label: destinations[index].$2,
          selected: selectedIndex == index,
          primary: primary,
          reducedMotion: reducedMotion,
          onTap: () => onDestinationSelected(index),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: SizedBox(
          height: 78,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(29),
                  border: Border.all(color: const Color(0xFFE7E2F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1430283F),
                      blurRadius: 18,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    for (var index = 0; index < destinations.length; index++)
                      item(index),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                child: Container(
                  width: 76,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF3EFFA),
                    borderRadius: BorderRadius.all(Radius.circular(32)),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _UploadButton(
                      primary: primary,
                      reducedMotion: reducedMotion,
                      selected: selectedIndex == fabIndex,
                      onTap: () => onDestinationSelected(fabIndex),
                    ),
                    const SizedBox(height: 4),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onDestinationSelected(fabIndex),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          child: Text(
                            destinations[fabIndex].$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              height: 1.1,
                              fontWeight: FontWeight.w700,
                              color: primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadButton extends StatelessWidget {
  const _UploadButton({
    required this.primary,
    required this.reducedMotion,
    required this.selected,
    required this.onTap,
  });

  final Color primary;
  final bool reducedMotion;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Upload',
    child: AnimatedScale(
      scale: selected ? 1.08 : 1,
      duration: reducedMotion
          ? Duration.zero
          : const Duration(milliseconds: 240),
      curve: Curves.easeOutBack,
      child: SizedBox(
        width: 60,
        height: 60,
        child: Material(
          color: primary,
          shape: const CircleBorder(),
          elevation: 6,
          shadowColor: const Color(0x667560B5),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            splashFactory: reducedMotion
                ? NoSplash.splashFactory
                : InkRipple.splashFactory,
            child: const SizedBox.expand(
              child: Icon(Icons.add_rounded, size: 30, color: Colors.white),
            ),
          ),
        ),
      ),
    ),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.primary,
    required this.reducedMotion,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color primary;
  final bool reducedMotion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final duration = reducedMotion
        ? Duration.zero
        : const Duration(milliseconds: 240);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(26),
          splashFactory: reducedMotion
              ? NoSplash.splashFactory
              : InkRipple.splashFactory,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: selected ? 1.1 : 1,
                  duration: duration,
                  curve: Curves.easeOut,
                  child: AnimatedContainer(
                    duration: duration,
                    curve: Curves.easeOut,
                    width: 44,
                    height: 26,
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFEAE3F7)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: selected ? primary : const Color(0xFF716B80),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedDefaultTextStyle(
                  duration: duration,
                  curve: Curves.easeOut,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.2,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? primary : const Color(0xFF716B80),
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
