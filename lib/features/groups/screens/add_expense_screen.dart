import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/models/expense_model.dart';
import '../../../core/models/group_member_model.dart';
import '../../../core/services/expense_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/expense_calculator.dart';

/// Screen for adding or editing a group expense.
class AddExpenseScreen extends StatefulWidget {
  final String groupId;
  final List<GroupMemberModel> members;
  final bool isAdmin;
  final ExpenseModel? existingExpense;

  const AddExpenseScreen({
    super.key,
    required this.groupId,
    required this.members,
    required this.isAdmin,
    this.existingExpense,
  });

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  late String _selectedPayerId;
  late Set<String> _selectedSplitMemberIds;
  late String _selectedCategory;
  late DateTime _selectedDate;

  bool _isLoading = false;
  String? _errorMessage;

  static const List<Map<String, dynamic>> _categories = [
    {'id': 'food', 'label': 'Food & Drinks', 'icon': Icons.restaurant_rounded},
    {'id': 'travel', 'label': 'Travel & Transit', 'icon': Icons.directions_car_rounded},
    {'id': 'stay', 'label': 'Stay & Hotel', 'icon': Icons.hotel_rounded},
    {'id': 'tickets', 'label': 'Tickets & Entry', 'icon': Icons.confirmation_number_rounded},
    {'id': 'shopping', 'label': 'Shopping', 'icon': Icons.shopping_bag_rounded},
    {'id': 'other', 'label': 'General / Other', 'icon': Icons.receipt_long_rounded},
  ];

