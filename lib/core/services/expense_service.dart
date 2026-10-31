import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/expense_model.dart';
import '../models/settlement_model.dart';
import '../models/group_activity_model.dart';
import '../models/group_message_model.dart';

/// Service managing group expenses, settlements, audit activity logging, and chat system notifications.
class ExpenseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _groupsRef => _firestore.collection('groups');

  // ═══════════════════════════════════════════════════════════════════
  // EXPENSE CRUD
  // ═══════════════════════════════════════════════════════════════════

  /// Add a new shared expense
  Future<ExpenseModel> addExpense({
    required String groupId,
    required String title,
    required int amountPaise,
    required String paidByUserId,
    required String paidByName,
    String? paidByPhotoUrl,
    required List<String> splitMemberIds,
    required DateTime date,
    String category = 'other',
    String? note,
    String? billPhotoUrl,
    String? itineraryStopId,
    int? itineraryDay,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) throw Exception('Title is required');
    if (trimmedTitle.length > 80) {
      throw Exception('Title must be 80 characters or fewer');
    }
    if (amountPaise <= 0) {
      throw Exception('Amount must be greater than zero');
    }
    if (amountPaise > 100000000) {
      // ₹10 Lakh maximum sensible limit
      throw Exception('Amount exceeds maximum allowed limit');
    }
    if (splitMemberIds.isEmpty) {
      throw Exception('Select at least one member to split with');
    }

    final docRef = _groupsRef.doc(groupId).collection('expenses').doc();
    final expense = ExpenseModel(
      id: docRef.id,
      groupId: groupId,
      title: trimmedTitle,
      amountPaise: amountPaise,
      paidByUserId: paidByUserId,
      paidByName: paidByName,
      paidByPhotoUrl: paidByPhotoUrl,
      splitMemberIds: splitMemberIds,
      date: date,
      category: category,
      note: note?.trim(),
      billPhotoUrl: billPhotoUrl,
      itineraryStopId: itineraryStopId,
      itineraryDay: itineraryDay,
      createdBy: user.uid,
    );

    final batch = _firestore.batch();
    batch.set(docRef, expense.toFirestore());

    // 1. Activity Log
    final logRef = _groupsRef.doc(groupId).collection('activity_logs').doc();
    final actorName = user.displayName ?? 'User';
    final activity = GroupActivityModel(
      id: logRef.id,
      actorId: user.uid,
      actorName: actorName,
      action: 'expense_add',
      details: '$actorName added expense: $trimmedTitle (${expense.formattedAmount})',
    );
    batch.set(logRef, activity.toFirestore());

    // 2. Chat System Message
    final msgRef = _groupsRef.doc(groupId).collection('messages').doc();
    final systemMsg = GroupMessageModel(
      id: msgRef.id,
      senderId: 'system',
      senderName: 'System',
      type: 'system',
      content: '$actorName added an expense: $trimmedTitle, ${expense.formattedAmount}',
    );
    batch.set(msgRef, systemMsg.toFirestore());

    await batch.commit();
    return expense;
  }

  /// Update an existing expense (only creator or group admin)
  Future<void> updateExpense({
    required String groupId,
    required ExpenseModel oldExpense,
    required String title,
    required int amountPaise,
    required String paidByUserId,
    required String paidByName,
    String? paidByPhotoUrl,
    required List<String> splitMemberIds,
    required DateTime date,
    String category = 'other',
    String? note,
    String? billPhotoUrl,
    String? itineraryStopId,
    int? itineraryDay,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) throw Exception('Title is required');
    if (trimmedTitle.length > 80) {
      throw Exception('Title must be 80 characters or fewer');
    }
    if (amountPaise <= 0) {
      throw Exception('Amount must be greater than zero');
    }
    if (splitMemberIds.isEmpty) {
      throw Exception('Select at least one member to split with');
    }

    final updated = oldExpense.copyWith(
      title: trimmedTitle,
      amountPaise: amountPaise,
      paidByUserId: paidByUserId,
      paidByName: paidByName,
      paidByPhotoUrl: paidByPhotoUrl,
      splitMemberIds: splitMemberIds,
      date: date,
      category: category,
      note: note?.trim(),
      billPhotoUrl: billPhotoUrl,
      itineraryStopId: itineraryStopId,
      itineraryDay: itineraryDay,
      updatedAt: DateTime.now(),
    );

    final batch = _firestore.batch();
    final docRef = _groupsRef.doc(groupId).collection('expenses').doc(oldExpense.id);
    batch.set(docRef, updated.toFirestore(), SetOptions(merge: true));

    // Activity Log
    final logRef = _groupsRef.doc(groupId).collection('activity_logs').doc();
    final actorName = user.displayName ?? 'User';
    final activity = GroupActivityModel(
      id: logRef.id,
      actorId: user.uid,
      actorName: actorName,
      action: 'expense_edit',
      details: '$actorName edited expense: $trimmedTitle (${updated.formattedAmount})',
    );
    batch.set(logRef, activity.toFirestore());

    await batch.commit();
  }

  /// Soft-delete an expense (preserves audit trail)
  Future<void> deleteExpense({
    required String groupId,
    required ExpenseModel expense,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final batch = _firestore.batch();
    final docRef = _groupsRef.doc(groupId).collection('expenses').doc(expense.id);

    batch.update(docRef, {
      'isDeleted': true,
      'deletedBy': user.uid,
      'deletedAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });

    // Activity Log
    final logRef = _groupsRef.doc(groupId).collection('activity_logs').doc();
    final actorName = user.displayName ?? 'User';
    final activity = GroupActivityModel(
      id: logRef.id,
      actorId: user.uid,
      actorName: actorName,
      action: 'expense_delete',
      details: '$actorName deleted expense: ${expense.title} (${expense.formattedAmount})',
    );
    batch.set(logRef, activity.toFirestore());

    await batch.commit();
  }

  /// Stream active (non-deleted) expenses for a group
  Stream<List<ExpenseModel>> streamExpenses(String groupId) {
    return _groupsRef
        .doc(groupId)
        .collection('expenses')
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => ExpenseModel.fromFirestore(doc))
              .where((expense) => !expense.isDeleted)
              .toList();
          list.sort((a, b) => b.date.compareTo(a.date));
          return list;
        });
  }

  // ═══════════════════════════════════════════════════════════════════
  // SETTLEMENTS (RECORDING PEER PAYMENTS)
  // ═══════════════════════════════════════════════════════════════════

  /// Record an offline settlement payment with "pending" status
  Future<SettlementModel> recordSettlement({
    required String groupId,
    required String fromUserId,
    required String fromUserName,
    required String toUserId,
    required String toUserName,
    required int amountPaise,
    String? notes,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');
    if (amountPaise <= 0) throw Exception('Settlement amount must be positive');
    if (fromUserId == toUserId) {
      throw Exception('Cannot record settlement to oneself');
    }

    final docRef = _groupsRef.doc(groupId).collection('settlements').doc();
    final settlement = SettlementModel(
      id: docRef.id,
      groupId: groupId,
      fromUserId: fromUserId,
      fromUserName: fromUserName,
      toUserId: toUserId,
      toUserName: toUserName,
      amountPaise: amountPaise,
      date: DateTime.now(),
      status: 'pending',
      notes: notes?.trim(),
      createdBy: user.uid,
    );

    final batch = _firestore.batch();
    batch.set(docRef, settlement.toFirestore());

    // 1. Activity Log
    final logRef = _groupsRef.doc(groupId).collection('activity_logs').doc();
    final activity = GroupActivityModel(
      id: logRef.id,
      actorId: user.uid,
      actorName: fromUserName,
      action: 'settlement_record',
      details: '$fromUserName marked ${settlement.formattedAmount} as paid to $toUserName',
    );
    batch.set(logRef, activity.toFirestore());

    // 2. Chat System Message
    final msgRef = _groupsRef.doc(groupId).collection('messages').doc();
    final systemMsg = GroupMessageModel(
      id: msgRef.id,
      senderId: 'system',
      senderName: 'System',
      type: 'system',
      content: '$fromUserName marked ${settlement.formattedAmount} as paid to $toUserName (Pending confirmation)',
    );
    batch.set(msgRef, systemMsg.toFirestore());

    await batch.commit();
    return settlement;
  }

  /// Receiver confirms that the payment was received
  Future<void> confirmSettlement({
    required String groupId,
    required SettlementModel settlement,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final batch = _firestore.batch();
    final docRef = _groupsRef.doc(groupId).collection('settlements').doc(settlement.id);

    batch.update(docRef, {
      'status': 'confirmed',
      'updatedAt': Timestamp.now(),
    });

    // 1. Activity Log
    final logRef = _groupsRef.doc(groupId).collection('activity_logs').doc();
    final receiverName = settlement.toUserName;
    final activity = GroupActivityModel(
      id: logRef.id,
      actorId: user.uid,
      actorName: receiverName,
      action: 'settlement_confirm',
      details: '$receiverName confirmed receiving ${settlement.formattedAmount} from ${settlement.fromUserName}',
    );
    batch.set(logRef, activity.toFirestore());

    // 2. Chat System Message
    final msgRef = _groupsRef.doc(groupId).collection('messages').doc();
    final systemMsg = GroupMessageModel(
      id: msgRef.id,
      senderId: 'system',
      senderName: 'System',
      type: 'system',
      content: '$receiverName confirmed receiving ${settlement.formattedAmount} from ${settlement.fromUserName}',
    );
    batch.set(msgRef, systemMsg.toFirestore());

    await batch.commit();
  }

  /// Receiver rejects the settlement with a reason
  Future<void> rejectSettlement({
    required String groupId,
    required SettlementModel settlement,
    required String reason,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final batch = _firestore.batch();
    final docRef = _groupsRef.doc(groupId).collection('settlements').doc(settlement.id);

    batch.update(docRef, {
      'status': 'rejected',
      'rejectionReason': reason.trim(),
      'updatedAt': Timestamp.now(),
    });

    // Activity Log
    final logRef = _groupsRef.doc(groupId).collection('activity_logs').doc();
    final receiverName = settlement.toUserName;
    final activity = GroupActivityModel(
      id: logRef.id,
      actorId: user.uid,
      actorName: receiverName,
      action: 'settlement_reject',
      details: '$receiverName rejected payment from ${settlement.fromUserName}: ${reason.trim()}',
    );
    batch.set(logRef, activity.toFirestore());

    await batch.commit();
  }

  /// Payer cancels their pending settlement
  Future<void> cancelSettlement({
    required String groupId,
    required SettlementModel settlement,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final batch = _firestore.batch();
    final docRef = _groupsRef.doc(groupId).collection('settlements').doc(settlement.id);

    batch.update(docRef, {
      'status': 'cancelled',
      'updatedAt': Timestamp.now(),
    });

    // Activity Log
    final logRef = _groupsRef.doc(groupId).collection('activity_logs').doc();
    final payerName = settlement.fromUserName;
    final activity = GroupActivityModel(
      id: logRef.id,
      actorId: user.uid,
      actorName: payerName,
      action: 'settlement_cancel',
      details: '$payerName cancelled pending payment of ${settlement.formattedAmount} to ${settlement.toUserName}',
    );
    batch.set(logRef, activity.toFirestore());

    await batch.commit();
  }

  /// Stream settlements for a group
  Stream<List<SettlementModel>> streamSettlements(String groupId) {
    return _groupsRef
        .doc(groupId)
        .collection('settlements')
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => SettlementModel.fromFirestore(doc))
              .toList();
          list.sort((a, b) => b.date.compareTo(a.date));
          return list;
        });
  }

  /// Fetch active expenses once (for batch calculations and previews)
  Future<List<ExpenseModel>> getExpensesOnce(String groupId) async {
    final snapshot = await _groupsRef.doc(groupId).collection('expenses').get();
    final list = snapshot.docs
        .map((d) => ExpenseModel.fromFirestore(d))
        .where((e) => !e.isDeleted)
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// Fetch settlements once
  Future<List<SettlementModel>> getSettlementsOnce(String groupId) async {
    final snapshot = await _groupsRef.doc(groupId).collection('settlements').get();
    final list = snapshot.docs.map((d) => SettlementModel.fromFirestore(d)).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }
}
