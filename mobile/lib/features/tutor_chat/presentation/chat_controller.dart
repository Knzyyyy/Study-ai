import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/chat_repository.dart';
import '../domain/chat_model.dart';

class ChatState {
  final String? sessionId;
  final List<ChatSession> sessions;
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isTyping;
  final String? error;

  ChatState({
    this.sessionId,
    this.sessions = const [],
    this.messages = const [],
    this.isLoading = false,
    this.isTyping = false,
    this.error,
  });

  ChatState copyWith({
    String? sessionId,
    List<ChatSession>? sessions,
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isTyping,
    String? error,
  }) => ChatState(
    sessionId: sessionId ?? this.sessionId,
    sessions: sessions ?? this.sessions,
    messages: messages ?? this.messages,
    isLoading: isLoading ?? this.isLoading,
    isTyping: isTyping ?? this.isTyping,
    error: error,
  );
}

class ChatController extends StateNotifier<ChatState> {
  final ChatRepository _repository;
  int _generation = 0;
  String? _materialId;
  CancelToken? _cancelToken;

  ChatController(this._repository) : super(ChatState());

  Future<void> initSession(
    String materialId, {
    String? sessionId,
    bool newSession = false,
  }) async {
    final generation = ++_generation;
    _cancelToken?.cancel();
    if (_materialId != materialId) state = ChatState();
    _materialId = materialId;
    state = state.copyWith(isLoading: true, isTyping: false);
    try {
      var sessions = await _repository.getSessions(materialId);
      if (!mounted || generation != _generation) return;
      final selected = newSession
          ? await _repository.createSession(materialId)
          : sessionId ??
                state.sessionId ??
                (sessions.isEmpty ? null : sessions.first.id);
      final history = selected == null
          ? <ChatMessage>[]
          : await _repository.getHistory(selected);
      if (newSession) sessions = await _repository.getSessions(materialId);
      if (!mounted || generation != _generation) return;
      state = ChatState(
        sessionId: selected,
        sessions: sessions,
        messages: history,
      );
    } catch (e) {
      if (mounted && generation == _generation) {
        state = state.copyWith(
          isLoading: false,
          error: 'Gagal memuat chat: $e',
        );
      }
    }
  }

  Future<void> sendMessage(String text) async {
    if (state.sessionId == null ||
        state.isLoading ||
        state.isTyping ||
        state.error != null ||
        text.trim().isEmpty) {
      return;
    }
    final sessionId = state.sessionId!;
    final generation = _generation;
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(role: 'user', content: text),
        ChatMessage(role: 'assistant', content: ''),
      ],
      isTyping: true,
    );
    try {
      await for (final chunk in _repository.sendMessageStream(
        sessionId,
        text,
        cancelToken: cancelToken,
      )) {
        if (!mounted || generation != _generation) return;
        final messages = List<ChatMessage>.from(state.messages);
        messages[messages.length - 1] = messages.last.copyWith(
          content: messages.last.content + chunk,
        );
        state = state.copyWith(messages: messages);
      }
    } catch (e) {
      if (mounted && generation == _generation) {
        state = state.copyWith(error: 'Gagal menerima respons: $e');
      }
    } finally {
      if (mounted && generation == _generation) {
        state = state.copyWith(isTyping: false, error: state.error);
      }
    }
  }

  @override
  void dispose() {
    ++_generation;
    _cancelToken?.cancel();
    super.dispose();
  }
}

final chatControllerProvider =
    StateNotifierProvider.autoDispose<ChatController, ChatState>((ref) {
      return ChatController(ref.watch(chatRepositoryProvider));
    });
