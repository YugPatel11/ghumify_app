import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/providers/group_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/group_message_model.dart';

/// WhatsApp-style group chat tab
class GroupChatTab extends StatefulWidget {
  final String groupId;

  const GroupChatTab({super.key, required this.groupId});

  @override
  State<GroupChatTab> createState() => _GroupChatTabState();
}

class _GroupChatTabState extends State<GroupChatTab> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthProvider>().user?.uid ?? '';

    return Column(
      children: [
        // Messages list (reversed for bottom-up display)
        Expanded(
          child: Consumer<GroupProvider>(
            builder: (context, provider, _) {
              final messages = provider.currentMessages;

              if (messages.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 48,
                        color: AppColors.textMuted.withOpacity(0.4),
                      ),
                      const SizedBox(height: AppTokens.md),
                      Text(
                        'No messages yet',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Start the conversation!',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: AppColors.textMuted.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.md,
                  vertical: AppTokens.sm,
                ),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final isMe = message.senderId == userId;
                  final showSender = !isMe &&
                      !message.isSystem &&
                      (index == messages.length - 1 ||
                          messages[index + 1].senderId != message.senderId);

                  return _MessageBubble(
                    message: message,
                    isMe: isMe,
                    showSender: showSender,
                  );
                },
              );
            },
          ),
        ),

        // Message input bar
        _buildInputBar(),
      ],
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: AppTokens.md,
        right: AppTokens.sm,
        top: AppTokens.sm,
        bottom: MediaQuery.of(context).padding.bottom + AppTokens.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        border: const Border(
          top: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Text field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.cardAlt,
                borderRadius: BorderRadius.circular(AppTokens.radiusXl),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: TextField(
                controller: _messageController,
                style: GoogleFonts.outfit(
                  color: AppColors.text,
                  fontSize: 15,
                ),
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: GoogleFonts.outfit(
                    color: AppColors.textMuted,
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTokens.sm),

          // Send button
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                gradient: AppColors.brandGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    context.read<GroupProvider>().sendMessage(widget.groupId, text);
    _messageController.clear();
  }
}

// ═══════════════════════════════════════════════════════════════
// MESSAGE BUBBLE
// ═══════════════════════════════════════════════════════════════

class _MessageBubble extends StatelessWidget {
  final GroupMessageModel message;
  final bool isMe;
  final bool showSender;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.showSender,
  });

  @override
  Widget build(BuildContext context) {
    // System messages
    if (message.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.cardAlt,
              borderRadius: BorderRadius.circular(AppTokens.radiusPill),
            ),
            child: Text(
              message.content,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Sender name
          if (showSender && !isMe)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 3),
              child: Text(
                message.senderName,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brand,
                ),
              ),
            ),

          // Bubble
          Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isMe ? AppColors.brand : AppColors.card,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                border: isMe
                    ? null
                    : Border.all(color: AppColors.border, width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    message.isDeletedForEveryone
                        ? '🚫 This message was deleted'
                        : message.content,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: isMe ? Colors.white : AppColors.text,
                      fontStyle: message.isDeletedForEveryone
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatTime(message.createdAt),
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      color: isMe
                          ? Colors.white.withOpacity(0.7)
                          : AppColors.textMuted,
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

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
