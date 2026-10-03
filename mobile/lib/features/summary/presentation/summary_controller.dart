import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/summary_repository.dart';
import '../domain/summary_model.dart';

// FutureProvider dengan parameter materialId
final summaryProvider = FutureProvider.family<SummaryModel, String>((
  ref,
  materialId,
) async {
  final repo = ref.watch(summaryRepositoryProvider);
  return repo.getSummary(materialId);
});
