import '../../../core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../home/presentation/home_screen.dart' show materialsListProvider;
import 'chat_controller.dart';

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      return const Text('...', style: TextStyle(fontSize: 15, height: 1.4));
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final phase = (_controller.value + index / 3) % 1;
            final scale = 0.75 + 0.25 * (1 - (phase - 0.5).abs() * 2);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.scale(
                scale: scale,
                child: Opacity(opacity: scale, child: child),
              ),
            );
          }),
        );
      },
      child: const SizedBox(
        width: 6,
        height: 6,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

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
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.materialId != widget.materialId) {
      _textController.clear();
      Future.microtask(() {
        if (mounted) {
          ref
              .read(chatControllerProvider.notifier)
              .initSession(widget.materialId);
        }
      });
    }
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
    final materials = ref.watch(materialsListProvider).valueOrNull ?? [];
    String? materialTitle;
    for (final material in materials) {
      if (material.id == widget.materialId) {
        materialTitle = material.title;
        break;
      }
    }

    // Otomatis scroll ke bawah tiap ada pesan/ketikan baru
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      appBar: AppBar(
        title: Text(
          materialTitle == null ? 'AI Tutor' : 'AI Tutor · $materialTitle',
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppColors.charcoal,
        foregroundColor: Colors.white,
      ),
      body: chatState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (chatState.error != null)
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: SelectableText(chatState.error!),
                      ),
                      TextButton(
                        onPressed: () => chatState.historyError
                            ? controller.initSession(widget.materialId)
                            : controller.clearError(),
                        child: Text(
                          chatState.historyError
                              ? 'Coba muat riwayat lagi'
                              : 'Tutup pesan gagal',
                        ),
                      ),
                    ],
                  ),
                if (chatState.sessionId == null && chatState.error == null)
                  const Text('Belum ada riwayat untuk materi ini.'),
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
                                ? AppColors.lavenderCard
                                : const Color(0xFFFFFFFF),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(isUser ? 16 : 0),
                              bottomRight: Radius.circular(isUser ? 0 : 16),
                            ),
                          ),
                          child:
                              msg.content.isEmpty &&
                                  !isUser &&
                                  chatState.isTyping
                              ? const _TypingIndicator()
                              : Text(
                                  msg.content,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    height: 1.4,
                                  ),
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
                            : AppColors.charcoal,
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
