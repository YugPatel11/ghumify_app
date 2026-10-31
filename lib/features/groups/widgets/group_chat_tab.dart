import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/providers/group_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/group_message_model.dart';

/// WhatsApp-style group chat tab with rich cards for stops and locations
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
                        'Start the conversation or share a place!',
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
        left: AppTokens.sm,
        right: AppTokens.sm,
        top: AppTokens.sm,
        bottom: MediaQuery.of(context).padding.bottom + AppTokens.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgElevated,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Action attachment button (+)
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.brand.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_rounded, color: AppColors.brand, size: 20),
            ),
            tooltip: 'Share location or trip stop',
            onPressed: () => _showAttachmentMenu(context),
          ),

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
          const SizedBox(width: AppTokens.xs),

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

  void _showAttachmentMenu(BuildContext context) {
    final provider = context.read<GroupProvider>();
    final itinerary = provider.currentItinerary;
    final stops = List<Map<String, dynamic>>.from(
      (itinerary?['stops'] as List<dynamic>? ?? []).map(
        (s) => Map<String, dynamic>.from(s as Map),
      ),
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(AppTokens.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Share to Chat',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: AppTokens.md),

              // Share Location Pin
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.pin_drop_rounded, color: AppColors.brand),
                ),
                title: Text(
                  'Share Current Location Pin',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                subtitle: Text(
                  'Post a one-time "I am here" map pin',
                  style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textMuted),
                ),
                onTap: () async {
                  Navigator.of(context).pop();
                  try {
                    await provider.shareCurrentLocationPin(widget.groupId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('📍 Location pin shared with group!'),
                          backgroundColor: AppColors.brand,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Could not share location: $e'),
                          backgroundColor: AppColors.error,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
              ),

              // Share Live Location
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.my_location_rounded, color: AppColors.success),
                ),
                title: Text(
                  'Share Live Location (1 Hour)',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                subtitle: Text(
                  'Broadcast real-time position updates',
                  style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textMuted),
                ),
                onTap: () async {
                  Navigator.of(context).pop();
                  try {
                    await provider.startLiveLocationSharing(
                      widget.groupId,
                      duration: const Duration(hours: 1),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('📡 Live location sharing started!'),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Could not start live location: $e'),
                          backgroundColor: AppColors.error,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
              ),

              // Share Itinerary Stop
              if (stops.isNotEmpty)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.route_rounded, color: AppColors.accent),
                  ),
                  title: Text(
                    'Share Itinerary Stop',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  subtitle: Text(
                    'Select a destination from the trip itinerary',
                    style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textMuted),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showStopPicker(context, provider, stops, itinerary?['city'] ?? 'Trip');
                  },
                ),

              const SizedBox(height: AppTokens.sm),
            ],
          ),
        );
      },
    );
  }

  void _showStopPicker(
    BuildContext context,
    GroupProvider provider,
    List<Map<String, dynamic>> stops,
    String city,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(AppTokens.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Stop to Share',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: AppTokens.md),
              ...stops.map((stop) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.place_rounded, color: AppColors.brand),
                  title: Text(
                    stop['name'] ?? 'Stop',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  subtitle: Text(
                    stop['startTime'] ?? '',
                    style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textMuted),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    provider.shareStopToChat(
                      groupId: widget.groupId,
                      stopData: stop,
                      city: city,
                    );
                  },
                );
              }),
            ],
          ),
        );
      },
    );
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
                maxWidth: MediaQuery.of(context).size.width * 0.78,
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
              child: _buildBubbleContent(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubbleContent(BuildContext context) {
    if (message.isDeletedForEveryone) {
      return Text(
        '🚫 This message was deleted',
        style: GoogleFonts.outfit(
          fontSize: 14,
          color: isMe ? Colors.white70 : AppColors.textMuted,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    // Rich Card: Location Pin
    if (message.isLocationPin) {
      final lat = (message.metadata?['latitude'] as num?)?.toDouble() ?? 0.0;
      final lng = (message.metadata?['longitude'] as num?)?.toDouble() ?? 0.0;
      final address = message.metadata?['address'] ?? message.metadata?['placeName'];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on_rounded,
                size: 20,
                color: isMe ? Colors.white : AppColors.brand,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Location Pin',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isMe ? Colors.white : AppColors.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            address != null ? '$address' : 'Coordinates: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: isMe ? Colors.white.withOpacity(0.9) : AppColors.textSoft,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.directions_rounded, size: 14),
            label: Text(
              'Open in Google Maps',
              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isMe ? Colors.white : AppColors.brand,
              foregroundColor: isMe ? AppColors.brand : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => _openMaps(lat, lng),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              _formatTime(message.createdAt),
              style: GoogleFonts.outfit(
                fontSize: 10,
                color: isMe ? Colors.white.withOpacity(0.7) : AppColors.textMuted,
              ),
            ),
          ),
        ],
      );
    }

    // Rich Card: Live Location Share
    if (message.type == 'live_location_share') {
      final lat = (message.metadata?['latitude'] as num?)?.toDouble() ?? 0.0;
      final lng = (message.metadata?['longitude'] as num?)?.toDouble() ?? 0.0;
      final durationMinutes = message.metadata?['durationMinutes'] ?? 60;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.sensors_rounded,
                size: 20,
                color: isMe ? Colors.white : AppColors.success,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Live Location (${durationMinutes}m)',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isMe ? Colors.white : AppColors.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            message.content,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: isMe ? Colors.white.withOpacity(0.9) : AppColors.textSoft,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.map_rounded, size: 14),
            label: Text(
              'View on Map',
              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isMe ? Colors.white : AppColors.brand,
              foregroundColor: isMe ? AppColors.brand : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => _openMaps(lat, lng),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              _formatTime(message.createdAt),
              style: GoogleFonts.outfit(
                fontSize: 10,
                color: isMe ? Colors.white.withOpacity(0.7) : AppColors.textMuted,
              ),
            ),
          ),
        ],
      );
    }

    // Rich Card: Itinerary Card
    if (message.isItineraryCard) {
      final stop = message.metadata?['stop'] as Map<String, dynamic>? ?? {};
      final stopName = stop['name'] ?? 'Stop';
      final startTime = stop['startTime'] ?? '';
      final description = stop['description'] ?? '';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.place_rounded, size: 18, color: Colors.white),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  stopName,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (startTime.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              startTime,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isMe ? Colors.white.withOpacity(0.85) : AppColors.brand,
              ),
            ),
          ],
          if (description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              description,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: isMe ? Colors.white.withOpacity(0.9) : AppColors.text,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              _formatTime(message.createdAt),
              style: GoogleFonts.outfit(
                fontSize: 10,
                color: isMe ? Colors.white.withOpacity(0.7) : AppColors.textMuted,
              ),
            ),
          ),
        ],
      );
    }

    // Standard Text Message
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          message.content,
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: isMe ? Colors.white : AppColors.text,
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
    );
  }

  Future<void> _openMaps(double lat, double lng) async {
    final webUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
    try {
      if (await canLaunchUrl(webUri)) {
        final ok = await launchUrl(webUri, mode: LaunchMode.externalApplication);
        if (ok) return;
      }
      if (await canLaunchUrl(geoUri)) {
        final ok = await launchUrl(geoUri);
        if (ok) return;
      }
      await launchUrl(webUri, mode: LaunchMode.platformDefault);
    } catch (_) {
      try {
        await launchUrl(webUri, mode: LaunchMode.platformDefault);
      } catch (_) {}
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
