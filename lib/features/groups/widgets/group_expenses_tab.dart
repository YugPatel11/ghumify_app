import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/models/expense_model.dart';
import '../../../core/models/settlement_model.dart';
import '../../../core/models/expense_balance_model.dart';
import '../../../core/models/group_member_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/group_provider.dart';
import '../../../core/services/expense_service.dart';
import '../../../core/utils/expense_calculator.dart';
import '../screens/add_expense_screen.dart';
import 'expense_detail_sheet.dart';
import 'mark_paid_dialog.dart';

/// Group detail tab for tracking shared expenses, balances, and settlements.
class GroupExpensesTab extends StatefulWidget {
  final String groupId;

  const GroupExpensesTab({super.key, required this.groupId});

  @override
  State<GroupExpensesTab> createState() => _GroupExpensesTabState();
}

class _GroupExpensesTabState extends State<GroupExpensesTab> {
  final ExpenseService _expenseService = ExpenseService();
  String _selectedCategory = 'all';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  static const List<Map<String, dynamic>> _filterCategories = [
    {'id': 'all', 'label': 'All'},
    {'id': 'food', 'label': 'Food'},
    {'id': 'travel', 'label': 'Travel'},
    {'id': 'stay', 'label': 'Stay'},
    {'id': 'tickets', 'label': 'Tickets'},
    {'id': 'shopping', 'label': 'Shopping'},
    {'id': 'other', 'label': 'Other'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final groupProvider = context.watch<GroupProvider>();
    final currentUserId = authProvider.user?.uid ?? '';
    final members = groupProvider.currentMembers;
    final group = groupProvider.currentGroup;
    final isAdmin = group != null && (group.ownerId == currentUserId || group.adminIds.contains(currentUserId));

    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AddExpenseScreen(
                groupId: widget.groupId,
                members: members,
                isAdmin: isAdmin,
              ),
            ),
          );
        },
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Add Expense',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
      ),
      body: StreamBuilder<List<ExpenseModel>>(
        stream: _expenseService.streamExpenses(widget.groupId),
        builder: (context, expenseSnapshot) {
          if (expenseSnapshot.connectionState == ConnectionState.waiting &&
              !expenseSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.brand),
            );
          }

          final allExpenses = expenseSnapshot.data ?? [];

          return StreamBuilder<List<SettlementModel>>(
            stream: _expenseService.streamSettlements(widget.groupId),
            builder: (context, settlementSnapshot) {
              final allSettlements = settlementSnapshot.data ?? [];

              // Calculate core balances and settle-up transfers
              final balances = ExpenseCalculator.calculateBalances(
                expenses: allExpenses,
                settlements: allSettlements,
                members: members,
              );

              final myBalance = balances[currentUserId] ??
                  ExpenseBalanceModel(
                    userId: currentUserId,
                    displayName: 'You',
                    totalPaidPaise: 0,
                    totalSharePaise: 0,
                    netBalancePaise: 0,
                  );

              final settleUpTransfers =
                  ExpenseCalculator.calculateSettleUpTransfers(balances);

              final pendingSettlements =
                  allSettlements.where((s) => s.isPending).toList();

              // Total group spend in paise
              final totalGroupSpendPaise = allExpenses.fold(
                0,
                (sum, e) => sum + e.amountPaise,
              );

              // Filter expenses by category & search
              final filteredExpenses = allExpenses.where((e) {
                final matchCat = _selectedCategory == 'all' ||
                    e.category.toLowerCase() == _selectedCategory;
                final matchQuery = _searchQuery.isEmpty ||
                    e.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    e.paidByName.toLowerCase().contains(_searchQuery.toLowerCase());
                return matchCat && matchQuery;
              }).toList();

              return RefreshIndicator(
                onRefresh: () async {
                  setState(() {});
                },
                color: AppColors.brand,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppTokens.lg,
                    AppTokens.md,
                    AppTokens.lg,
                    80, // bottom padding for FAB
                  ),
                  children: [
                    // ── 1. Summary Card ──
                    _buildSummaryCard(
                      totalGroupSpendPaise: totalGroupSpendPaise,
                      myBalance: myBalance,
                    ),
                    const SizedBox(height: AppTokens.lg),

                    // ── 2. Pending Settlement Confirmation Alerts ──
                    if (pendingSettlements.isNotEmpty) ...[
                      ...pendingSettlements.map((s) => _buildPendingSettlementCard(
                            context: context,
                            settlement: s,
                            currentUserId: currentUserId,
                          )),
                      const SizedBox(height: AppTokens.md),
                    ],

                    // ── 3. Who Owes Whom (Settle Up Suggestions) ──
                    _buildWhoOwesWhomSection(
                      context: context,
                      transfers: settleUpTransfers,
                      currentUserId: currentUserId,
                      balances: balances,
                    ),
                    const SizedBox(height: AppTokens.xl),

                    // ── 4. Search and Filter Bar ──
                    _buildSearchAndFilter(),
                    const SizedBox(height: AppTokens.md),

                    // ── 5. Expense List Header ──
                    Row(
                      children: [
                        Text(
                          'Expenses (${filteredExpenses.length})',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTokens.sm),

                    // ── 6. Expense List / Empty State ──
                    if (filteredExpenses.isEmpty)
                      _buildEmptyState(hasAny: allExpenses.isNotEmpty)
                    else
                      ...filteredExpenses.map((expense) => _buildExpenseRow(
                            context: context,
                            expense: expense,
                            currentUserId: currentUserId,
                            members: members,
                            isAdmin: isAdmin,
                          )),

                    const SizedBox(height: AppTokens.xl),

                    // ── 7. Privacy & Payment Disclaimer ──
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'This feature only keeps track of who owes what. Payments are made outside the app.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTokens.md),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // SECTION BUILDERS
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildSummaryCard({
    required int totalGroupSpendPaise,
    required ExpenseBalanceModel myBalance,
  }) {
    final isCreditor = myBalance.isCreditor;
    final isDebtor = myBalance.isDebtor;

    Color badgeColor;
    Color badgeBg;
    IconData badgeIcon;
    String badgeText;

    if (isCreditor) {
      badgeColor = AppColors.success;
      badgeBg = AppColors.success.withOpacity(0.12);
      badgeIcon = Icons.south_west_rounded; // Incoming / get back
      badgeText = 'You get back ${myBalance.formattedNetBalance}';
    } else if (isDebtor) {
      badgeColor = Colors.orange;
      badgeBg = Colors.orange.withOpacity(0.12);
      badgeIcon = Icons.north_east_rounded; // Outgoing / owe
      badgeText = 'You owe ${myBalance.formattedNetBalance}';
    } else {
      badgeColor = AppColors.textSoft;
      badgeBg = AppColors.cardAlt;
      badgeIcon = Icons.check_circle_outline_rounded;
      badgeText = 'All settled up';
    }

    return Container(
      padding: const EdgeInsets.all(AppTokens.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: AppTokens.shadow(level: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with Balance Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'YOUR EXPENSE BALANCE',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(width: AppTokens.xs),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                  border: Border.all(color: badgeColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 14, color: badgeColor),
                    const SizedBox(width: 4),
                    Text(
                      badgeText,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.md),

          // 3-Column Metrics Row
          Row(
            children: [
              Expanded(
                child: _buildMetricCol(
                  label: 'Group Total',
                  value: ExpenseCurrencyHelper.formatPaise(totalGroupSpendPaise),
                  color: AppColors.text,
                ),
              ),
              Container(width: 1, height: 36, color: AppColors.border),
              Expanded(
                child: _buildMetricCol(
                  label: 'You Paid',
                  value: ExpenseCurrencyHelper.formatPaise(myBalance.totalPaidPaise),
                  color: AppColors.brand,
                ),
              ),
              Container(width: 1, height: 36, color: AppColors.border),
              Expanded(
                child: _buildMetricCol(
                  label: 'Your Share',
                  value: ExpenseCurrencyHelper.formatPaise(myBalance.totalSharePaise),
                  color: AppColors.textSoft,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCol({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildPendingSettlementCard({
    required BuildContext context,
    required SettlementModel settlement,
    required String currentUserId,
  }) {
    final isReceiver = settlement.toUserId == currentUserId;
    final isPayer = settlement.fromUserId == currentUserId;

    if (!isReceiver && !isPayer) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(AppTokens.md),
      decoration: BoxDecoration(
        color: isReceiver ? Colors.amber.withOpacity(0.1) : AppColors.cardAlt,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(
          color: isReceiver ? Colors.amber.withOpacity(0.4) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.hourglass_top_rounded,
            color: isReceiver ? Colors.amber : AppColors.textMuted,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isReceiver
                      ? '${settlement.fromUserName} marked ${settlement.formattedAmount} as paid'
                      : 'Payment of ${settlement.formattedAmount} to ${settlement.toUserName}',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                Text(
                  isReceiver
                      ? 'Please confirm once you receive the funds.'
                      : 'Pending confirmation from ${settlement.toUserName}.',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (isReceiver) ...[
            TextButton(
              onPressed: () => _confirmSettlement(settlement),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.success,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: Text(
                'Confirm',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.error),
              tooltip: 'Reject payment',
              onPressed: () => _rejectSettlement(settlement),
            ),
          ] else if (isPayer) ...[
            TextButton(
              onPressed: () => _cancelSettlement(settlement),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWhoOwesWhomSection({
    required BuildContext context,
    required List<SettleUpSuggestionModel> transfers,
    required String currentUserId,
    required Map<String, ExpenseBalanceModel> balances,
  }) {
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
          Row(
            children: [
              const Icon(
                Icons.swap_horiz_rounded,
                color: AppColors.brand,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Settle Up Suggestions',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Simplified transfers to make everyone even with minimal payments',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppTokens.md),

          if (transfers.isEmpty)
            Container(
              padding: const EdgeInsets.all(AppTokens.md),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.success,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'All settled! No pending debts in this group.',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            )
          else
            ...transfers.map((t) {
              final isMePayer = t.fromUserId == currentUserId;
              final isMeReceiver = t.toUserId == currentUserId;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.md,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isMePayer
                      ? Colors.orange.withOpacity(0.08)
                      : (isMeReceiver
                          ? AppColors.success.withOpacity(0.08)
                          : AppColors.bgElevated),
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  border: Border.all(
                    color: isMePayer
                        ? Colors.orange.withOpacity(0.3)
                        : (isMeReceiver
                            ? AppColors.success.withOpacity(0.3)
                            : AppColors.border),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                color: AppColors.text,
                              ),
                              children: [
                                TextSpan(
                                  text: isMePayer ? 'You' : t.fromUserName,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const TextSpan(text: ' should pay '),
                                TextSpan(
                                  text: isMeReceiver ? 'You' : t.toUserName,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            t.formattedAmount,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isMePayer ? Colors.orange : AppColors.brand,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isMePayer)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: Text(
                          'Mark as Paid',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTokens.radiusPill),
                          ),
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => MarkPaidDialog(
                              groupId: widget.groupId,
                              fromUserId: currentUserId,
                              fromUserName: 'You',
                              toUserId: t.toUserId,
                              toUserName: t.toUserName,
                              defaultAmountPaise: t.amountPaise,
                            ),
                          );
                        },
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Column(
      children: [
        // Search TextField
        TextField(
          controller: _searchController,
          onChanged: (val) => setState(() => _searchQuery = val.trim()),
          style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text),
          decoration: InputDecoration(
            hintText: 'Search expenses by name or payer...',
            hintStyle: GoogleFonts.outfit(fontSize: 13, color: AppColors.textMuted),
            prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: AppColors.card,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Category Filter Chips
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _filterCategories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final cat = _filterCategories[index];
              final isSelected = _selectedCategory == cat['id'];
              return ChoiceChip(
                label: Text(
                  cat['label'],
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textSoft,
                  ),
                ),
                selected: isSelected,
                selectedColor: AppColors.brand,
                backgroundColor: AppColors.card,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                  side: BorderSide(
                    color: isSelected ? AppColors.brand : AppColors.border,
                  ),
                ),
                onSelected: (selected) {
                  if (selected) setState(() => _selectedCategory = cat['id']);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildExpenseRow({
    required BuildContext context,
    required ExpenseModel expense,
    required String currentUserId,
    required List<GroupMemberModel> members,
    required bool isAdmin,
  }) {
    final splitCount = expense.splitMemberIds.length;
    final sharePaise = expense.calculateSharePaise(splitCount);
    final isPartOfSplit = expense.splitMemberIds.contains(currentUserId);
    final isPayer = expense.paidByUserId == currentUserId;

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => ExpenseDetailSheet(
            groupId: widget.groupId,
            expense: expense,
            members: members,
            isAdmin: isAdmin,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(AppTokens.md),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            // Category Icon Badge
            _buildCategoryIcon(expense.category),
            const SizedBox(width: 12),

            // Title & Payer
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.title,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                      Flexible(
                        child: Text(
                        style: GoogleFonts.outfit(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                        '· ${_formatShortDate(expense.date)}',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Amount & Share Info
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  expense.formattedAmount,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isPartOfSplit
                      ? 'Your share: ${ExpenseCurrencyHelper.formatPaise(sharePaise)}'
                      : 'Not in split',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isPartOfSplit ? AppColors.textSoft : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryIcon(String category) {
    IconData icon;
    Color color;

    switch (category.toLowerCase()) {
      case 'food':
        icon = Icons.restaurant_rounded;
        color = Colors.orange;
        break;
      case 'travel':
        icon = Icons.directions_car_rounded;
        color = Colors.blue;
        break;
      case 'stay':
        icon = Icons.hotel_rounded;
        color = Colors.purple;
        break;
      case 'tickets':
        icon = Icons.confirmation_number_rounded;
        color = Colors.teal;
        break;
      case 'shopping':
        icon = Icons.shopping_bag_rounded;
        color = Colors.pink;
        break;
      default:
        icon = Icons.receipt_long_rounded;
        color = AppColors.brand;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildEmptyState({required bool hasAny}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.brandSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                size: 36,
                color: AppColors.brand,
              ),
            ),
            const SizedBox(height: AppTokens.md),
            Text(
              hasAny ? 'No Matching Expenses' : 'No Expenses Yet',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hasAny
                  ? 'Try selecting a different category or clearing search.'
                  : 'Tap the button below to add your first group expense.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatShortDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]}';
  }

  Future<void> _confirmSettlement(SettlementModel settlement) async {
    try {
      await _expenseService.confirmSettlement(
        groupId: widget.groupId,
        settlement: settlement,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Confirmed payment of ${settlement.formattedAmount} from ${settlement.fromUserName}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to confirm: $e')),
        );
      }
    }
  }

  Future<void> _rejectSettlement(SettlementModel settlement) async {
    final reasonController = TextEditingController();
    final shouldReject = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          'Reject Payment',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'State why you have not received ${settlement.formattedAmount} from ${settlement.fromUserName}:',
              style: GoogleFonts.outfit(color: AppColors.textSoft, fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text),
              decoration: const InputDecoration(
                hintText: 'e.g. Payment not received in bank',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldReject == true) {
      try {
        await _expenseService.rejectSettlement(
          groupId: widget.groupId,
          settlement: settlement,
          reason: reasonController.text.trim().isNotEmpty
              ? reasonController.text.trim()
              : 'Payment not received',
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to reject: $e')),
          );
        }
      }
    }
  }

  Future<void> _cancelSettlement(SettlementModel settlement) async {
    try {
      await _expenseService.cancelSettlement(
        groupId: widget.groupId,
        settlement: settlement,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment cancelled')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel: $e')),
        );
      }
    }
  }
}
