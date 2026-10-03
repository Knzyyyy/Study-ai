import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_provider.dart';

class MaterialRepository {
  final SupabaseClient _supabase;
  final Dio _dio;

  MaterialRepository(this._supabase, this._dio);

  /// 1. Upload file ke Supabase Storage dan buat row di database tabel 'materials'
  Future<String> uploadAndCreateMaterial({
    required String courseId,
    File? file,
    Uint8List? bytes,
    required String fileName,
    required String fileType,
    bool generateSummary = true,
    bool generateFlashcards = false,
    bool generateQuiz = false,
  }) async {
    final user = _supabase.auth.currentUser;
    final sessionUser = _supabase.auth.currentSession?.user;
    debugPrint('current user: ${user?.id}');
    debugPrint('session user: ${sessionUser?.id}');
    if (user == null) throw Exception('User tidak sedang login');

    final course = await _supabase
        .from('courses')
        .select('id')
        .eq('id', courseId)
        .eq('user_id', user.id)
        .maybeSingle();
    if (course == null) throw Exception('Pilih mata kuliah yang valid.');

    // Buat nama file unik agar tidak bentrok
    final filePathInStorage =
        '${user.id}/${DateTime.now().millisecondsSinceEpoch}_$fileName';

    debugPrint('Upload user: ${user.id}');
    debugPrint('Upload path: $filePathInStorage');
    debugPrint('Upload bucket: materials');

    if (file == null && bytes == null) {
      throw Exception('File tidak dapat dibaca');
    }

    if (bytes != null) {
      await _supabase.storage
          .from('materials')
          .uploadBinary(filePathInStorage, bytes);
    } else {
      await _supabase.storage
          .from('materials')
          .upload(filePathInStorage, file!);
    }

    debugPrint('Upload storage berhasil');
    debugPrint('Sebelum insert materials');

    late final Map<String, dynamic> insertResponse;
    try {
      insertResponse = await _supabase
          .from('materials')
          .insert({
            'course_id': courseId,
            'user_id': user.id,
            'title': fileName,
            'file_path': filePathInStorage,
            'file_type': fileType,
            'status': 'uploaded',
          })
          .select()
          .single()
          .timeout(const Duration(seconds: 15));
    } catch (e, st) {
      debugPrint('Insert materials gagal: $e');
      debugPrintStack(stackTrace: st);
      rethrow;
    }

    final materialId = insertResponse['id'];
    debugPrint('Insert berhasil: $materialId');
    debugPrint('Sebelum panggil backend: ${_dio.options.baseUrl}');

    return materialId as String;
  }

  Future<void> process(String materialId, Map<String, bool> options) async {
    await _dio.post('/materials/$materialId/process', data: options);
  }

  /// 2. Cek status pemrosesan materi
  Future<Map<String, dynamic>> checkStatus(String materialId) async {
    final response = await _dio.get('/materials/$materialId/status');
    return response.data;
  }
}

final materialRepositoryProvider = Provider<MaterialRepository>((ref) {
  final supabase = Supabase.instance.client;
  final dio = ref.watch(dioProvider);
  return MaterialRepository(supabase, dio);
});
