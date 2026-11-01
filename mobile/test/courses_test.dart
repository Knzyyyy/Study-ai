import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tugas_akhir_mobpro/features/quiz/presentation/quiz_controller.dart';
import 'package:tugas_akhir_mobpro/features/materials/presentation/courses.dart';
import 'package:tugas_akhir_mobpro/features/materials/domain/material_model.dart';
import 'package:tugas_akhir_mobpro/features/home/presentation/home_screen.dart';

void main() {
  testWidgets('Materi counts and course filter fit narrow width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final materials = [
      for (final id in ['one', 'two'])
        MaterialModel.fromJson({
          'id': id,
          'course_id': id == 'one' ? 'course-a' : 'course-b',
          'user_id': 'user',
          'title': 'Materi $id',
          'file_path': id,
          'file_type': 'pdf',
          'status': 'done',
          'created_at': '2026-01-01T00:00:00Z',
        }),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeUserProvider.overrideWith((ref) => Stream.value(null)),
          courseUserProvider.overrideWith((ref) => Stream.value('user')),
          coursesProvider.overrideWith(
            (ref) async => const [
              Course(id: 'course-a', name: 'Matematika'),
              Course(id: 'course-b', name: 'Fisika'),
            ],
          ),
          materialsListProvider.overrideWith((ref) async => materials),
          quizProgressProvider.overrideWith((ref) async => {}),
        ],
        child: const MaterialApp(home: MaterialsLibraryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Materi'), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      const Color(0xFFFBF9F5),
    );
    final card = tester.widget<Container>(
      find
          .ancestor(
            of: find.text('Materi one'),
            matching: find.byType(Container),
          )
          .first,
    );
    expect((card.decoration! as BoxDecoration).color, const Color(0xFF22252A));
    expect(
      (card.decoration! as BoxDecoration).borderRadius,
      BorderRadius.circular(24),
    );
    expect(find.text('2 Materi'), findsOneWidget);
    expect(find.text('Materi one'), findsOneWidget);
    expect(find.text('Materi two'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Matematika').last);
    await tester.pumpAndSettle();
    expect(find.text('Materi one'), findsOneWidget);
    expect(find.text('Materi two'), findsNothing);
    expect(find.byType(CourseProgressCard), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Semua course'));
    await tester.tap(find.text('Semua course'));
    await tester.pumpAndSettle();
    expect(find.text('Materi one'), findsOneWidget);
    expect(find.text('Materi two'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('Nama dan pilihan harus valid, placeholder ditolak', () {
    const courses = [Course(id: 'real-id', name: 'Matematika')];
    expect(validateCourseName('   '), isNotNull);
    expect(validateCourseName(' Matematika '), isNull);
    expect(validCourseSelection(null, courses), isFalse);
    expect(validCourseSelection('course-123', courses), isFalse);
    expect(validCourseSelection('real-id', courses), isTrue);
    expect(validCourseSelection('real-id', []), isFalse);
  });

  test('Semua memuat legacy, filter hanya course_id cocok', () {
    MaterialModel material(String id, String? courseId) =>
        MaterialModel.fromJson({
          'id': id,
          'course_id': courseId,
          'user_id': 'user',
          'title': id,
          'file_path': id,
          'file_type': 'pdf',
          'status': 'uploaded',
          'created_at': '2026-01-01T00:00:00Z',
        });
    final materials = [material('one', 'course-a'), material('two', null)];
    expect(filterMaterials(materials, null), hasLength(2));
    expect(filterMaterials(materials, 'course-a').single.id, 'one');
    expect(filterMaterials(materials, 'course-b'), isEmpty);
  });
}
