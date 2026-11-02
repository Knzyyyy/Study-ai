import '../../../core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../home/presentation/home_screen.dart' show materialsListProvider;
import '../../materials/domain/material_model.dart';
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

  Future<void> _chooseMaterial(List<MaterialModel> materials) async {
    final readyMaterials = materials.where((item) => item.status == 'done');
    final selected = await showModalBottomSheet<MaterialModel>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            const Text(
              'Pilih materi',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            for (final material in readyMaterials)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: const CircleAvatar(
                  backgroundColor: AppColors.lavenderSoft,
                  child: Icon(
                    Icons.description_outlined,
                    color: AppColors.primaryDark,
                  ),
                ),
                title: Text(
                  material.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(material.fileType.toUpperCase()),
                onTap: () => Navigator.pop(context, material),
              ),
            if (!readyMaterials.any((_) => true))
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('Belum ada materi yang siap dipelajari.'),
              ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      context.go('/materials/${selected.id}/chat');
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
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          tooltip: 'Kembali',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI Tutor',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            Text(
              materialTitle ?? 'Belajar dari materi pilihanmu',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.inkSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: OutlinedButton(
              onPressed: () => _chooseMaterial(materials),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.borderLine),
                shape: const StadiumBorder(),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text(
                'Ganti materi',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
      body: chatState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: chatState.messages.isEmpty && !chatState.isLoading
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              chatState.error ??
                                  'Tanyakan apa saja tentang materi ini.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.inkSecondary,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                          itemCount: chatState.messages.length,
                          itemBuilder: (context, index) {
                            final msg = chatState.messages[index];
                            final isUser = msg.role == 'user';
                            return Align(
                              alignment: isUser
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 16,
                                ),
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.sizeOf(context).width * .82,
                                ),
                                decoration: BoxDecoration(
                                  color: isUser
                                      ? AppColors.charcoal
                                      : Colors.white,
                                  border: isUser
                                      ? null
                                      : Border.all(color: AppColors.borderLine),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(24),
                                    topRight: const Radius.circular(24),
                                    bottomLeft: Radius.circular(
                                      isUser ? 24 : 6,
                                    ),
                                    bottomRight: Radius.circular(
                                      isUser ? 6 : 24,
                                    ),
                                  ),
                                  boxShadow: isUser
                                      ? null
                                      : const [
                                          BoxShadow(
                                            color: Color(0x08000000),
                                            blurRadius: 8,
                                            offset: Offset(0, 3),
                                          ),
                                        ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!isUser) ...[
                                      const Row(
                                        children: [
                                          Icon(
                                            Icons.auto_awesome_rounded,
                                            color: AppColors.primary,
                                            size: 16,
                                          ),
                                          SizedBox(width: 7),
                                          Text(
                                            'AI Tutor',
                                            style: TextStyle(
                                              color: AppColors.primary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                    if (msg.content.isEmpty &&
                                        !isUser &&
                                        chatState.isTyping)
                                      const _TypingIndicator()
                                    else if (isUser)
                                      SelectableText(
                                        msg.content,
                                        style: TextStyle(
                                          fontSize: 14,
                                          height: 1.6,
                                          color: Colors.white,
                                        ),
                                      )
                                    else
                                      MarkdownBody(
                                        data: msg.content,
                                        selectable: true,
                                        styleSheet: MarkdownStyleSheet(
                                          p: const TextStyle(
                                            fontSize: 14,
                                            height: 1.6,
                                            color: AppColors.ink,
                                          ),
                                          pPadding: const EdgeInsets.only(
                                            bottom: 10,
                                          ),
                                          strong: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.ink,
                                          ),
                                          em: const TextStyle(
                                            fontStyle: FontStyle.italic,
                                          ),
                                          listBullet: const TextStyle(
                                            fontSize: 14,
                                            height: 1.6,
                                            color: AppColors.inkSecondary,
                                          ),
                                          h1: const TextStyle(
                                            fontSize: 20,
                                            height: 1.35,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.ink,
                                          ),
                                          h2: const TextStyle(
                                            fontSize: 18,
                                            height: 1.4,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.ink,
                                          ),
                                          h3: const TextStyle(
                                            fontSize: 16,
                                            height: 1.45,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.ink,
                                          ),
                                          code: TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 13,
                                            color: AppColors.charcoal,
                                            backgroundColor:
                                                AppColors.surfaceSubtle,
                                          ),
                                          codeblockDecoration: BoxDecoration(
                                            color: AppColors.surfaceSubtle,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          blockquote: const TextStyle(
                                            fontSize: 14,
                                            height: 1.6,
                                            color: AppColors.inkSecondary,
                                          ),
                                          blockquoteDecoration:
                                              const BoxDecoration(
                                                border: Border(
                                                  left: BorderSide(
                                                    color: AppColors.primary,
                                                    width: 3,
                                                  ),
                                                ),
                                              ),
                                          horizontalRuleDecoration:
                                              const BoxDecoration(
                                                border: Border(
                                                  top: BorderSide(
                                                    color: AppColors.borderLine,
                                                  ),
                                                ),
                                              ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                if (chatState.error != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                    decoration: BoxDecoration(
                      color: AppColors.peachSoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            chatState.error!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.inkSecondary,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Tutup pesan',
                          onPressed: controller.clearError,
                          icon: const Icon(Icons.close_rounded, size: 19),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    12 + MediaQuery.paddingOf(context).bottom,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                      top: BorderSide(color: AppColors.borderLine),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          enabled:
                              !chatState.isTyping &&
                              chatState.sessionId != null,
                          minLines: 1,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: chatState.isTyping
                                ? 'AI sedang mengetik...'
                                : 'Tanya seputar materi...',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(28),
                              borderSide: const BorderSide(
                                color: AppColors.borderLine,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(28),
                              borderSide: const BorderSide(
                                color: AppColors.borderLine,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(28),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                          ),
                          onSubmitted: (_) {
                            _sendMessage(controller, chatState.isTyping);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: chatState.isTyping
                            ? AppColors.inkMeta
                            : AppColors.charcoal,
                        radius: 24,
                        child: IconButton(
                          icon: const Icon(Icons.send, color: Colors.white),
                          onPressed:
                              chatState.isTyping || chatState.sessionId == null
                              ? null
                              : () => _sendMessage(
                                  controller,
                                  chatState.isTyping,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  void _sendMessage(ChatController controller, bool isTyping) {
    final text = _textController.text.trim();
    if (text.isEmpty || isTyping) return;
    controller.sendMessage(text);
    _textController.clear();
  }
}
