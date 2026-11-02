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
  final bool historyError;

  ChatState({
    this.sessionId,
    this.sessions = const [],
    this.messages = const [],
    this.isLoading = false,
    this.isTyping = false,
    this.error,
    this.historyError = false,
  });

  ChatState copyWith({
    String? sessionId,
    List<ChatSession>? sessions,
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isTyping,
    String? error,
    bool clearError = false,
    bool? historyError,
  }) => ChatState(
    sessionId: sessionId ?? this.sessionId,
    sessions: sessions ?? this.sessions,
    messages: messages ?? this.messages,
    isLoading: isLoading ?? this.isLoading,
    isTyping: isTyping ?? this.isTyping,
    error: clearError ? null : error ?? this.error,
    historyError: historyError ?? this.historyError,
  );
}

class ChatController extends StateNotifier<ChatState> {
  final ChatRepository _repository;
  int _generation = 0;
  String? _materialId;
  CancelToken? _cancelToken;

  ChatController(this._repository) : super(ChatState());

  Future<void> initSession(String materialId) async {
    if (_materialId == materialId && (state.isLoading || state.isTyping))
      return;
    final generation = ++_generation;
    _cancelToken?.cancel();
    if (_materialId != materialId) state = ChatState();
    _materialId = materialId;
    state = state.copyWith(isLoading: true, isTyping: false);
    try {
      final sessions = await _repository.getSessions(materialId);
      if (!mounted || generation != _generation) return;
      final selected = sessions.isEmpty
          ? await _repository.createSession(materialId)
          : sessions.first.id;
      if (!mounted || generation != _generation) return;
      state = state.copyWith(sessionId: selected);
      final history = await _repository.getHistory(selected);
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
          error: 'Riwayat chat gagal dimuat. Periksa koneksi lalu coba lagi.',
          historyError: true,
        );
      }
    }
  }

  void clearError() {
    if (state.error != null) state = state.copyWith(clearError: true);
  }

  Future<void> sendMessage(String text) async {
    if (state.sessionId == null ||
        state.isLoading ||
        state.isTyping ||
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
      clearError: true,
      historyError: false,
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
      // The streamed response is already the source of truth for this turn.
      // Fetching history here created a second failure point after a successful
      // response and could show a misleading send error to the user.
    } catch (e) {
      if (mounted && generation == _generation) {
        try {
          // The server persists completed answers before closing the stream.
          // Wait briefly for persistence if the stream closes before the
          // server finishes writing the response.
          for (var attempt = 0; attempt < 8; attempt++) {
            if (attempt > 0) {
              await Future<void>.delayed(Duration(milliseconds: 500 * attempt));
            }
            if (!mounted || generation != _generation) return;
            final history = await _repository.getHistory(sessionId);
            if (!mounted || generation != _generation) return;
            final userMessageIndex = history.lastIndexWhere(
              (message) => message.role == 'user' && message.content == text,
            );
            final hasSavedAnswer =
                userMessageIndex >= 0 &&
                history
                    .skip(userMessageIndex + 1)
                    .any(
                      (message) =>
                          message.role == 'assistant' &&
                          message.content.trim().isNotEmpty,
                    );
            if (hasSavedAnswer) {
              state = state.copyWith(messages: history, clearError: true);
              return;
            }
          }
        } catch (_) {
          // Keep any partial response visible if history cannot be recovered.
        }

        if (!mounted || generation != _generation) return;
        final messages = List<ChatMessage>.from(state.messages);
        final hasPartialResponse =
            messages.isNotEmpty &&
            messages.last.role == 'assistant' &&
            messages.last.content.isNotEmpty;
        if (!hasPartialResponse &&
            messages.isNotEmpty &&
            messages.last.role == 'assistant') {
          messages.removeLast();
        }
        state = state.copyWith(
          messages: messages,
          error: hasPartialResponse
              ? 'Koneksi terputus. Sebagian jawaban mungkin belum lengkap.'
              : 'Respons gagal diterima. Periksa koneksi lalu coba lagi.',
          historyError: false,
        );
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
