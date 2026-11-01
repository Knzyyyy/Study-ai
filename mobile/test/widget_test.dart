import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tugas_akhir_mobpro/features/home/presentation/home_screen.dart';
import 'package:tugas_akhir_mobpro/features/quiz/presentation/quiz_controller.dart';
import 'package:tugas_akhir_mobpro/features/quiz/domain/quiz_model.dart';
import 'package:tugas_akhir_mobpro/features/materials/domain/material_model.dart';
import 'package:tugas_akhir_mobpro/features/flashcard/presentation/flashcard_controller.dart';
import 'package:tugas_akhir_mobpro/features/materials/presentation/courses.dart';
import 'package:go_router/go_router.dart';

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets('Statistics form two columns at $width', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            materialsListProvider.overrideWith((ref) async => []),
            quizProgressProvider.overrideWith((ref) async => {}),
            flashcardReviewCountProvider.overrideWith((ref) async => 7),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: HomeStatistics(),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      final icons = [
        Icons.menu_book_outlined,
        Icons.style_outlined,
        Icons.track_changes_rounded,
      ];
      final positions = icons
          .map((icon) => tester.getTopLeft(find.byIcon(icon)))
          .toList();
      expect(positions[0].dy, positions[1].dy);
      expect(positions[0].dx, lessThan(positions[1].dx));
      expect(positions[2].dy, greaterThan(positions[0].dy));
      expect(positions[2].dx, positions[0].dx);
      expect(find.text('Materi dilatih'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  test('Home latest materials sorted newest first and capped at three', () {
    final items = List.generate(
      5,
      (index) => MaterialModel(
        id: '$index',
        courseId: 'course',
        userId: 'user',
        title: '$index',
        filePath: '$index',
        fileType: 'pdf',
        status: 'done',
        createdAt: DateTime(2026, 1, index + 1),
      ),
    );
    expect(latestHomeMaterials(items).map((item) => item.id), ['4', '3', '2']);
    expect(items.first.id, '0');
    expect(latestHomeMaterials([]), isEmpty);
    expect(homeUserName(null), 'Pengguna');
  });
  testWidgets('Home empty state, real stats, reduced motion and profile link', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
        GoRoute(
          path: '/profile',
          builder: (_, _) => const Scaffold(body: Text('Profile destination')),
        ),
        GoRoute(
          path: '/materials/upload/:courseId',
          builder: (_, state) => Scaffold(
            body: Text('Upload ${state.pathParameters['courseId']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeUserProvider.overrideWith((ref) => Stream.value(null)),
          courseUserProvider.overrideWith((ref) => Stream.value('user')),
          materialsListProvider.overrideWith((ref) async => []),
          coursesProvider.overrideWith((ref) async => []),
          quizProgressProvider.overrideWith((ref) async => {}),
          flashcardReviewCountProvider.overrideWith((ref) async => 7),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Halo, Pengguna'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('Belum latihan'), findsOneWidget);
    expect(find.text('Pelajari materi terbaru'), findsNothing);
    for (final button
        in tester
            .widgetList<OutlinedButton>(find.byType(OutlinedButton))
            .take(3)) {
      expect(button.onPressed, isNull);
    }
    await tester.ensureVisible(find.text('Belum ada materi'));
    expect(find.text('Belum ada materi'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Tambahkan materi baru')).dy,
      greaterThan(tester.getBottomLeft(find.text('Belum ada materi')).dy),
    );
    final uploadButton = find.widgetWithText(FilledButton, 'Tambah materi');
    await tester.ensureVisible(uploadButton);
    await tester.tap(uploadButton);
    await tester.pumpAndSettle();
    expect(find.text('Upload course-123'), findsOneWidget);
    router.go('/');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Buka profil'));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Buka profil'));
    await tester.pumpAndSettle();
    expect(find.text('Profile destination'), findsOneWidget);
  });

  testWidgets('Home stats show unavailable with retry on provider errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          materialsListProvider.overrideWith(
            (ref) async => throw StateError('offline'),
          ),
          quizProgressProvider.overrideWith(
            (ref) async => throw StateError('offline'),
          ),
          flashcardReviewCountProvider.overrideWith(
            (ref) async => throw StateError('offline'),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: HomeStatistics())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tidak tersedia'), findsNWidgets(4));
    expect(find.text('Coba lagi'), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Narrow home uses newest done material and real progress', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    MaterialModel material(String id, String status, int day) => MaterialModel(
      id: id,
      courseId: 'course',
      userId: 'user',
      title: 'Long material title for narrow dashboard layout $id',
      filePath: id,
      fileType: 'pdf',
      status: status,
      createdAt: DateTime(2026, 1, day),
    );
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
        GoRoute(
          path: '/materials/upload/:courseId',
          builder: (_, state) => Scaffold(
            body: Text('Upload ${state.pathParameters['courseId']}'),
          ),
        ),
        for (final route in ['summary', 'flashcards', 'chat'])
          GoRoute(
            path: '/materials/ready/$route',
            builder: (_, _) => Scaffold(body: Text('$route destination')),
          ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeUserProvider.overrideWith((ref) => Stream.value(null)),
          courseUserProvider.overrideWith((ref) => Stream.value('user')),
          coursesProvider.overrideWith((ref) async => []),
          materialsListProvider.overrideWith(
            (ref) async => [
              material('pending', 'processing', 3),
              material('ready', 'done', 2),
              material('old', 'done', 1),
            ],
          ),
          quizProgressProvider.overrideWith(
            (ref) async => {
              'ready': QuizProgressModel.fromJson({
                'count': 1,
                'latest_score': 80,
              }),
              'unrelated': QuizProgressModel.fromJson({
                'count': 1,
                'latest_score': 100,
              }),
            },
          ),
          flashcardReviewCountProvider.overrideWith((ref) async => 2),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tambahkan materi baru'), findsOneWidget);
    expect(find.text('PDF atau PPTX • Maks. 20 MB'), findsOneWidget);
    expect(find.text('3 materi di perpustakaan'), findsNothing);
    expect(find.text('Lihat semua'), findsNothing);
    expect(find.text('AI Tutor'), findsWidgets);
    expect(find.text('1/3 materi dilatih'), findsOneWidget);
    expect(find.text('Pelajari materi terbaru'), findsOneWidget);
    expect(find.text('Target mingguan belum tersedia'), findsNothing);
    expect(tester.takeException(), isNull);
    final actions = find.byWidgetPredicate(
      (widget) => widget is OutlinedButton,
    );
    expect(actions, findsNWidgets(12));
    for (final entry in [(0, 'summary'), (2, 'chat')]) {
      final label = entry.$1 == 0 ? 'Ringkasan' : 'Tanya Tutor';
      await tester.ensureVisible(find.text(label).first);
      await tester.tap(find.text(label).first);
      await tester.pumpAndSettle();
      expect(find.text('${entry.$2} destination'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(
      find.byTooltip(
        'Hapus materi Long material title for narrow dashboard layout old',
      ),
    );
    final lastFile = find
        .ancestor(
          of: find.byTooltip(
            'Hapus materi Long material title for narrow dashboard layout old',
          ),
          matching: find.byType(Container),
        )
        .first;
    final uploadPanel = find
        .ancestor(
          of: find.text('Tambahkan materi baru'),
          matching: find.byType(Container),
        )
        .first;
    expect(
      tester.getRect(uploadPanel).top,
      greaterThanOrEqualTo(tester.getRect(lastFile).bottom),
    );
    await tester.ensureVisible(find.text('Tambah materi'));
    final uploadButton = find.widgetWithText(FilledButton, 'Tambah materi');
    expect(tester.getSize(uploadButton).width, greaterThanOrEqualTo(220));
    expect(tester.takeException(), isNull);
    await tester.tap(uploadButton);
    await tester.pumpAndSettle();
    expect(find.text('Upload course-123'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('Course aggregation excludes unpracticed and unrelated materials', () {
    MaterialModel material(String id) => MaterialModel(
      id: id,
      courseId: 'course',
      userId: 'user',
      title: id,
      filePath: id,
      fileType: 'pdf',
      status: 'done',
      createdAt: DateTime(2026),
    );
    QuizProgressModel score(int count, double? latest, {String? date}) =>
        QuizProgressModel.fromJson({
          'count': count,
          'latest_score': latest,
          'last_practiced_at': date,
        });
    final result = courseProgress(
      [material('a'), material('b'), material('c')],
      {
        'a': score(10, 100, date: '2026-01-01'),
        'b': score(1, 0),
        'c': score(0, null),
        'other': score(1, 100),
      },
    );
    expect(result.total, 3);
    expect(result.practiced, 2);
    expect(result.mean, 50);
    expect(result.unknownDates, 1);
    expect(courseProgress([], {}).mean, isNull);
    expect(courseProgress([material('a')], {'a': score(1, null)}).mean, isNull);
    expect(
      () => courseProgress([material('a')], {'a': score(1, 101)}),
      throwsFormatException,
    );
  });
  testWidgets('Course progress smoke works without app initialization', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [quizProgressProvider.overrideWith((ref) async => {})],
        child: const MaterialApp(
          home: Scaffold(body: CourseProgressCard(materials: [])),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('0/0 materi dilatih'), findsOneWidget);
    expect(find.textContaining('Belum latihan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
