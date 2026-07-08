import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String requestId;
  const ChatScreen({super.key, required this.requestId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<String> _quickReplies = [
    "Lastiğim patladı",
    "Konumum doğru",
    "Yol kenarındayım",
    "Gelmeye hazır mısınız?",
  ];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String content) async {
    if (content.trim().isEmpty) return;
    
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    try {
      await ref.read(requestRepositoryProvider).sendMessage(
        widget.requestId,
        user.id,
        content.trim(),
      );
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final requestAsync = ref.watch(requestStatusProvider(widget.requestId));
    final messagesAsync = ref.watch(messagesStreamProvider(widget.requestId));

    final user = userAsync.value;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Auto-scroll on new message
    messagesAsync.whenData((_) => _scrollToBottom());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: requestAsync.when(
          loading: () => const Text('Yükleniyor...', style: TextStyle(color: AppColors.textPrimary)),
          error: (err, st) => const Text('Sohbet', style: TextStyle(color: AppColors.textPrimary)),
          data: (request) {
            // Get driver name if assigned
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Çekici ile Sohbet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                Text(
                  request.status.dbValue.toUpperCase(),
                  style: const TextStyle(fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.w600),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_in_talk, color: AppColors.accent),
            tooltip: 'Güvenli VoIP Arama',
            onPressed: () => context.push('/customer/call/${widget.requestId}'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Message List
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
              error: (err, st) => Center(child: Text('Hata: $err', style: const TextStyle(color: AppColors.error))),
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 48, color: AppColors.border),
                        SizedBox(height: 12),
                        Text(
                          'Sürücüye ilk mesajınızı gönderin.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == user.id;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMe ? AppColors.primary : AppColors.surface,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isMe ? 16 : 0),
                            bottomRight: Radius.circular(isMe ? 0 : 16),
                          ),
                          border: isMe ? null : Border.all(color: AppColors.border),
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        child: Text(
                          message.content,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            height: 1.3,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Quick Replies
          Container(
            height: 48,
            color: AppColors.background,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _quickReplies.length,
              itemBuilder: (context, index) {
                final reply = _quickReplies[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: InkWell(
                    onTap: () => _sendMessage(reply),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        reply,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Input Bar
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppColors.cardBackground,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Mesajınızı yazın...',
                        hintStyle: const TextStyle(color: AppColors.border),
                        filled: true,
                        fillColor: AppColors.surface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: AppColors.accent, width: 1),
                        ),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (val) => _sendMessage(val),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _sendMessage(_messageController.text),
                    icon: const Icon(Icons.send, color: AppColors.accent),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
