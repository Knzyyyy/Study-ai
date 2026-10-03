import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/summary_model.dart';

class SummaryRepository {
  final Dio _dio;

  SummaryRepository(this._dio);

  // Ambil ringkasan dari FastAPI
  Future<SummaryModel> getSummary(String materialId) async {
    final response = await _dio.get('/materials/$materialId/summary');
    return SummaryModel.fromJson(response.data);
  }

  // Minta AI membuat ulang ringkasan
  Future<void> regenerateSummary(String materialId) async {
    await _dio.post('/materials/$materialId/summary/regenerate');
  }
}

final summaryRepositoryProvider = Provider<SummaryRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return SummaryRepository(dio);
});
