import 'dart:math' as math;
import '../models/expense_model.dart';
import '../models/settlement_model.dart';
import '../models/expense_balance_model.dart';
import '../models/group_member_model.dart';

/// Currency formatting and parsing utilities for Indian Rupee with integer paise precision.
class ExpenseCurrencyHelper {
  /// Format integer paise into Indian Rupee string (e.g. 15050 -> "₹150.50", 10000 -> "₹100")
  static String formatPaise(int amountPaise) {
    final absPaise = amountPaise.abs();
    final isNegative = amountPaise < 0;
    final prefix = isNegative ? '-₹' : '₹';

    if (absPaise % 100 == 0) {
      final rupees = absPaise ~/ 100;
      final formatted = rupees.toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          );
      return '$prefix$formatted';
    }

    final rupees = absPaise / 100.0;
    final formatted = rupees.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
    return '$prefix$formatted';
  }

  /// Parse user rupee string (e.g. "150.50" or "150") into integer paise (15050).
  /// Returns null if string is invalid or amount <= 0.
  static int? parseRupeesToPaise(String input) {
    final clean = input.trim().replaceAll(',', '').replaceAll('₹', '');
    if (clean.isEmpty) return null;

    final parts = clean.split('.');
    if (parts.length > 2) return null; // multiple decimal points

    final whole = int.tryParse(parts[0]);
    if (whole == null || whole < 0) return null;

    int paiseFraction = 0;
    if (parts.length == 2) {
      final fractionStr = parts[1];
      if (fractionStr.length > 2) return null; // max 2 decimals allowed
      if (fractionStr.length == 1) {
        final digit = int.tryParse(fractionStr);
        if (digit == null) return null;
        paiseFraction = digit * 10;
      } else if (fractionStr.length == 2) {
        final digits = int.tryParse(fractionStr);
        if (digits == null) return null;
        paiseFraction = digits;
      }
    }

    final totalPaise = (whole * 100) + paiseFraction;
    if (totalPaise <= 0) return null;
    return totalPaise;
  }
}

/// Pure deterministic calculation engine for equal expense splits, net balances, and greedy settle-up minimization.
/// Contains no UI or database code.
class ExpenseCalculator {
  /// Calculate equal shares in paise across members.
  /// When total amount does not divide evenly, leftover paise are deterministically
  /// distributed 1 paisa at a time to the first members in lexicographical order.
  ///
  /// Invariant: The sum of all shares strictly equals totalPaise.
  static Map<String, int> calculateEqualShares(
    int totalPaise,
    List<String> memberIds,
  ) {
    if (memberIds.isEmpty || totalPaise <= 0) {
      return {};
    }

    // Sort member IDs deterministically to ensure reproducible allocation
    final sortedIds = List<String>.from(memberIds)..sort();
    final count = sortedIds.length;
    final baseShare = totalPaise ~/ count;
    final remainder = totalPaise % count;

    final shares = <String, int>{};
    for (int i = 0; i < count; i++) {
      final memberId = sortedIds[i];
      // First 'remainder' members receive 1 extra paisa
      final extra = i < remainder ? 1 : 0;
      shares[memberId] = baseShare + extra;
    }

    return shares;
  }

