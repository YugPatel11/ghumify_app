import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/providers/group_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/group_model.dart';
import '../../../core/models/group_invitation_model.dart';
import 'create_group_screen.dart';
import 'group_detail_screen.dart';
import '../../../core/widgets/translated_text.dart';

/// Groups list screen showing all groups and pending invitations
class GroupsListScreen extends StatefulWidget {
  const GroupsListScreen({super.key});

  @override
  State<GroupsListScreen> createState() => _GroupsListScreenState();
}

class _GroupsListScreenState extends State<GroupsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GroupProvider>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Tr(
          'Groups',
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        backgroundColor: AppColors.bgElevated,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToCreateGroup(context),
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.group_add_rounded),
        label: Tr(
          'New Group',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
      ),
      body: Consumer<GroupProvider>(
        builder: (context, provider, _) {
          final invitations = provider.invitations;
          final groups = provider.groups;

          if (provider.isLoading && groups.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.brand),
            );
          }

          if (groups.isEmpty && invitations.isEmpty) {
            return _buildEmptyState();
          }

          return ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.md,
              vertical: AppTokens.sm,
            ),
            children: [
              // Pending invitations banner
              if (invitations.isNotEmpty) ...[
                _buildSectionHeader('Pending Invitations', invitations.length),
                const SizedBox(height: AppTokens.sm),
                ...invitations.map((inv) => _InvitationCard(invitation: inv)),
                const SizedBox(height: AppTokens.lg),
              ],

              // Groups list
              if (groups.isNotEmpty) ...[
                _buildSectionHeader('My Groups', groups.length),
                const SizedBox(height: AppTokens.sm),
                ...groups.map((group) => _GroupCard(
                      group: group,
                      onTap: () => _openGroup(context, group),
                    )),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      children: [
        Tr(
          title,
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textSoft,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.brandSoft,
            borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          ),
          child: Text(
            '$count',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.brand,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.brandSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.groups_rounded,
                size: 40,
                color: AppColors.brand,
              ),
            ),
            const SizedBox(height: AppTokens.lg),
            Tr(
              'No Groups Yet',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: AppTokens.sm),
            Tr(
              'Create a group to plan trips together\nwith friends and family',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: AppColors.textSoft,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToCreateGroup(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
    );
  }

  void _openGroup(BuildContext context, GroupModel group) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GroupDetailScreen(groupId: group.id),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// GROUP CARD
// ═══════════════════════════════════════════════════════════════

class _GroupCard extends StatelessWidget {
  final GroupModel group;
  final VoidCallback onTap;

  const _GroupCard({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.uid ?? '';
    final unread = group.getUnreadCount(userId);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTokens.sm),
        padding: const EdgeInsets.all(AppTokens.md),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(color: AppColors.border, width: 0.5),
          boxShadow: AppTokens.shadow(level: 1),
        ),
        child: Row(
          children: [
            // Group avatar
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              ),
              child: Center(
                child: Text(
                  _getInitials(group.name),
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppTokens.md),

            // Group info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    group.lastMessageText != null
                        ? '${group.lastMessageSenderName}: ${group.lastMessageText}'
                        : '${group.memberIds.length} members',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Unread badge + time
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (group.lastMessageAt != null)
                  Text(
                    _formatTime(group.lastMessageAt!),
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: unread > 0 ? AppColors.brand : AppColors.textMuted,
                      fontWeight:
                          unread > 0 ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                if (unread > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.brand,
                      borderRadius:
                          BorderRadius.circular(AppTokens.radiusPill),
                    ),
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}';
  }
}

// ═══════════════════════════════════════════════════════════════
// INVITATION CARD
// ═══════════════════════════════════════════════════════════════

class _InvitationCard extends StatelessWidget {
  final GroupInvitationModel invitation;

  const _InvitationCard({required this.invitation});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.sm),
      padding: const EdgeInsets.all(AppTokens.md),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mail_rounded,
              color: AppColors.accentDeep,
              size: 22,
            ),
          ),
          const SizedBox(width: AppTokens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invitation.groupName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Invited by ${invitation.inviterName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppColors.textSoft,
                  ),
                ),
              ],
            ),
          ),
          // Accept / Decline buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MiniButton(
                label: 'Decline',
                color: AppColors.textMuted,
                onTap: () {
                  context
                      .read<GroupProvider>()
                      .declineInvitation(invitation.id);
                },
              ),
              const SizedBox(width: 8),
              _MiniButton(
                label: 'Accept',
                color: AppColors.brand,
                filled: true,
                onTap: () {
                  context
                      .read<GroupProvider>()
                      .acceptInvitation(invitation.id);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  const _MiniButton({
    required this.label,
    required this.color,
    this.filled = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: filled ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          border: filled ? null : Border.all(color: color, width: 1),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: filled ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}
