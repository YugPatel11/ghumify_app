import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/services/expense_service.dart';
import '../../../core/utils/expense_calculator.dart';

/// Dialog allowing a debtor to mark a payment as paid to a creditor.
class MarkPaidDialog extends StatefulWidget {
  final String groupId;
  final String fromUserId;
  final String fromUserName;
  final String toUserId;
  final String toUserName;
  final int defaultAmountPaise;

  const MarkPaidDialog({
    super.key,
    required this.groupId,
    required this.fromUserId,
    required this.fromUserName,
    required this.toUserId,
    required this.toUserName,
    required this.defaultAmountPaise,
  });

  @override
  State<MarkPaidDialog> createState() => _MarkPaidDialogState();
}

class _MarkPaidDialogState extends State<MarkPaidDialog> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final rupees = widget.defaultAmountPaise / 100.0;
    _amountController.text = widget.defaultAmountPaise % 100 == 0
        ? (widget.defaultAmountPaise ~/ 100).toString()
        : rupees.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final parsedPaise =
        ExpenseCurrencyHelper.parseRupeesToPaise(_amountController.text);
    if (parsedPaise == null || parsedPaise <= 0) {
      setState(() => _error = 'Enter a valid amount greater than ₹0');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await ExpenseService().recordSettlement(
        groupId: widget.groupId,
        fromUserId: widget.fromUserId,
        fromUserName: widget.fromUserName,
        toUserId: widget.toUserId,
        toUserName: widget.toUserName,
        amountPaise: parsedPaise,
        notes: _notesController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Marked ${ExpenseCurrencyHelper.formatPaise(parsedPaise)} as paid. Waiting for ${widget.toUserName} to confirm.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppColors.brandSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.payments_rounded,
              color: AppColors.brand,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Record Payment',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppColors.text,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recording payment to ${widget.toUserName}',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: AppColors.textSoft,
              ),
            ),
            const SizedBox(height: AppTokens.md),

            // Amount field
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brand,
                ),
                labelText: 'Amount Paid',
                labelStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.bgElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  borderSide: const BorderSide(color: AppColors.brand, width: 2),
                ),
              ),
            ),
            const SizedBox(height: AppTokens.sm),

            // Notes field
            TextField(
              controller: _notesController,
              style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text),
              decoration: InputDecoration(
                labelText: 'Note (Optional, e.g. Sent via UPI/Cash)',
                labelStyle: GoogleFonts.outfit(fontSize: 13, color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.bgElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: AppTokens.sm),
              Text(
                _error!,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: AppColors.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],

            const SizedBox(height: AppTokens.sm),
            Text(
              'Note: This records an offline payment. Balances will update after ${widget.toUserName} confirms receipt.',
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: AppColors.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: GoogleFonts.outfit(color: AppColors.textMuted),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brand,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            ),
          ),
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  'Mark as Paid',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                ),
        ),
      ],
    );
  }
}
