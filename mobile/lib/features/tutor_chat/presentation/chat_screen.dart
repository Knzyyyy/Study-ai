import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'chat_controller.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String materialId;

  const ChatScreen({super.key, required this.materialId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Inisialisasi sesi pas halaman dibuka
    Future.microtask(() {
      if (mounted) {
        ref
            .read(chatControllerProvider.notifier)
            .initSession(widget.materialId);
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (mounted && _scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatControllerProvider);
    final controller = ref.read(chatControllerProvider.notifier);

    // Otomatis scroll ke bawah tiap ada pesan/ketikan baru
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Tutor'),
        actions: [
          TextButton(
            onPressed: chatState.isLoading || chatState.isTyping
                ? null
                : () => controller.initSession(
                    widget.materialId,
                    newSession: true,
                  ),
            child: const Text(
              'Chat Baru',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
      ),
      body: chatState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (chatState.sessions.isNotEmpty)
                  DropdownButton<String>(
                    isExpanded: true,
                    value: chatState.sessionId,
                    hint: const Text('Pilih riwayat'),
                    items: chatState.sessions
                        .map(
                          (session) => DropdownMenuItem(
                            value: session.id,
                            child: Text(
                              '${session.title}${session.date == null ? '' : ' · ${session.date!.toLocal()}'}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: chatState.isTyping
                        ? null
                        : (id) {
                            if (id != null) {
                              controller.initSession(
                                widget.materialId,
                                sessionId: id,
                              );
                            }
                          },
                  ),
                if (chatState.error != null)
                  Column(
                    children: [
                      Text(chatState.error!),
                      TextButton(
                        onPressed: () =>
                            controller.initSession(widget.materialId),
                        child: const Text('Muat ulang riwayat'),
                      ),
                    ],
                  ),
                if (chatState.sessionId == null && chatState.error == null)
                  const Text('Belum ada riwayat. Pilih Chat Baru.'),
                // 1. Area Balon Chat
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: chatState.messages.length,
                    itemBuilder: (context, index) {
                      final msg = chatState.messages[index];
                      final isUser = msg.role == 'user';

                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          decoration: BoxDecoration(
                            color: isUser
                                ? Colors.blue.shade100
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(isUser ? 16 : 0),
                              bottomRight: Radius.circular(isUser ? 0 : 16),
                            ),
                          ),
                          child: Text(
                            msg.content.isEmpty ? "..." : msg.content,
                            style: const TextStyle(fontSize: 15, height: 1.4),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // 2. Area Kotak Ketik (Input)
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          enabled:
                              !chatState.isTyping &&
                              chatState.sessionId != null &&
                              chatState.error == null,
                          decoration: InputDecoration(
                            hintText: chatState.isTyping
                                ? 'AI sedang mengetik...'
                                : 'Tanya seputar materi...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: (_) {
                            if (_textController.text.isNotEmpty) {
                              controller.sendMessage(_textController.text);
                              _textController.clear();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: chatState.isTyping
                            ? Colors.grey
                            : Colors.blue.shade900,
                        radius: 24,
                        child: IconButton(
                          icon: const Icon(Icons.send, color: Colors.white),
                          onPressed:
                              chatState.isTyping ||
                                  chatState.sessionId == null ||
                                  chatState.error != null
                              ? null
                              : () {
                                  if (_textController.text.isNotEmpty) {
                                    controller.sendMessage(
                                      _textController.text,
                                    );
                                    _textController.clear();
                                  }
                                },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
