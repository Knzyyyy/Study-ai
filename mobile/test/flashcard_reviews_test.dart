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
  bool reviewed = false;

  @override
  Future<void> reviewCard(
    String materialId,
    String flashcardId, {
    required bool understood,
  }) async {
    expect(materialId, 'material');
    expect(flashcardId, 'card');
    calls++;
    await pending.future;
    studied = understood;
    reviewed = true;
  }
}

void main() {
  testWidgets('Review saves without leaving the card, then finish session', (
    tester,
  ) async {
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
                sourcePage: 4,
                example: 'A short example.',
                reviewed: repo.reviewed,
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
    expect(find.text('Question'), findsOneWidget);
    expect(find.text('Belum dinilai: 1'), findsOneWidget);
    await tester.ensureVisible(find.text('Balik kartu'));
    await tester.tap(find.text('Balik kartu'));
    await tester.pump();
    expect(find.text('Sumber: Hal. 4'), findsOneWidget);
    expect(find.text('Contoh: A short example.'), findsOneWidget);
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Sudah paham'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sudah paham'));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsWidgets);
    expect(repo.calls, 1);
    repo.pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Answer'), findsOneWidget);
    expect(find.text('Belum dinilai: 0'), findsOneWidget);
    expect(find.text('Sesi Flashcard Selesai!'), findsNothing);
    await tester.tap(find.text('Simulasi\nSelesai'));
    await tester.pumpAndSettle();
    expect(find.text('Sesi Flashcard Selesai!'), findsOneWidget);
    expect(find.text('Sudah paham'), findsOneWidget);
  });
}
