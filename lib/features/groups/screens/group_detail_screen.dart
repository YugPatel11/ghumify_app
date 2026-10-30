import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/providers/group_provider.dart';
import '../widgets/group_chat_tab.dart';
import '../widgets/group_info_tab.dart';

/// Main group detail screen with tabbed layout: Chat, Info
class GroupDetailScreen extends StatefulWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GroupProvider>().openGroup(widget.groupId);
    });
  }

  @override
  void dispose() {
    context.read<GroupProvider>().closeGroup();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GroupProvider>(
      builder: (context, provider, _) {
        final group = provider.currentGroup;

        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(
            backgroundColor: AppColors.bgElevated,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: AppColors.text),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: group != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      Text(
                        '${group.memberIds.length} members',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  )
                : Text(
                    'Loading...',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.brand,
              indicatorWeight: 3,
              labelColor: AppColors.brand,
              unselectedLabelColor: AppColors.textMuted,
              labelStyle: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              tabs: const [
                Tab(
                  icon: Icon(Icons.chat_bubble_rounded, size: 20),
                  text: 'Chat',
                ),
                Tab(
                  icon: Icon(Icons.info_rounded, size: 20),
                  text: 'Info',
                ),
              ],
            ),
          ),
          body: group == null
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.brand),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    GroupChatTab(groupId: widget.groupId),
                    GroupInfoTab(groupId: widget.groupId),
                  ],
                ),
        );
      },
    );
  }
}
