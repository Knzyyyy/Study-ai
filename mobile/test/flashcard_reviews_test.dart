import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tugas_akhir_mobpro/features/flashcard/data/flashcard_repository.dart';
import 'package:tugas_akhir_mobpro/features/flashcard/domain/flashcard_model.dart';
import 'package:tugas_akhir_mobpro/features/flashcard/presentation/flashcard_controller.dart';
import 'package:tugas_akhir_mobpro/features/flashcard/presentation/flashcards_screen.dart';

class ReviewRepository extends FlashcardRepository {
  ReviewRepository() : super(Dio());
  final pending = Completer<void>();
  int calls = 0;
  bool studied = false;

  @override
  Future<void> markStudied(String materialId, String flashcardId) async {
    expect(materialId, 'material');
    expect(flashcardId, 'card');
    calls++;
    await pending.future;
    studied = true;
  }
}

void main() {
  testWidgets(
    'Explicit mark saves once and refreshes persisted studied state',
    (tester) async {
      final repo = ReviewRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            flashcardRepositoryProvider.overrideWithValue(repo),
            flashcardsProvider('material').overrideWith(
              (ref) async => [
                FlashcardModel(
                  id: 'card',
                  materialId: 'material',
                  front: 'Question',
                  back: 'Answer',
                  studied: repo.studied,
                ),
              ],
            ),
            flashcardReviewCountProvider.overrideWith(
              (ref) async => repo.studied ? 1 : 0,
            ),
          ],
          child: const MaterialApp(
            home: FlashcardsScreen(materialId: 'material'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.calls, 0);
      await tester.tap(find.text('Question'));
      await tester.pump();
      expect(repo.calls, 0);
      await tester.tap(find.text('Tandai sudah dipelajari'));
      await tester.pump();
      expect(find.text('Menyimpan...'), findsOneWidget);
      await tester.tap(find.text('Menyimpan...'));
      expect(repo.calls, 1);
      repo.pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Sudah dipelajari'), findsOneWidget);
      await tester.tap(find.text('Sudah dipelajari'));
      expect(repo.calls, 1);
    },
  );
}
