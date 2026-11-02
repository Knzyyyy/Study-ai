import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tugas_akhir_mobpro/features/tutor_chat/domain/chat_model.dart';
import 'package:tugas_akhir_mobpro/features/tutor_chat/presentation/chat_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tugas_akhir_mobpro/features/tutor_chat/data/chat_repository.dart';
import 'package:tugas_akhir_mobpro/features/tutor_chat/presentation/chat_controller.dart';

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

class SendChatRepository extends ChatRepository {
  SendChatRepository({required this.stream, required this.savedHistory})
    : super(Dio());

  final Stream<String> stream;
  final List<ChatMessage> savedHistory;
  int historyReads = 0;

  @override
  Future<List<ChatSession>> getSessions(String materialId) async => [
    ChatSession(id: 'session', title: 'Saved question'),
  ];

  @override
  Future<List<ChatMessage>> getHistory(String sessionId) async {
    historyReads++;
    return savedHistory;
  }

  @override
  Stream<String> sendMessageStream(
    String sessionId,
    String content, {
    CancelToken? cancelToken,
  }) => stream;
}

class DelayedPersistingChatRepository extends SendChatRepository {
  DelayedPersistingChatRepository()
    : super(
        stream: Stream<String>.error(const FormatException('connection lost')),
        savedHistory: [
          ChatMessage(role: 'user', content: 'Pertanyaan'),
          ChatMessage(role: 'assistant', content: 'Jawaban tersimpan'),
        ],
      );

  @override
  Future<List<ChatMessage>> getHistory(String sessionId) async {
    historyReads++;
    return historyReads <= 2 ? [] : savedHistory;
  }
}

void main() {
  testWidgets('opening resumes saved history without new chat controls', (
    tester,
  ) async {
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
    expect(repository.created, 0);
    expect(find.text('Chat Baru'), findsNothing);
    expect(find.byType(DropdownButton<String>), findsNothing);
  });
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

  test(
    'keeps streamed answer without making another history request',
    () async {
      final repository = SendChatRepository(
        stream: Stream.fromIterable(['Jawaban ', 'AI']),
        savedHistory: const [],
      );
      final controller = ChatController(repository);
      await controller.initSession('material');
      final initialHistoryReads = repository.historyReads;

      await controller.sendMessage('Pertanyaan');

      expect(controller.state.messages.map((message) => message.content), [
        'Pertanyaan',
        'Jawaban AI',
      ]);
      expect(controller.state.error, isNull);
      expect(repository.historyReads, initialHistoryReads);
      controller.dispose();
    },
  );

  test(
    'recovers the saved answer when the stream ends with an error',
    () async {
      final repository = SendChatRepository(
        stream: Stream<String>.error(const FormatException('connection lost')),
        savedHistory: [
          ChatMessage(role: 'user', content: 'Pertanyaan'),
          ChatMessage(role: 'assistant', content: 'Jawaban tersimpan'),
        ],
      );
      final controller = ChatController(repository);
      await controller.initSession('material');

      await controller.sendMessage('Pertanyaan');

      expect(controller.state.messages.last.content, 'Jawaban tersimpan');
      expect(controller.state.error, isNull);
      controller.dispose();
    },
  );

  test('waits for persistence before showing a stream failure', () async {
    final repository = DelayedPersistingChatRepository();
    final controller = ChatController(repository);
    await controller.initSession('material');

    await controller.sendMessage('Pertanyaan');

    expect(controller.state.messages.last.content, 'Jawaban tersimpan');
    expect(controller.state.error, isNull);
    expect(repository.historyReads, 3);
    controller.dispose();
  });
}
