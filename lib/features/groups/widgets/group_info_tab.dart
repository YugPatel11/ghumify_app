import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/providers/group_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/group_member_model.dart';

/// Group info tab: member list, roles, admin controls, leave/delete
class GroupInfoTab extends StatelessWidget {
  final String groupId;

  const GroupInfoTab({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    return Consumer2<GroupProvider, AuthProvider>(
      builder: (context, groupProvider, authProvider, _) {
        final group = groupProvider.currentGroup;
        final members = groupProvider.currentMembers;
        final userId = authProvider.user?.uid ?? '';

        if (group == null) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.brand),
          );
        }

        final isAdmin = group.isAdmin(userId);
        final isOwner = group.ownerId == userId;

        return ListView(
          padding: const EdgeInsets.all(AppTokens.md),
          children: [
            // Group info card
            _buildGroupInfoCard(group.name, group.description, members.length),

            const SizedBox(height: AppTokens.lg),

            // Add member (admin only)
            if (isAdmin) ...[
              _AddMemberSection(groupId: groupId),
              const SizedBox(height: AppTokens.lg),
            ],

            // Itinerary edit policy (admin only)
            if (isAdmin) ...[
              _PolicySection(groupId: groupId),
              const SizedBox(height: AppTokens.lg),
            ],

            // Members list
            _buildSectionTitle('Members', members.length),
            const SizedBox(height: AppTokens.sm),
            ...members.map((member) => _MemberTile(
                  member: member,
                  groupId: groupId,
                  currentUserId: userId,
                  isCurrentUserAdmin: isAdmin,
                  isCurrentUserOwner: isOwner,
                  groupOwnerId: group.ownerId,
                )),

            const SizedBox(height: AppTokens.xxl),

            // Leave group
            _ActionButton(
              label: 'Leave Group',
              icon: Icons.exit_to_app_rounded,
              color: AppColors.warning,
              onTap: () => _confirmLeave(context, groupProvider),
            ),

            // Delete group (owner only)
            if (isOwner) ...[
              const SizedBox(height: AppTokens.md),
              _ActionButton(
                label: 'Delete Group',
                icon: Icons.delete_forever_rounded,
                color: AppColors.error,
                onTap: () => _confirmDelete(context, groupProvider),
              ),
            ],

            const SizedBox(height: AppTokens.xxl),
          ],
        );
      },
    );
  }

  Widget _buildGroupInfoCard(String name, String description, int memberCount) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: AppTokens.shadow(level: 1),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(AppTokens.radiusLg),
            ),
            child: Center(
              child: Text(
                _getInitials(name),
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTokens.md),
          Text(
            name,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              description,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: AppColors.textSoft,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '$memberCount members',
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, int count) {
    return Row(
      children: [
        Text(
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

  String _getInitials(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) return '${words[0][0]}${words[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  void _confirmLeave(BuildContext context, GroupProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Leave Group?', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        content: Text(
          'You will no longer receive messages from this group.',
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.outfit(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.leaveGroup(groupId);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: Text('Leave', style: GoogleFonts.outfit(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, GroupProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Group?', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        content: Text(
          'This will permanently delete the group and all its messages. This cannot be undone.',
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.outfit(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.deleteGroup(groupId);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: Text('Delete', style: GoogleFonts.outfit(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ADD MEMBER SECTION
// ═══════════════════════════════════════════════════════════════

class _AddMemberSection extends StatefulWidget {
  final String groupId;

  const _AddMemberSection({required this.groupId});

  @override
  State<_AddMemberSection> createState() => _AddMemberSectionState();
}

class _AddMemberSectionState extends State<_AddMemberSection> {
  final _emailController = TextEditingController();
  bool _isAdding = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add Member',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSoft,
            ),
          ),
          const SizedBox(height: AppTokens.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text),
                  decoration: InputDecoration(
                    hintText: 'Enter email address',
                    hintStyle: GoogleFonts.outfit(
                      fontSize: 14,
                      color: AppColors.textMuted,
                    ),
                    filled: true,
                    fillColor: AppColors.cardAlt,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                      borderSide: const BorderSide(color: AppColors.brand),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _isAdding ? null : _addMember,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  ),
                  child: _isAdding
                      ? const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.person_add_rounded,
                          color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _addMember() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() => _isAdding = true);

    final result = await context.read<GroupProvider>().addMember(
          widget.groupId,
          email,
        );

    if (mounted) {
      setState(() => _isAdding = false);

      if (result != null) {
        _emailController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result, style: GoogleFonts.outfit()),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        final error = context.read<GroupProvider>().error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'Failed to add member',
                style: GoogleFonts.outfit()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// POLICY SECTION
// ═══════════════════════════════════════════════════════════════

class _PolicySection extends StatelessWidget {
  final String groupId;

  const _PolicySection({required this.groupId});

  @override
  Widget build(BuildContext context) {
    return Consumer<GroupProvider>(
      builder: (context, provider, _) {
        final group = provider.currentGroup;
        if (group == null) return const SizedBox.shrink();

        final currentPolicy = group.itineraryEditPolicy;

        return Container(
          padding: const EdgeInsets.all(AppTokens.md),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Itinerary Edit Policy',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSoft,
                ),
              ),
              const SizedBox(height: AppTokens.sm),
              _PolicyOption(
                label: 'Admins Only',
                subtitle: 'Only admins can edit the itinerary',
                isSelected: currentPolicy == 'admins_only',
                onTap: () => provider.updateEditPolicy(groupId, 'admins_only'),
              ),
              _PolicyOption(
                label: 'All Members',
                subtitle: 'Everyone can edit the itinerary',
                isSelected: currentPolicy == 'all_members',
                onTap: () => provider.updateEditPolicy(groupId, 'all_members'),
              ),
              _PolicyOption(
                label: 'Selected Members',
                subtitle: 'Choose specific members',
                isSelected: currentPolicy == 'selected_members',
                onTap: () => provider.updateEditPolicy(groupId, 'selected_members'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PolicyOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _PolicyOption({
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.brand : AppColors.border,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.brand,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// MEMBER TILE
// ═══════════════════════════════════════════════════════════════

class _MemberTile extends StatelessWidget {
  final GroupMemberModel member;
  final String groupId;
  final String currentUserId;
  final bool isCurrentUserAdmin;
  final bool isCurrentUserOwner;
  final String groupOwnerId;

  const _MemberTile({
    required this.member,
    required this.groupId,
    required this.currentUserId,
    required this.isCurrentUserAdmin,
    required this.isCurrentUserOwner,
    required this.groupOwnerId,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = member.userId == currentUserId;
    final isMemberOwner = member.userId == groupOwnerId;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.brandSoft,
            child: Text(
              member.displayName.isNotEmpty
                  ? member.displayName[0].toUpperCase()
                  : '?',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.brand,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name + role
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${member.displayName}${isMe ? ' (You)' : ''}',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Text(
                  member.email,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Role badge
          _RoleBadge(role: member.role),

          // Admin actions (if current user is admin and this is not the owner)
          if (isCurrentUserAdmin && !isMe && !isMemberOwner) ...[
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              onSelected: (value) =>
                  _handleAction(context, value),
              icon: const Icon(Icons.more_vert_rounded,
                  size: 20, color: AppColors.textMuted),
              itemBuilder: (context) => [
                if (!member.isAdmin)
                  const PopupMenuItem(
                    value: 'promote',
                    child: Text('Promote to Admin'),
                  ),
                if (member.isAdmin && !isMemberOwner)
                  const PopupMenuItem(
                    value: 'demote',
                    child: Text('Demote to Member'),
                  ),
                const PopupMenuItem(
                  value: 'remove',
                  child: Text('Remove from Group'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _handleAction(BuildContext context, String action) {
    final provider = context.read<GroupProvider>();
    switch (action) {
      case 'promote':
        provider.promoteToAdmin(groupId, member.userId);
        break;
      case 'demote':
        provider.demoteToMember(groupId, member.userId);
        break;
      case 'remove':
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Remove ${member.displayName}?',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            content: Text(
              'They will no longer be able to access this group.',
              style: GoogleFonts.outfit(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel',
                    style: GoogleFonts.outfit(color: AppColors.textMuted)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  provider.removeMember(groupId, member.userId);
                },
                child: Text('Remove',
                    style: GoogleFonts.outfit(color: AppColors.error)),
              ),
            ],
          ),
        );
        break;
    }
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;

  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String label;

    switch (role) {
      case 'owner':
        bgColor = AppColors.accentSoft;
        textColor = AppColors.accentDeep;
        label = 'Owner';
        break;
      case 'admin':
        bgColor = AppColors.brandSoft;
        textColor = AppColors.brand;
        label = 'Admin';
        break;
      default:
        bgColor = AppColors.cardAlt;
        textColor = AppColors.textMuted;
        label = 'Member';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ACTION BUTTON
// ═══════════════════════════════════════════════════════════════

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
