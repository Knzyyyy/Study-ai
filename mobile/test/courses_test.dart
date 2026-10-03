import 'package:flutter_test/flutter_test.dart';
import 'package:tugas_akhir_mobpro/features/materials/presentation/courses.dart';
import 'package:tugas_akhir_mobpro/features/materials/domain/material_model.dart';
import 'package:tugas_akhir_mobpro/features/home/presentation/home_screen.dart';

void main() {
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
