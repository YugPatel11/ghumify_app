import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/models/group_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/group_provider.dart';
import '../../../core/services/expense_service.dart';
import '../../../core/utils/expense_calculator.dart';
import '../../groups/screens/create_group_screen.dart';
import '../../groups/screens/group_detail_screen.dart';

/// Home screen entry card for Split Expenses feature.
/// Handles zero-group empty state, single-group direct launch, and multi-group picker.
class SplitExpensesHomeCard extends StatefulWidget {
  const SplitExpensesHomeCard({super.key});

  @override
  State<SplitExpensesHomeCard> createState() => _SplitExpensesHomeCardState();
}

class _SplitExpensesHomeCardState extends State<SplitExpensesHomeCard> {
  final ExpenseService _expenseService = ExpenseService();
  int _totalNetBalancePaise = 0;
  bool _hasCalculatedBalance = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadBalanceSummary();
  }

  Future<void> _loadBalanceSummary() async {
    final groupProvider = context.read<GroupProvider>();
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.user?.uid ?? '';
    final groups = groupProvider.groups;

    if (groups.isEmpty || currentUserId.isEmpty) {
      if (mounted) {
        setState(() {
          _totalNetBalancePaise = 0;
          _hasCalculatedBalance = true;
        });
      }
      return;
    }

    try {
      int cumulativeNetPaise = 0;
      // Load balances across all user's groups
      for (final g in groups) {
        final expenses = await _expenseService.getExpensesOnce(g.id);
        final settlements = await _expenseService.getSettlementsOnce(g.id);
        final balances = ExpenseCalculator.calculateBalances(
          expenses: expenses,
          settlements: settlements,
          members: [],
        );
        final myB = balances[currentUserId];
        if (myB != null) {
          cumulativeNetPaise += myB.netBalancePaise;
        }
      }

      if (mounted) {
        setState(() {
          _totalNetBalancePaise = cumulativeNetPaise;
          _hasCalculatedBalance = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _hasCalculatedBalance = true);
      }
    }
  }

  void _handleTap(BuildContext context) {
    final groupProvider = context.read<GroupProvider>();
    final groups = groupProvider.groups;

    if (groups.isEmpty) {
      _showNoGroupsSheet(context);
    } else if (groups.length == 1) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GroupDetailScreen(
            groupId: groups.first.id,
            initialTabIndex: 2, // Expenses tab
          ),
        ),
      );
    } else {
      _showGroupPickerSheet(context, groups);
    }
  }

  void _showNoGroupsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppTokens.xl,
            AppTokens.lg,
            AppTokens.xl,
            MediaQuery.of(ctx).padding.bottom + AppTokens.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.brandSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.group_add_rounded,
                  color: AppColors.brand,
                  size: 32,
                ),
              ),
              const SizedBox(height: AppTokens.md),
              Text(
                'Create a Group to Split Expenses',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Split hotels, cab fares, and food bills equally with travel companions. The app tracks who owes what and simplifies repayments.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: AppColors.textSoft,
                ),
              ),
              const SizedBox(height: AppTokens.xl),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add_rounded),
                  label: Text(
                    'Create a Group',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CreateGroupScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showGroupPickerSheet(BuildContext context, List<GroupModel> groups) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppTokens.lg,
            AppTokens.md,
            AppTokens.lg,
            MediaQuery.of(ctx).padding.bottom + AppTokens.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppTokens.md),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Choose a Group',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Select which trip expenses you want to view or split',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: AppTokens.md),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: groups.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final g = groups[index];
                    return ListTile(
                      tileColor: AppColors.card,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                        side: const BorderSide(color: AppColors.border, width: 0.5),
                      ),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.brandSoft,
                        child: Text(
                          g.name.isNotEmpty ? g.name[0].toUpperCase() : 'G',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                            color: AppColors.brand,
                          ),
                        ),
                      ),
                      title: Text(
                        g.name,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                      subtitle: Text(
                        '${g.memberIds.length} members',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => GroupDetailScreen(
                              groupId: g.id,
                              initialTabIndex: 2, // Expenses tab
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupProvider = context.watch<GroupProvider>();
    final groups = groupProvider.groups;

    String subtitleText = 'Equal splits & smart settle-up with friends';
    Widget? balanceBadge;

    if (groups.isNotEmpty && _hasCalculatedBalance && _totalNetBalancePaise != 0) {
      if (_totalNetBalancePaise > 0) {
        final formatted = ExpenseCurrencyHelper.formatPaise(_totalNetBalancePaise);
        subtitleText = 'You get back across your groups';
        balanceBadge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.12),
            borderRadius: BorderRadius.circular(AppTokens.radiusPill),
            border: Border.all(color: AppColors.success.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.south_west_rounded,
                size: 12,
                color: AppColors.success,
              ),
              const SizedBox(width: 4),
              Text(
                'Get back $formatted',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        );
      } else {
        final formatted =
            ExpenseCurrencyHelper.formatPaise(_totalNetBalancePaise.abs());
        subtitleText = 'You owe across your groups';
        balanceBadge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.12),
            borderRadius: BorderRadius.circular(AppTokens.radiusPill),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.north_east_rounded,
                size: 12,
                color: Colors.orange,
              ),
              const SizedBox(width: 4),
              Text(
                'Owe $formatted',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        );
      }
    } else if (groups.isNotEmpty && _hasCalculatedBalance && _totalNetBalancePaise == 0) {
      subtitleText = 'All settled up in ${groups.length} ${groups.length == 1 ? "group" : "groups"}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
      child: GestureDetector(
        onTap: () => _handleTap(context),
        child: Container(
          padding: const EdgeInsets.all(AppTokens.md),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                AppColors.card,
                AppColors.cardAlt,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppTokens.radiusLg),
            border: Border.all(color: AppColors.border, width: 0.5),
            boxShadow: AppTokens.shadow(level: 1),
          ),
          child: Row(
            children: [
              // Glowing Icon Badge
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.brandSoft,
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppColors.brand,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),

              // Title, Subtitle, and Optional Balance Badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Split Expenses',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (balanceBadge != null) ...[
                          const SizedBox(width: 8),
                          balanceBadge,
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitleText,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

