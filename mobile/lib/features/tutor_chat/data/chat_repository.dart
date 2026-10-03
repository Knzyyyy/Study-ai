import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/chat_model.dart';

Stream<String> decodeChatStream(Stream<List<int>> bytes) async* {
  final data = <String>[];
  await for (final line
      in bytes.transform(utf8.decoder).transform(const LineSplitter())) {
    if (line.isEmpty) {
      if (data.isEmpty) continue;
      final payload = data.join('\n');
      data.clear();
      if (payload == '[DONE]') return;
      final event = jsonDecode(payload) as Map<String, dynamic>;
      if (event['error'] != null) throw Exception(event['error']);
      if (event['text'] is String) yield event['text'] as String;
    } else if (line == 'data' || line.startsWith('data:')) {
      var value = line == 'data' ? '' : line.substring(5);
      if (value.startsWith(' ')) value = value.substring(1);
      data.add(value);
    }
  }
  throw const FormatException(
    'Respons terputus sebelum selesai. Muat ulang riwayat.',
  );
}

class ChatRepository {
  final Dio _dio;
  ChatRepository(this._dio);

  Future<List<ChatSession>> getSessions(String materialId) async {
    final response = await _dio.get(
      '/chat/sessions',
      queryParameters: {'material_id': materialId},
    );
    return (response.data as List).map((e) => ChatSession.fromJson(e)).toList();
  }

  Future<String> createSession(String materialId) async {
    final response = await _dio.post(
      '/chat/sessions',
      data: {'material_id': materialId},
    );
    return response.data['id'];
  }

  Future<List<ChatMessage>> getHistory(String sessionId) async {
    final response = await _dio.get('/chat/sessions/$sessionId/messages');
    return (response.data as List).map((e) => ChatMessage.fromJson(e)).toList();
  }

  Stream<String> sendMessageStream(
    String sessionId,
    String content, {
    CancelToken? cancelToken,
  }) async* {
    final response = await _dio.post<ResponseBody>(
      '/chat/sessions/$sessionId/messages',
      data: {'content': content},
      cancelToken: cancelToken,
      options: Options(responseType: ResponseType.stream),
    );
    yield* decodeChatStream(response.data!.stream);
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(dioProvider));
});
