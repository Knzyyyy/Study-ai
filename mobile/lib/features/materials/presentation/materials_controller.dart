import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/material_repository.dart';
import '../../home/presentation/home_screen.dart';
import '../../quiz/presentation/quiz_controller.dart';
import 'courses.dart';

class MaterialsController extends StateNotifier<AsyncValue<void>> {
  final MaterialRepository _repository;
  final void Function()? onChanged;
  final Duration pollInterval;
  final int maxPolls;
  String? materialId;
  String? status;
  String? message;
  Map<String, bool> _options = {};
  int _revision = 0;
  Timer? _timer;
  Completer<void>? _waiting;

  MaterialsController(
    this._repository, {
    this.onChanged,
    this.pollInterval = const Duration(seconds: 2),
    this.maxPolls = 60,
  }) : super(const AsyncValue.data(null));

  Future<bool> uploadMaterial({
    required String courseId,
    String? filePath,
    Uint8List? bytes,
    required String fileName,
    required String fileType,
    bool generateSummary = true,
    bool generateFlashcards = false,
    bool generateQuiz = false,
  }) async {
    if (state.isLoading) return false;
    state = const AsyncValue.loading();
    materialId = null;
    status = 'uploaded';
    message = null;
    _options = {
      'generate_summary': generateSummary,
      'generate_flashcards': generateFlashcards,
      'generate_quiz': generateQuiz,
    };
    try {
      final id = await _repository.uploadAndCreateMaterial(
        courseId: courseId,
        file: filePath == null ? null : File(filePath),
        bytes: bytes,
        fileName: fileName,
        fileType: fileType,
        generateSummary: generateSummary,
        generateFlashcards: generateFlashcards,
        generateQuiz: generateQuiz,
      );
      if (!mounted) return false;
      materialId = id;
      onChanged?.call();
      await retry();
      return true;
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<void> retry() async {
    final id = materialId;
    if (id == null || !mounted) return;
    final revision = ++_revision;
    state = const AsyncValue.loading();
    message = null;
    try {
      await _repository
          .process(id, _options)
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      if (!mounted || revision != _revision) return;
      message = 'Permintaan belum terkonfirmasi. Memeriksa status server...';
    }
    if (!mounted || revision != _revision) return;
    await poll();
  }

  Future<void> poll() async {
    final id = materialId;
    if (id == null || !mounted) return;
    final revision = ++_revision;
    state = const AsyncValue.loading();
    for (var attempt = 0; attempt < maxPolls; attempt++) {
      try {
        final result = await _repository
            .checkStatus(id)
            .timeout(const Duration(seconds: 15));
        if (!mounted || revision != _revision) return;
        status = result['status'] as String;
        message = result['error_message'] as String?;
        if (status == 'done' || status == 'failed' || status == 'uploaded') {
          onChanged?.call();
          state = status == 'failed'
              ? AsyncValue.error(
                  message ?? 'Analisis gagal',
                  StackTrace.current,
                )
              : const AsyncValue.data(null);
          return;
        }
      } catch (_) {
        if (!mounted || revision != _revision) return;
        message =
            'Status belum dapat diperiksa. Proses server tidak dibatalkan.';
      }
      _waiting = Completer<void>();
      _timer = Timer(
        pollInterval * (1 + attempt ~/ 15),
        () => _waiting?.complete(),
      );
      await _waiting!.future;
      if (!mounted || revision != _revision) return;
    }
    message =
        'Masih diproses atau status belum terkonfirmasi. Periksa status lagi; jangan unggah ulang.';
    state = const AsyncValue.data(null);
    onChanged?.call();
  }

  @override
  void dispose() {
    _revision++;
    _timer?.cancel();
    if (_waiting != null && !_waiting!.isCompleted) _waiting!.complete();
    super.dispose();
  }
}

final materialsControllerProvider =
    StateNotifierProvider<MaterialsController, AsyncValue<void>>((ref) {
      ref.watch(courseUserProvider.select((value) => value.valueOrNull));
      return MaterialsController(
        ref.watch(materialRepositoryProvider),
        onChanged: () {
          ref.invalidate(materialsListProvider);
          ref.invalidate(quizProgressProvider);
        },
      );
    });
