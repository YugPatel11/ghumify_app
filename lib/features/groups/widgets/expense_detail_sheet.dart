import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/models/expense_model.dart';
import '../../../core/models/group_member_model.dart';
import '../../../core/services/expense_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../screens/add_expense_screen.dart';

/// Modal bottom sheet displaying detailed breakdown of an expense.
class ExpenseDetailSheet extends StatelessWidget {
  final String groupId;
  final ExpenseModel expense;
  final List<GroupMemberModel> members;
  final bool isAdmin;

  const ExpenseDetailSheet({
    super.key,
    required this.groupId,
    required this.expense,
    required this.members,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.user?.uid ?? '';
    final canEditOrDelete = expense.createdBy == currentUserId || isAdmin;

    final nameMap = <String, String>{};
    for (final m in members) {
      nameMap[m.userId] = m.displayName.isNotEmpty ? m.displayName : 'Member';
    }

    final splitCount = expense.splitMemberIds.length;
    final sharePaise = expense.calculateSharePaise(splitCount);
    final shareRupees = sharePaise / 100.0;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppTokens.lg,
        AppTokens.md,
        AppTokens.lg,
        MediaQuery.of(context).padding.bottom + AppTokens.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
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

            // Header Row: Category Badge + Actions
            Row(
              children: [
                _buildCategoryBadge(expense.category),
                const Spacer(),
                if (canEditOrDelete) ...[
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: AppColors.textSoft, size: 20),
                    tooltip: 'Edit expense',
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AddExpenseScreen(
                            groupId: groupId,
                            members: members,
                            isAdmin: isAdmin,
                            existingExpense: expense,
                          ),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                    tooltip: 'Delete expense',
                    onPressed: () => _confirmDelete(context),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppTokens.sm),

            // Title & Amount
            Text(
              expense.title,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              expense.formattedAmount,
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.brand,
              ),
            ),
            const SizedBox(height: AppTokens.md),

            // Metadata card
            Container(
              padding: const EdgeInsets.all(AppTokens.md),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Column(
                children: [
                  _buildMetaRow(
                    icon: Icons.person_outline_rounded,
                    label: 'Paid by',
                    value: expense.paidByName,
                    highlight: true,
                  ),
                  const Divider(color: AppColors.border, height: 20),
                  _buildMetaRow(
                    icon: Icons.calendar_today_rounded,
                    label: 'Date',
                    value: _formatDate(expense.date),
                  ),
                  if (expense.note != null && expense.note!.isNotEmpty) ...[
                    const Divider(color: AppColors.border, height: 20),
                    _buildMetaRow(
                      icon: Icons.notes_rounded,
                      label: 'Note',
                      value: expense.note!,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppTokens.lg),

            // Split Breakdown Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                  'Split between $splitCount people',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                ),
                const SizedBox(width: AppTokens.xs),
                Text(
                  '₹${shareRupees.toStringAsFixed(2)} each',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSoft,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.sm),

            // Members List
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: expense.splitMemberIds.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: AppColors.border, height: 1),
                itemBuilder: (context, index) {
                  final memberId = expense.splitMemberIds[index];
                  final name = nameMap[memberId] ?? 'Member';
                  final isPayer = memberId == expense.paidByUserId;

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.md,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.brandSoft,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'M',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                              color: AppColors.brand,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.text,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isPayer) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.brandSoft,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Payer',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.brand,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Text(
                          '₹${shareRupees.toStringAsFixed(2)}',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBadge(String category) {
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            category[0].toUpperCase() + category.substring(1),
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow({
    required IconData icon,
    required String label,
    required String value,
    bool highlight = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
              color: highlight ? AppColors.brand : AppColors.text,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        ),
        title: Text(
          'Delete Expense?',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${expense.title}"? Balances will be recalculated.',
          style: GoogleFonts.outfit(color: AppColors.textSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              ),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop(); // dismiss dialog
              Navigator.of(context).pop(); // dismiss sheet
              try {
                await ExpenseService().deleteExpense(
                  groupId: groupId,
                  expense: expense,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Expense deleted')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete: $e')),
                  );
                }
              }
            },
            child: Text(
              'Delete',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
