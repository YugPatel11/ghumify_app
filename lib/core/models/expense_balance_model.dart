/// Model representing a member's net spending balance in the group.
class ExpenseBalanceModel {
  final String userId;
  final String displayName;
  final String? photoUrl;
  final int totalPaidPaise; // Total amount paid by this user across expenses
  final int totalSharePaise; // Total of user's shares across expenses
  final int netBalancePaise; // Net balance = totalPaid - totalShare + confirmedSettlements

  ExpenseBalanceModel({
    required this.userId,
    required this.displayName,
    this.photoUrl,
    required this.totalPaidPaise,
    required this.totalSharePaise,
    required this.netBalancePaise,
  });

  bool get isCreditor => netBalancePaise > 0;
  bool get isDebtor => netBalancePaise < 0;
  bool get isSettled => netBalancePaise == 0;

  double get netBalanceRupees => netBalancePaise / 100.0;
  double get totalPaidRupees => totalPaidPaise / 100.0;
  double get totalShareRupees => totalSharePaise / 100.0;

  String get formattedNetBalance {
    final absPaise = netBalancePaise.abs();
    final rupees = absPaise / 100.0;
    if (absPaise % 100 == 0) {
      return '₹${(absPaise ~/ 100).toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          )}';
    }
    return '₹${rupees.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';
  }

  /// Readable badge text e.g. "You get back ₹50" or "You owe ₹50" or "All settled"
  String getSummaryLabel({bool isCurrentUser = false}) {
    if (isSettled) return 'All settled';
    if (isCreditor) {
      return isCurrentUser
          ? 'You get back $formattedNetBalance'
          : '$displayName gets back $formattedNetBalance';
    } else {
      return isCurrentUser
          ? 'You owe $formattedNetBalance'
          : '$displayName owes $formattedNetBalance';
    }
  }
}

/// Suggested minimal transfer to settle up balances.
class SettleUpSuggestionModel {
  final String fromUserId;
  final String fromUserName;
  final String toUserId;
  final String toUserName;
  final int amountPaise;

  SettleUpSuggestionModel({
    required this.fromUserId,
    required this.fromUserName,
    required this.toUserId,
    required this.toUserName,
    required this.amountPaise,
  });

  double get amountRupees => amountPaise / 100.0;

  String get formattedAmount {
    if (amountPaise % 100 == 0) {
      return '₹${(amountPaise ~/ 100).toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          )}';
    }
    return '₹${amountRupees.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';
  }

  String get readableText =>
      '$fromUserName should pay $toUserName $formattedAmount';
}