  @override
  void initState() {
    super.initState();
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.user?.uid ?? '';

    if (widget.existingExpense != null) {
      final e = widget.existingExpense!;
      _titleController.text = e.title;
      final rupees = e.amountRupees;
      _amountController.text = e.amountPaise % 100 == 0
          ? (e.amountPaise ~/ 100).toString()
          : rupees.toStringAsFixed(2);
      _noteController.text = e.note ?? '';
      _selectedPayerId = e.paidByUserId;
      _selectedSplitMemberIds = Set<String>.from(e.splitMemberIds);
      _selectedCategory = e.category;
      _selectedDate = e.date;
    } else {
      _selectedPayerId = currentUserId;
      _selectedSplitMemberIds = widget.members.map((m) => m.userId).toSet();
      _selectedCategory = 'food';
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  int get _parsedAmountPaise {
    return ExpenseCurrencyHelper.parseRupeesToPaise(_amountController.text) ?? 0;
  }

  String _getLiveSharePreview() {
    final amountPaise = _parsedAmountPaise;
    final count = _selectedSplitMemberIds.length;
    if (amountPaise <= 0 || count == 0) {
      return 'Enter an amount and select members to see per-person share';
    }

    final shareBase = amountPaise ~/ count;
    final remainder = amountPaise % count;
    final shareRupees = shareBase / 100.0;

    if (remainder == 0) {
      return '₹${shareRupees.toStringAsFixed(2)} each for $count ${count == 1 ? "person" : "people"}';
    } else {
      return '₹${shareRupees.toStringAsFixed(2)} each ($remainder person gets 1 paisa adjustment)';
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.brand,
              onPrimary: Colors.white,
              surface: AppColors.bgElevated,
              onSurface: AppColors.text,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    final amountPaise = _parsedAmountPaise;
    if (amountPaise <= 0) {
      setState(() => _errorMessage = 'Please enter an amount greater than ₹0');
      return;
    }

    if (_selectedSplitMemberIds.isEmpty) {
      setState(() => _errorMessage = 'Select at least one member to split with');
      return;
    }

    // Determine payer name
    String payerName = 'User';
    String? payerPhoto;
    for (final m in widget.members) {
      if (m.userId == _selectedPayerId) {
        payerName = m.displayName.isNotEmpty ? m.displayName : 'Member';
        payerPhoto = m.photoUrl;
        break;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = ExpenseService();
      if (widget.existingExpense != null) {
        await service.updateExpense(
          groupId: widget.groupId,
          oldExpense: widget.existingExpense!,
          title: _titleController.text.trim(),
          amountPaise: amountPaise,
          paidByUserId: _selectedPayerId,
          paidByName: payerName,
          paidByPhotoUrl: payerPhoto,
          splitMemberIds: _selectedSplitMemberIds.toList(),
          date: _selectedDate,
          category: _selectedCategory,
          note: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
        );
      } else {
        await service.addExpense(
          groupId: widget.groupId,
          title: _titleController.text.trim(),
          amountPaise: amountPaise,
          paidByUserId: _selectedPayerId,
          paidByName: payerName,
          paidByPhotoUrl: payerPhoto,
          splitMemberIds: _selectedSplitMemberIds.toList(),
          date: _selectedDate,
          category: _selectedCategory,
          note: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingExpense != null
                  ? 'Expense updated successfully'
                  : 'Expense added to group',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingExpense != null;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(
          isEdit ? 'Edit Expense' : 'Add Expense',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        backgroundColor: AppColors.bgElevated,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppTokens.lg),
          children: [
            // Amount Input Card
            Container(
              padding: const EdgeInsets.all(AppTokens.lg),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AMOUNT',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      prefixText: '₹ ',
                      prefixStyle: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brand,
                      ),
                      hintText: '0.00',
                      hintStyle: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted.withOpacity(0.4),
                      ),
                      border: InputBorder.none,
                    ),
                    validator: (val) {
                      final p = ExpenseCurrencyHelper.parseRupeesToPaise(val ?? '');
                      if (p == null || p <= 0) return 'Enter a valid amount';
                      return null;
                    },
                  ),

                  // Live Share preview pill
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.brandSoft,
                      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.pie_chart_outline_rounded,
                          size: 16,
                          color: AppColors.brand,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _getLiveSharePreview(),
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.brand,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTokens.lg),

            // Title Input
            TextFormField(
              controller: _titleController,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              style: GoogleFonts.outfit(fontSize: 16, color: AppColors.text),
              decoration: InputDecoration(
                labelText: 'What was this expense for? *',
                labelStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                hintText: 'e.g. Lunch at Rock Garden',
                hintStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  borderSide: const BorderSide(color: AppColors.brand, width: 2),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: AppTokens.md),

            // Category Chips
            Text(
              'Category',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat['id'];
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        cat['icon'] as IconData,
                        size: 16,
                        color: isSelected ? Colors.white : AppColors.textSoft,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        cat['label'] as String,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : AppColors.textSoft,
                        ),
                      ),
                    ],
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.brand,
                  backgroundColor: AppColors.card,
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
              }).toList(),
            ),
            const SizedBox(height: AppTokens.lg),

            // Paid By Picker
            Container(
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
                    'Paid by',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedPayerId,
                    dropdownColor: AppColors.bgElevated,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.bgElevated,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items: widget.members.map((m) {
                      return DropdownMenuItem<String>(
                        value: m.userId,
                        child: Text(
                          m.displayName.isNotEmpty ? m.displayName : 'Member',
                          style: GoogleFonts.outfit(color: AppColors.text),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedPayerId = val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTokens.lg),

            // Split Between Section
            Container(
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                        'Split between (${_selectedSplitMemberIds.length}/${widget.members.length})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTokens.xs),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            if (_selectedSplitMemberIds.length ==
                                widget.members.length) {
                              _selectedSplitMemberIds.clear();
                            } else {
                              _selectedSplitMemberIds =
                                  widget.members.map((m) => m.userId).toSet();
                            }
                          });
                        },
                        child: Text(
                          _selectedSplitMemberIds.length == widget.members.length
                              ? 'Deselect all'
                              : 'Select all',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.brand,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: AppColors.border),
                  ...widget.members.map((m) {
                    final isChecked =
                        _selectedSplitMemberIds.contains(m.userId);
                    return CheckboxListTile(
                      value: isChecked,
                      activeColor: AppColors.brand,
                      checkColor: Colors.white,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        m.displayName.isNotEmpty ? m.displayName : 'Member',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: AppColors.text,
                        ),
                      ),
                      secondary: CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.brandSoft,
                        child: Text(
                          m.displayName.isNotEmpty
                              ? m.displayName[0].toUpperCase()
                              : 'M',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brand,
                          ),
                        ),
                      ),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedSplitMemberIds.add(m.userId);
                          } else {
                            _selectedSplitMemberIds.remove(m.userId);
                          }
                        });
                      },
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: AppTokens.lg),

            // Date & Notes Row
            ListTile(
              tileColor: AppColors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                side: const BorderSide(color: AppColors.border, width: 0.5),
              ),
              leading:
                  const Icon(Icons.calendar_today_rounded, color: AppColors.brand),
              title: Text(
                'Date',
                style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textMuted),
              ),
              subtitle: Text(
                '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: AppColors.textMuted),
              onTap: _pickDate,
            ),
            const SizedBox(height: AppTokens.md),

            // Optional Note
            TextFormField(
              controller: _noteController,
              maxLines: 2,
              style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text),
              decoration: InputDecoration(
                labelText: 'Note (Optional)',
                labelStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: AppTokens.md),
              Text(
                _errorMessage!,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],

            const SizedBox(height: AppTokens.xl),

            // Submit Button
            SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  ),
                ),
                onPressed: _isLoading ? null : _saveExpense,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isEdit ? 'Save Changes' : 'Add Expense',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: AppTokens.xxl),
          ],
        ),
      ),
    );
  }
}
