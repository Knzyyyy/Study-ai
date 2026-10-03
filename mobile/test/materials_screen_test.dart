import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tugas_akhir_mobpro/features/materials/data/material_repository.dart';
import 'package:tugas_akhir_mobpro/features/materials/presentation/materials_screen.dart';
import 'package:tugas_akhir_mobpro/features/materials/presentation/courses.dart';
import 'package:tugas_akhir_mobpro/features/materials/presentation/materials_controller.dart';

class TestPicker extends FilePicker {
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => FilePickerResult([
    PlatformFile(name: 'slides.pdf', size: 1024, path: '/slides.pdf'),
  ]);
}

class TestRepository extends MaterialRepository {
  TestRepository()
    : super(
        SupabaseClient(
          'https://example.com',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
        Dio(),
      );

  int uploads = 0;
  bool? summary;
  final completion = Completer<void>();

  @override
  Future<String> uploadAndCreateMaterial({
    required String courseId,
    File? file,
    Uint8List? bytes,
    required String fileName,
    required String fileType,
    bool generateSummary = true,
    bool generateFlashcards = false,
    bool generateQuiz = false,
  }) {
    uploads++;
    summary = generateSummary;
    expect(courseId, '123e4567-e89b-12d3-a456-426614174000');
    expect(fileName, 'slides.pdf');
    expect(fileType, 'pdf');
    expect(file?.path, '/slides.pdf');
    return completion.future.then((_) => 'material');
  }

  @override
  Future<void> process(String materialId, Map<String, bool> options) async {
    lastOptions = Map.of(options);
  }

  String serverStatus = 'done';
  Map<String, bool>? lastOptions;

  @override
  Future<Map<String, dynamic>> checkStatus(String materialId) async => {
    'status': serverStatus,
  };
}

void main() {
  test(
    'Polling timeout preserves processing; retry preserves options',
    () async {
      final repository = TestRepository()..serverStatus = 'processing';
      final controller = MaterialsController(
        repository,
        pollInterval: Duration.zero,
        maxPolls: 2,
      );
      repository.completion.complete();
      await controller.uploadMaterial(
        courseId: '123e4567-e89b-12d3-a456-426614174000',
        filePath: '/slides.pdf',
        fileName: 'slides.pdf',
        fileType: 'pdf',
        generateSummary: false,
        generateQuiz: true,
      );
      expect(controller.status, 'processing');
      expect(controller.state.isLoading, false);
      expect(controller.message, contains('Masih diproses'));
      repository.serverStatus = 'failed';
      await controller.poll();
      expect(controller.state.hasError, true);
      repository.serverStatus = 'done';
      await controller.retry();
      expect(controller.status, 'done');
      expect(repository.uploads, 1);
      expect(repository.lastOptions, {
        'generate_summary': false,
        'generate_flashcards': false,
        'generate_quiz': true,
      });
      controller.dispose();
    },
  );
  testWidgets('Selection stages file; analysis alone uploads', (tester) async {
    FilePicker.platform = TestPicker();
    final repository = TestRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          materialRepositoryProvider.overrideWithValue(repository),
          coursesProvider.overrideWith(
            (ref) async => const [
              Course(
                id: '123e4567-e89b-12d3-a456-426614174000',
                name: 'Matematika',
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: MaterialsScreen(courseId: 'course')),
      ),
    );
    final analyze = find.widgetWithText(FilledButton, 'Mulai Analisis');
    expect(tester.widget<FilledButton>(analyze).onPressed, isNull);
    await tester.tap(find.text('Pilih Dokumen'));
    await tester.pumpAndSettle();
    expect(repository.uploads, 0);
    expect(find.text('slides.pdf'), findsOneWidget);
    expect(find.text('0.00 MB'), findsOneWidget);
    expect(tester.widget<FilledButton>(analyze).onPressed, isNull);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Matematika').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(Switch).first);
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(analyze);
    await tester.tap(analyze);
    await tester.pump();
    expect(repository.uploads, 1);
    expect(repository.summary, false);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    repository.completion.complete();
    await tester.pumpAndSettle();
    expect(find.text('slides.pdf'), findsNothing);
    expect(tester.widget<FilledButton>(analyze).onPressed, isNull);
  });
}