  /// Calculates net balances for all group members across active expenses and confirmed settlements.
  ///
  /// Formula:
  /// For each member:
  ///   Net Balance = (Total Paid - Total Shares) + (Confirmed Sent - Confirmed Received)
  ///
  /// Invariant:
  ///   Sum of all net balances is strictly zero (Σ NetBalance == 0).
  static Map<String, ExpenseBalanceModel> calculateBalances({
    required List<ExpenseModel> expenses,
    required List<SettlementModel> settlements,
    required List<GroupMemberModel> members,
  }) {
    // Collect all unique member IDs (including removed members with historical records)
    final allUserIds = <String>{};
    final nameMap = <String, String>{};
    final photoMap = <String, String?>{};

    for (final m in members) {
      allUserIds.add(m.userId);
      nameMap[m.userId] = m.displayName.isNotEmpty ? m.displayName : 'Member';
      photoMap[m.userId] = m.photoUrl;
    }

    // Include historical members who might not be in current members list
    for (final e in expenses) {
      if (e.isDeleted) continue;
      allUserIds.add(e.paidByUserId);
      if (!nameMap.containsKey(e.paidByUserId) && e.paidByName.isNotEmpty) {
        nameMap[e.paidByUserId] = e.paidByName;
      }
      for (final id in e.splitMemberIds) {
        allUserIds.add(id);
      }
    }

    for (final s in settlements) {
      if (s.isConfirmed) {
        allUserIds.add(s.fromUserId);
        allUserIds.add(s.toUserId);
        if (!nameMap.containsKey(s.fromUserId) && s.fromUserName.isNotEmpty) {
          nameMap[s.fromUserId] = s.fromUserName;
        }
        if (!nameMap.containsKey(s.toUserId) && s.toUserName.isNotEmpty) {
          nameMap[s.toUserId] = s.toUserName;
        }
      }
    }

    final totalPaid = <String, int>{for (final id in allUserIds) id: 0};
    final totalShares = <String, int>{for (final id in allUserIds) id: 0};
    final settlementNet = <String, int>{for (final id in allUserIds) id: 0};

    // 1. Process active expenses
    for (final expense in expenses) {
      if (expense.isDeleted) continue;
      final payerId = expense.paidByUserId;
      totalPaid[payerId] = (totalPaid[payerId] ?? 0) + expense.amountPaise;

      final shares = calculateEqualShares(
        expense.amountPaise,
        expense.splitMemberIds,
      );

      for (final entry in shares.entries) {
        final memberId = entry.key;
        final share = entry.value;
        totalShares[memberId] = (totalShares[memberId] ?? 0) + share;
      }
    }

    // 2. Process confirmed settlements
    for (final s in settlements) {
      if (s.isConfirmed) {
        // Debtor paid creditor: debtor's debt is reduced (+), creditor's credit is reduced (-)
        settlementNet[s.fromUserId] =
            (settlementNet[s.fromUserId] ?? 0) + s.amountPaise;
        settlementNet[s.toUserId] =
            (settlementNet[s.toUserId] ?? 0) - s.amountPaise;
      }
    }

    // 3. Assemble balance models
    final balances = <String, ExpenseBalanceModel>{};
    for (final id in allUserIds) {
      final paid = totalPaid[id] ?? 0;
      final share = totalShares[id] ?? 0;
      final netSettled = settlementNet[id] ?? 0;
      final netBalance = (paid - share) + netSettled;

      balances[id] = ExpenseBalanceModel(
        userId: id,
        displayName: nameMap[id] ?? 'Member',
        photoUrl: photoMap[id],
        totalPaidPaise: paid,
        totalSharePaise: share,
        netBalancePaise: netBalance,
      );
    }

    return balances;
  }

  /// Calculates the minimal set of transactions to settle all debts using the standard Greedy algorithm:
  /// Repeatedly matches the largest debtor (most negative net balance) with the largest creditor
  /// (most positive net balance).
  ///
  /// Method Explanation:
  /// 1. Debtors (net balance < 0) and Creditors (net balance > 0) are placed into priority queues/lists.
  /// 2. In each iteration, the member owing the most money sends a payment to the member owed the most.
  /// 3. The transaction amount is min(|debtor.balance|, creditor.balance).
  /// 4. This clears at least one member's balance in every iteration, yielding at most N - 1 transactions.
  static List<SettleUpSuggestionModel> calculateSettleUpTransfers(
    Map<String, ExpenseBalanceModel> balances,
  ) {
    // Separate active debtors and creditors
    final debtors = <_TempAccount>[];
    final creditors = <_TempAccount>[];

    for (final b in balances.values) {
      if (b.netBalancePaise < 0) {
        debtors.add(_TempAccount(
          userId: b.userId,
          name: b.displayName,
          balancePaise: b.netBalancePaise,
        ));
      } else if (b.netBalancePaise > 0) {
        creditors.add(_TempAccount(
          userId: b.userId,
          name: b.displayName,
          balancePaise: b.netBalancePaise,
        ));
      }
    }

    // Sort: debtors ascending (most negative first), creditors descending (largest credit first)
    debtors.sort((a, b) => a.balancePaise.compareTo(b.balancePaise));
    creditors.sort((a, b) => b.balancePaise.compareTo(a.balancePaise));

    final suggestions = <SettleUpSuggestionModel>[];
    int debtorIdx = 0;
    int creditorIdx = 0;

    while (debtorIdx < debtors.length && creditorIdx < creditors.length) {
      final debtor = debtors[debtorIdx];
      final creditor = creditors[creditorIdx];

      final debtAmount = -debtor.balancePaise;
      final creditAmount = creditor.balancePaise;

      final transferPaise = math.min(debtAmount, creditAmount);

      if (transferPaise > 0) {
        suggestions.add(SettleUpSuggestionModel(
          fromUserId: debtor.userId,
          fromUserName: debtor.name,
          toUserId: creditor.userId,
          toUserName: creditor.name,
          amountPaise: transferPaise,
        ));
      }

      debtor.balancePaise += transferPaise;
      creditor.balancePaise -= transferPaise;

      if (debtor.balancePaise == 0) debtorIdx++;
      if (creditor.balancePaise == 0) creditorIdx++;
    }

    return suggestions;
  }
}

class _TempAccount {
  final String userId;
  final String name;
  int balancePaise;

  _TempAccount({
    required this.userId,
    required this.name,
    required this.balancePaise,
  });
}
