import 'dart:async';
import 'package:tugas_akhir_mobpro/features/flashcard/presentation/flashcard_controller.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tugas_akhir_mobpro/features/home/presentation/home_screen.dart';
import 'package:tugas_akhir_mobpro/features/quiz/domain/quiz_model.dart';
import 'package:tugas_akhir_mobpro/features/quiz/presentation/quiz_controller.dart';
import 'package:tugas_akhir_mobpro/features/profile/presentation/profile_screen.dart';

QuizProgressModel progress(int count, double? mean) =>
    QuizProgressModel.fromJson({'count': count, 'mean_score': mean});

void main() {
  test('Profile validators enforce bounds and optional NIM', () {
    expect(validateProfileName(' A '), isNotNull);
    expect(validateProfileName(' Ada Lovelace '), isNull);
    expect(validateProfileName('A\nB'), isNotNull);
    expect(validateProfileName('x' * 101), isNotNull);
    expect(validateNim(''), isNull);
    expect(validateNim('12345678'), isNull);
    expect(validateNim('12'), isNotNull);
    expect(validateNim('x' * 31), isNotNull);
    expect(validateNim('abc xyz'), isNotNull);
    expect(validatePassword('1234567'), isNotNull);
    expect(validatePassword('12345678'), isNull);
    expect(validatePasswordConfirmation('different', '12345678'), isNotNull);
    expect(validatePasswordConfirmation('12345678', '12345678'), isNull);
  });

  testWidgets('Profile form validates and prevents duplicate submits', (
    tester,
  ) async {
    final pending = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileEditForm(
            password: true,
            save: (_, _) {
              calls++;
              return pending.future;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Simpan'));
    await tester.pump();
    expect(calls, 0);
    await tester.enterText(find.byType(TextFormField).at(0), '12345678');
    await tester.enterText(find.byType(TextFormField).at(1), '12345678');
    await tester.tap(find.text('Simpan'));
    await tester.pump();
    await tester.tap(find.text('Simpan'));
    expect(calls, 1);
    pending.completeError(StateError('offline'));
    await tester.pump();
    expect(find.textContaining('Gagal menyimpan'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
  test('Quiz mean weights persisted attempts, including zero scores', () {
    expect(weightedQuizScore([progress(1, 100), progress(3, 0)]), 25);
    expect(weightedQuizScore([]), isNull);
    expect(weightedQuizScore([progress(0, null)]), isNull);
    expect(() => weightedQuizScore([progress(1, null)]), throwsFormatException);
    expect(
      () => weightedQuizScore([progress(1, double.nan)]),
      throwsFormatException,
    );
  });

  testWidgets('Empty statistics show real zero and no quiz attempts', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          flashcardReviewCountProvider.overrideWith((ref) async => 0),
          materialsListProvider.overrideWith((ref) async => []),
          quizProgressProvider.overrideWith((ref) async => {}),
        ],
        child: const MaterialApp(home: Scaffold(body: ProfileStatistics())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('0'), findsOneWidget);
    expect(find.text('Belum latihan'), findsOneWidget);
    expect(find.text('Flashcard direview: 0'), findsOneWidget);
    expect(find.text('0%'), findsNothing);
  });

  testWidgets('Loading and errors never show dummy statistics; retry works', (
    tester,
  ) async {
    final pending = Completer<Map<String, QuizProgressModel>>();
    var calls = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          flashcardReviewCountProvider.overrideWith((ref) async => 0),
          materialsListProvider.overrideWith((ref) async {
            if (++calls == 1) throw StateError('offline');
            return [];
          }),
          quizProgressProvider.overrideWith((ref) => pending.future),
        ],
        child: const MaterialApp(home: Scaffold(body: ProfileStatistics())),
      ),
    );
    await tester.pump();
    expect(find.text('Gagal memuat'), findsOneWidget);
    expect(find.text('Memuat...'), findsOneWidget);
    expect(find.text('0'), findsNothing);
    await tester.tap(find.text('Coba lagi'));
    await tester.pump();
    await tester.pump();
    expect(find.text('0'), findsOneWidget);
    pending.completeError(StateError('offline'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Gagal memuat'), findsOneWidget);
    expect(find.text('Belum latihan'), findsNothing);
  });
}
