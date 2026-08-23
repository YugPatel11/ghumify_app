import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/models/chat_message_model.dart';

/// Styled chat bubble for user and AI messages
class ChatBubble extends StatelessWidget {
  final ChatMessageModel message;
  final VoidCallback? onApplyChanges;

  const ChatBubble({
    super.key,
    required this.message,
    this.onApplyChanges,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 48 : 0,
        right: isUser ? 0 : 48,
        bottom: AppTokens.md,
      ),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Role label
          Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 8, right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isUser) ...[
                  const Icon(Icons.auto_awesome, size: 12, color: AppColors.brand),
                  const SizedBox(width: 4),
                ],
                Text(
                  isUser ? 'YOU' : 'GHUMIFY AI',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isUser ? AppColors.textSoft : AppColors.brandDeep,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),

          // Message bubble
          ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(AppTokens.radiusLg),
              topRight: const Radius.circular(AppTokens.radiusLg),
              bottomLeft: Radius.circular(isUser ? AppTokens.radiusLg : 4),
              bottomRight: Radius.circular(isUser ? 4 : AppTokens.radiusLg),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.lg,
                  vertical: AppTokens.md,
                ),
                decoration: BoxDecoration(
                  color: isUser 
                      ? AppColors.brand
                      : AppColors.glassWhiteLight,
                  border: Border.all(
                    color: isUser 
                        ? Colors.transparent 
                        : AppColors.borderGlass
                  ),
                ),
                child: Text(
                  message.content,
                  style: TextStyle(
                    color: isUser ? Colors.white : AppColors.text,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),

          // Apply changes button (when AI returns modified itinerary)
          if (message.hasItineraryUpdate && onApplyChanges != null) ...[
            const SizedBox(height: AppTokens.sm),
            SizedBox(
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: ElevatedButton.icon(
                    onPressed: onApplyChanges,
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Apply Changes to Itinerary', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand.withOpacity(0.2),
                      foregroundColor: AppColors.brand,
                      side: BorderSide(color: AppColors.brand.withOpacity(0.5), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            ),
          ],

          // Timestamp
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 8, right: 8),
            child: Text(
              _formatTime(message.timestamp),
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
