import 'package:flutter_test/flutter_test.dart';
import 'package:ghumify_app/core/models/expense_model.dart';
import 'package:ghumify_app/core/models/settlement_model.dart';
import 'package:ghumify_app/core/models/group_member_model.dart';
import 'package:ghumify_app/core/utils/expense_calculator.dart';

void main() {
  group('ExpenseCurrencyHelper Tests', () {
    test('formatPaise formats integer paise into Indian Rupee', () {
      expect(ExpenseCurrencyHelper.formatPaise(10000), '₹100');
      expect(ExpenseCurrencyHelper.formatPaise(125050), '₹1,250.50');
      expect(ExpenseCurrencyHelper.formatPaise(5000), '₹50');
      expect(ExpenseCurrencyHelper.formatPaise(3333), '₹33.33');
      expect(ExpenseCurrencyHelper.formatPaise(-5000), '-₹50');
    });

    test('parseRupeesToPaise correctly converts inputs into integer paise', () {
      expect(ExpenseCurrencyHelper.parseRupeesToPaise('100'), 10000);
      expect(ExpenseCurrencyHelper.parseRupeesToPaise('150.50'), 15050);
      expect(ExpenseCurrencyHelper.parseRupeesToPaise('₹ 1,250.50'), 125050);
      expect(ExpenseCurrencyHelper.parseRupeesToPaise('33.33'), 3333);
      expect(ExpenseCurrencyHelper.parseRupeesToPaise('0'), isNull);
      expect(ExpenseCurrencyHelper.parseRupeesToPaise('-50'), isNull);
      expect(ExpenseCurrencyHelper.parseRupeesToPaise('abc'), isNull);
    });
  });

  group('Equal Split and Leftover Paise Tests', () {
    test('Splits evenly without remainder', () {
      final shares = ExpenseCalculator.calculateEqualShares(
        30000, // ₹300.00
        ['user_a', 'user_b', 'user_c'],
      );

      expect(shares.length, 3);
      expect(shares['user_a'], 10000);
      expect(shares['user_b'], 10000);
      expect(shares['user_c'], 10000);
      expect(shares.values.fold(0, (a, b) => a + b), 30000);
    });

    test('Splits unevenly: leftover paise distributed deterministically', () {
      // ₹100 split between 3 people (10000 paise / 3 = 3333 r 1)
      final shares = ExpenseCalculator.calculateEqualShares(
        10000,
        ['user_c', 'user_a', 'user_b'],
      );

      // Lexicographically sorted: user_a gets 3334, user_b gets 3333, user_c gets 3333
      expect(shares['user_a'], 3334);
      expect(shares['user_b'], 3333);
      expect(shares['user_c'], 3333);

      // Total strictly matches 10000 paise (₹100)
      expect(shares.values.fold(0, (a, b) => a + b), 10000);
    });

    test('Splits unevenly with 2 leftover paise', () {
      // ₹100.01 (10001 paise) split 3 ways -> 3333 r 2 -> two people get 3334, one gets 3333
      final shares = ExpenseCalculator.calculateEqualShares(
        10001,
        ['user_1', 'user_2', 'user_3'],
      );

      expect(shares['user_1'], 3334);
      expect(shares['user_2'], 3334);
      expect(shares['user_3'], 3333);
      expect(shares.values.fold(0, (a, b) => a + b), 10001);
    });
  });

  group('Core Balances and Settle-Up Tests', () {
    final members = [
      GroupMemberModel(userId: 'u1', email: 'u1@test.com', displayName: 'Person 1'),
      GroupMemberModel(userId: 'u2', email: 'u2@test.com', displayName: 'Person 2'),
      GroupMemberModel(userId: 'u3', email: 'u3@test.com', displayName: 'Person 3'),
    ];

    test('Prompt Worked Example 1: P1 paid 100, P2 paid 200, split equally', () {
      // Person 1 paid ₹100, Person 2 paid ₹200, split equally between both.
      // Total ₹300, each share ₹150.
      // Person 1 net = 100 - 150 = -50.
      // Person 2 net = 200 - 150 = +50.
      // Settle-up: Person 1 sends ₹50 to Person 2.
      final expenses = [
        ExpenseModel(
          id: 'e1',
          groupId: 'g1',
          title: 'Lunch',
          amountPaise: 10000, // ₹100
          paidByUserId: 'u1',
          paidByName: 'Person 1',
          splitMemberIds: ['u1', 'u2'],
          date: DateTime.now(),
          createdBy: 'u1',
        ),
        ExpenseModel(
          id: 'e2',
          groupId: 'g1',
          title: 'Dinner',
          amountPaise: 20000, // ₹200
          paidByUserId: 'u2',
          paidByName: 'Person 2',
          splitMemberIds: ['u1', 'u2'],
          date: DateTime.now(),
          createdBy: 'u2',
        ),
      ];

      final balances = ExpenseCalculator.calculateBalances(
        expenses: expenses,
        settlements: [],
        members: [members[0], members[1]],
      );

      expect(balances['u1']!.totalPaidPaise, 10000);
      expect(balances['u1']!.totalSharePaise, 15000);
      expect(balances['u1']!.netBalancePaise, -5000); // -₹50

      expect(balances['u2']!.totalPaidPaise, 20000);
      expect(balances['u2']!.totalSharePaise, 15000);
      expect(balances['u2']!.netBalancePaise, 5000); // +₹50

      // Zero-sum invariant
      final sumBalances = balances.values.fold(0, (a, b) => a + b.netBalancePaise);
      expect(sumBalances, 0);

      // Settle-up transfers
      final transfers = ExpenseCalculator.calculateSettleUpTransfers(balances);
      expect(transfers.length, 1);
      expect(transfers.first.fromUserId, 'u1');
      expect(transfers.first.toUserId, 'u2');
      expect(transfers.first.amountPaise, 5000);
      expect(transfers.first.readableText, 'Person 1 should pay Person 2 ₹50');
    });

    test('Prompt Worked Example 2: A paid 300, B paid 0, C paid 0, split equally', () {
      // 3 people (A paid 300, B paid 0, C paid 0, split equally):
      // each share ₹100 -> B sends ₹100 to A, C sends ₹100 to A.
      final expenses = [
        ExpenseModel(
          id: 'e1',
          groupId: 'g1',
          title: 'Cab',
          amountPaise: 30000, // ₹300
          paidByUserId: 'u1',
          paidByName: 'Person 1',
          splitMemberIds: ['u1', 'u2', 'u3'],
          date: DateTime.now(),
          createdBy: 'u1',
        ),
      ];

      final balances = ExpenseCalculator.calculateBalances(
        expenses: expenses,
        settlements: [],
        members: members,
      );

      expect(balances['u1']!.netBalancePaise, 20000); // +₹200
      expect(balances['u2']!.netBalancePaise, -10000); // -₹100
      expect(balances['u3']!.netBalancePaise, -10000); // -₹100

      final transfers = ExpenseCalculator.calculateSettleUpTransfers(balances);
      expect(transfers.length, 2);

      final totalSentToA = transfers
          .where((t) => t.toUserId == 'u1')
          .fold(0, (sum, t) => sum + t.amountPaise);
      expect(totalSentToA, 20000); // Exactly ₹200
    });

    test('Edge Case: Only one person selected (paid for self, no debt)', () {
      final expenses = [
        ExpenseModel(
          id: 'e1',
          groupId: 'g1',
          title: 'Personal Snack',
          amountPaise: 5000,
          paidByUserId: 'u1',
          paidByName: 'Person 1',
          splitMemberIds: ['u1'],
          date: DateTime.now(),
          createdBy: 'u1',
        ),
      ];

      final balances = ExpenseCalculator.calculateBalances(
        expenses: expenses,
        settlements: [],
        members: members,
      );

      expect(balances['u1']!.netBalancePaise, 0);
      final transfers = ExpenseCalculator.calculateSettleUpTransfers(balances);
      expect(transfers, isEmpty);
    });

    test('Edge Case: Person paid but is not in the split', () {
      // Person 1 pays ₹100 for Person 2 and Person 3 (Person 1 is not part of the split)
      final expenses = [
        ExpenseModel(
          id: 'e1',
          groupId: 'g1',
          title: 'Museum Entry for Friends',
          amountPaise: 10000,
          paidByUserId: 'u1',
          paidByName: 'Person 1',
          splitMemberIds: ['u2', 'u3'],
          date: DateTime.now(),
          createdBy: 'u1',
        ),
      ];

      final balances = ExpenseCalculator.calculateBalances(
        expenses: expenses,
        settlements: [],
        members: members,
      );

      expect(balances['u1']!.totalPaidPaise, 10000);
      expect(balances['u1']!.totalSharePaise, 0);
      expect(balances['u1']!.netBalancePaise, 10000); // gets full ₹100 back

      expect(balances['u2']!.netBalancePaise, -5000);
      expect(balances['u3']!.netBalancePaise, -5000);
    });

    test('Settlement Integration: Partial settlement reduces balance correctly', () {
      // U1 owes U2 ₹50. U1 pays ₹30 to U2 (confirmed).
      // Remaining debt should be ₹20.
      final expenses = [
        ExpenseModel(
          id: 'e1',
          groupId: 'g1',
          title: 'Dinner',
          amountPaise: 10000, // ₹100
          paidByUserId: 'u2',
          paidByName: 'Person 2',
          splitMemberIds: ['u1', 'u2'],
          date: DateTime.now(),
          createdBy: 'u2',
        ),
      ];

      final settlements = [
        SettlementModel(
          id: 's1',
          groupId: 'g1',
          fromUserId: 'u1',
          fromUserName: 'Person 1',
          toUserId: 'u2',
          toUserName: 'Person 2',
          amountPaise: 3000, // ₹30
          date: DateTime.now(),
          status: 'confirmed',
          createdBy: 'u1',
        ),
      ];

      final balances = ExpenseCalculator.calculateBalances(
        expenses: expenses,
        settlements: settlements,
        members: [members[0], members[1]],
      );

      // Originally u1 owed 5000, paid 3000 -> now owes 2000
      expect(balances['u1']!.netBalancePaise, -2000);
      expect(balances['u2']!.netBalancePaise, 2000);

      final transfers = ExpenseCalculator.calculateSettleUpTransfers(balances);
      expect(transfers.length, 1);
      expect(transfers.first.amountPaise, 2000);
      expect(transfers.first.readableText, 'Person 1 should pay Person 2 ₹20');
    });

    test('Unconfirmed settlements (pending/rejected/cancelled) do not affect balance', () {
      final expenses = [
        ExpenseModel(
          id: 'e1',
          groupId: 'g1',
          title: 'Dinner',
          amountPaise: 10000,
          paidByUserId: 'u2',
          paidByName: 'Person 2',
          splitMemberIds: ['u1', 'u2'],
          date: DateTime.now(),
          createdBy: 'u2',
        ),
      ];

      final settlements = [
        SettlementModel(
          id: 's1',
          groupId: 'g1',
          fromUserId: 'u1',
          fromUserName: 'Person 1',
          toUserId: 'u2',
          toUserName: 'Person 2',
          amountPaise: 3000,
          date: DateTime.now(),
          status: 'pending', // Pending
          createdBy: 'u1',
        ),
        SettlementModel(
          id: 's2',
          groupId: 'g1',
          fromUserId: 'u1',
          fromUserName: 'Person 1',
          toUserId: 'u2',
          toUserName: 'Person 2',
          amountPaise: 2000,
          date: DateTime.now(),
          status: 'rejected', // Rejected
          createdBy: 'u1',
        ),
      ];

      final balances = ExpenseCalculator.calculateBalances(
        expenses: expenses,
        settlements: settlements,
        members: [members[0], members[1]],
      );

      // Still owes original ₹50
      expect(balances['u1']!.netBalancePaise, -5000);
      expect(balances['u2']!.netBalancePaise, 5000);
    });

    test('Full settle-up results in All Settled state', () {
      final expenses = [
        ExpenseModel(
          id: 'e1',
          groupId: 'g1',
          title: 'Dinner',
          amountPaise: 10000,
          paidByUserId: 'u2',
          paidByName: 'Person 2',
          splitMemberIds: ['u1', 'u2'],
          date: DateTime.now(),
          createdBy: 'u2',
        ),
      ];

      final settlements = [
        SettlementModel(
          id: 's1',
          groupId: 'g1',
          fromUserId: 'u1',
          fromUserName: 'Person 1',
          toUserId: 'u2',
          toUserName: 'Person 2',
          amountPaise: 5000, // Full ₹50
          date: DateTime.now(),
          status: 'confirmed',
          createdBy: 'u1',
        ),
      ];

      final balances = ExpenseCalculator.calculateBalances(
        expenses: expenses,
        settlements: settlements,
        members: [members[0], members[1]],
      );

      expect(balances['u1']!.isSettled, isTrue);
      expect(balances['u2']!.isSettled, isTrue);
      expect(ExpenseCalculator.calculateSettleUpTransfers(balances), isEmpty);
    });

    test('Soft deleted expenses are completely excluded from balance calculation', () {
      final expenses = [
        ExpenseModel(
          id: 'e1',
          groupId: 'g1',
          title: 'Deleted Expense',
          amountPaise: 50000,
          paidByUserId: 'u1',
          paidByName: 'Person 1',
          splitMemberIds: ['u1', 'u2'],
          date: DateTime.now(),
          createdBy: 'u1',
          isDeleted: true,
        ),
      ];

      final balances = ExpenseCalculator.calculateBalances(
        expenses: expenses,
        settlements: [],
        members: [members[0], members[1]],
      );

      expect(balances['u1']!.totalPaidPaise, 0);
      expect(balances['u1']!.netBalancePaise, 0);
      expect(balances['u2']!.netBalancePaise, 0);
    });

    test('Removed member historical balances are preserved and never lost', () {
      // u1 and u2 had expenses. u2 was subsequently removed from the group.
      // u2 is not in currentMembers list, but their balance must still be tracked!
      final expenses = [
        ExpenseModel(
          id: 'e1',
          groupId: 'g1',
          title: 'Past Activity',
          amountPaise: 10000,
          paidByUserId: 'u2', // removed member paid
          paidByName: 'Removed Person 2',
          splitMemberIds: ['u1', 'u2'],
          date: DateTime.now(),
          createdBy: 'u2',
        ),
      ];

      final balances = ExpenseCalculator.calculateBalances(
        expenses: expenses,
        settlements: [],
        members: [members[0]], // only u1 is in active members
      );

      expect(balances.containsKey('u2'), isTrue);
      expect(balances['u2']!.displayName, 'Removed Person 2');
      expect(balances['u2']!.netBalancePaise, 5000); // +₹50
      expect(balances['u1']!.netBalancePaise, -5000); // -₹50
    });

    test('Late joining member is only included in expenses they are selected in', () {
      // u1 and u2 have expense e1.
      // u_late joins later and is only in expense e2.
      final expenses = [
        ExpenseModel(
          id: 'e1',
          groupId: 'g1',
          title: 'Day 1 Dinner',
          amountPaise: 10000,
          paidByUserId: 'u1',
          paidByName: 'Person 1',
          splitMemberIds: ['u1', 'u2'],
          date: DateTime.now().subtract(const Duration(days: 2)),
          createdBy: 'u1',
        ),
        ExpenseModel(
          id: 'e2',
          groupId: 'g1',
          title: 'Day 3 Cab',
          amountPaise: 9000,
          paidByUserId: 'u_late',
          paidByName: 'Late Joiner',
          splitMemberIds: ['u1', 'u2', 'u_late'],
          date: DateTime.now(),
          createdBy: 'u_late',
        ),
      ];

      final lateMember = GroupMemberModel(
        userId: 'u_late',
        email: 'late@test.com',
        displayName: 'Late Joiner',
      );

      final balances = ExpenseCalculator.calculateBalances(
        expenses: expenses,
        settlements: [],
        members: [members[0], members[1], lateMember],
      );

      // u_late paid 9000, split 3000 -> net = +6000
      expect(balances['u_late']!.netBalancePaise, 6000);

      // Total sum of balances strictly 0
      final sum = balances.values.fold(0, (a, b) => a + b.netBalancePaise);
      expect(sum, 0);
    });

    test('Stress Test: 100 expenses across 5 members always maintains zero-sum invariant', () {
      final fiveMembers = List.generate(
        5,
        (i) => GroupMemberModel(
          userId: 'user_$i',
          email: 'user_$i@test.com',
          displayName: 'User $i',
        ),
      );

      final stressExpenses = <ExpenseModel>[];
      for (int i = 0; i < 100; i++) {
        final payerId = 'user_${i % 5}';
        final splitIds = ['user_${i % 5}', 'user_${(i + 1) % 5}', 'user_${(i + 2) % 5}'];
        final amountPaise = 1000 + (i * 37) % 50000; // varying paise amounts
        stressExpenses.add(ExpenseModel(
          id: 'stress_$i',
          groupId: 'g_stress',
          title: 'Expense $i',
          amountPaise: amountPaise,
          paidByUserId: payerId,
          paidByName: 'User ${i % 5}',
          splitMemberIds: splitIds,
          date: DateTime.now(),
          createdBy: payerId,
        ));
      }

      final balances = ExpenseCalculator.calculateBalances(
        expenses: stressExpenses,
        settlements: [],
        members: fiveMembers,
      );

      final sumNetBalances = balances.values.fold(0, (a, b) => a + b.netBalancePaise);
      expect(sumNetBalances, 0); // Strict zero-sum invariant

      // Greedy transfers completely resolve all balances
      final transfers = ExpenseCalculator.calculateSettleUpTransfers(balances);
      // Settle-up can require at most N - 1 = 4 transfers
      expect(transfers.length, lessThanOrEqualTo(4));
    });

    test('Serialization round-trip for ExpenseModel and SettlementModel', () {
      final now = DateTime.now();
      final expense = ExpenseModel(
        id: 'e_serial',
        groupId: 'g_serial',
        title: 'Snacks & Chai',
        amountPaise: 4500,
        paidByUserId: 'u1',
        paidByName: 'Person 1',
        splitMemberIds: ['u1', 'u2'],
        date: now,
        category: 'food',
        note: 'Best samosas',
        createdBy: 'u1',
      );

      final map = expense.toMap();
      final revived = ExpenseModel.fromMap(map);
      expect(revived.id, expense.id);
      expect(revived.amountPaise, 4500);
      expect(revived.formattedAmount, '₹45');
      expect(revived.title, 'Snacks & Chai');

      final settlement = SettlementModel(
        id: 's_serial',
        groupId: 'g_serial',
        fromUserId: 'u1',
        fromUserName: 'Person 1',
        toUserId: 'u2',
        toUserName: 'Person 2',
        amountPaise: 2250,
        date: now,
        status: 'pending',
        notes: 'Paid via UPI',
        createdBy: 'u1',
      );

      final sMap = settlement.toMap();
      final sRevived = SettlementModel.fromMap(sMap);
      expect(sRevived.id, settlement.id);
      expect(sRevived.amountPaise, 2250);
      expect(sRevived.formattedAmount, '₹22.50');
      expect(sRevived.isPending, isTrue);
    });
  });
}
