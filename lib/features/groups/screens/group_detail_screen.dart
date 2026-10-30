import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/providers/group_provider.dart';
import '../widgets/group_chat_tab.dart';
import '../widgets/group_itinerary_tab.dart';
import '../widgets/group_expenses_tab.dart';
import '../widgets/group_live_map_tab.dart';
import '../widgets/group_info_tab.dart';

/// Main group detail screen with 5 tabs: Chat, Itinerary, Expenses, Live Map, Info
class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  final int initialTabIndex;

  const GroupDetailScreen({
    super.key,
    required this.groupId,
    this.initialTabIndex = 0,
  });

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final validIndex = widget.initialTabIndex.clamp(0, 4);
    _tabController = TabController(length: 5, initialIndex: validIndex, vsync: this);

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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: AppColors.brand,
              indicatorWeight: 3,
              labelColor: AppColors.brand,
              unselectedLabelColor: AppColors.textMuted,
              labelStyle: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              tabs: const [
                Tab(
                  icon: Icon(Icons.chat_bubble_rounded, size: 18),
                  text: 'Chat',
                ),
                Tab(
                  icon: Icon(Icons.route_rounded, size: 18),
                  text: 'Itinerary',
                ),
                Tab(
                  icon: Icon(Icons.account_balance_wallet_rounded, size: 18),
                  text: 'Expenses',
                ),
                Tab(
                  icon: Icon(Icons.explore_rounded, size: 18),
                  text: 'Live Map',
                ),
                Tab(
                  icon: Icon(Icons.info_rounded, size: 18),
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
                    GroupItineraryTab(groupId: widget.groupId),
                    GroupExpensesTab(groupId: widget.groupId),
                    GroupLiveMapTab(groupId: widget.groupId),
                    GroupInfoTab(groupId: widget.groupId),
                  ],
                ),
        );
      },
    );
  }
}
