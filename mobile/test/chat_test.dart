import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tugas_akhir_mobpro/features/tutor_chat/domain/chat_model.dart';
import 'package:tugas_akhir_mobpro/features/tutor_chat/presentation/chat_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tugas_akhir_mobpro/features/tutor_chat/data/chat_repository.dart';

class SavedChatRepository extends ChatRepository {
  int created = 0;
  SavedChatRepository() : super(Dio());

  @override
  Future<List<ChatSession>> getSessions(String materialId) async => [
    ChatSession(id: 'saved', title: 'Saved question'),
    if (created > 0) ChatSession(id: 'new', title: 'Chat Baru'),
  ];

  @override
  Future<List<ChatMessage>> getHistory(String sessionId) async =>
      sessionId == 'saved'
      ? [ChatMessage(role: 'assistant', content: 'Saved answer')]
      : [];

  @override
  Future<String> createSession(String materialId) async {
    created++;
    return 'new';
  }
}

void main() {
  testWidgets(
    'opening resumes saved history; Chat Baru alone creates session',
    (tester) async {
      final repository = SavedChatRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [chatRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: ChatScreen(materialId: 'material')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Saved answer'), findsOneWidget);
      expect(repository.created, 0);
      await tester.tap(find.text('Chat Baru'));
      await tester.pumpAndSettle();
      expect(repository.created, 1);
      expect(find.text('Saved answer'), findsNothing);
    },
  );
  test('UTF8 and SSE survive every byte boundary and multiline data', () async {
    final bytes = utf8.encode(
      ': keepalive\r\ndata: {"text":\r\ndata: "你好 🌍"}\r\n\r\ndata: [DONE]\r\n\r\n',
    );
    for (var boundary = 1; boundary < bytes.length; boundary++) {
      expect(
        await decodeChatStream(
          Stream.fromIterable([
            bytes.sublist(0, boundary),
            bytes.sublist(boundary),
          ]),
        ).toList(),
        ['你好 🌍'],
      );
    }
  });
  test('server error is terminal and visible', () async {
    final stream = decodeChatStream(
      Stream.value(utf8.encode('data: {"error":"failed"}\n\ndata: [DONE]\n\n')),
    );
    await expectLater(
      stream,
      emitsError(predicate((e) => e.toString().contains('failed'))),
    );
  });
  test(
    'truncated and malformed responses fail instead of losing data',
    () async {
      for (final body in [
        'data: {"text":"partial"}\n\n',
        'data: broken\n\n',
        'data: {"text":',
      ]) {
        await expectLater(
          decodeChatStream(Stream.value(utf8.encode(body))).toList(),
          throwsFormatException,
        );
      }
    },
  );
}
