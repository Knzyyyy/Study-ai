import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:tugas_akhir_mobpro/core/router/app_router.dart';

void main() {
  testWidgets('Five destinations select correctly with reduced motion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              bottomNavigationBar: AppNavigationBar(
                selectedIndex: selected,
                onDestinationSelected: (index) =>
                    setState(() => selected = index),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(InkWell), findsNWidgets(5));
    expect(find.byType(AnimatedScale), findsNothing);
    expect(find.text('Upload'), findsNothing);
    const types = [
      Icons.home_rounded,
      Icons.menu_book_rounded,
      Icons.add_rounded,
      Icons.assignment_turned_in_outlined,
      Icons.person_outline_rounded,
    ];
    for (var index = 0; index < types.length; index++) {
      await tester.tap(find.byIcon(types[index]));
      await tester.pump();
      expect(selected, index);
    }
    expect(tester.takeException(), isNull);
  });
  test(
    'Shared navigation wires every branch and keeps details outside shell',
    () {
      final router = File('lib/core/router/app_router.dart').readAsStringSync();
      expect(router, contains('StatefulShellRoute.indexedStack('));
      expect('StatefulShellBranch('.allMatches(router).length, 5);
      expect(router, contains('navigationShell.goBranch(index)'));
      expect(router, contains('selectedIndex: navigationShell.currentIndex'));
      expect(
        router,
        contains("initialLocation: '/materials/upload/course-123'"),
      );
      expect(router, contains('refreshListenable: authRefresh'));
      final shellEnd = router.indexOf("path: '/materials/:id/summary'");
      for (final path in [
        '/',
        '/materials/upload/:courseId',
        '/quiz',
        '/profile',
      ]) {
        expect(router.indexOf("path: '$path'"), lessThan(shellEnd));
      }
      for (final feature in [
        'home/presentation/home_screen.dart',
        'materials/presentation/materials_screen.dart',
        'quiz/presentation/quiz_hub_screen.dart',
        'quiz/presentation/quiz_screen.dart',
        'profile/presentation/profile_screen.dart',
      ]) {
        final source = File('lib/features/$feature').readAsStringSync();
        expect(source, isNot(contains('bottomNavigationBar:')));
        expect(source, isNot(contains('BottomNavigationBar(')));
        expect(source, isNot(contains('Widget _bottomNavigation(')));
        expect(source, isNot(contains('Widget _navigation(')));
      }
    },
  );
}
