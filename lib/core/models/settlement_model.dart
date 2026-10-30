import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a settlement payment between two group members.
/// Records offline payments (cash, UPI, bank transfer) with confirmation workflow.
class SettlementModel {
  final String id;
  final String groupId;
  final String fromUserId; // Debtor who paid
  final String fromUserName;
  final String toUserId; // Creditor who received
  final String toUserName;
  final int amountPaise; // 1 INR = 100 paise
  final String currency; // default "INR"
  final DateTime date;
  final String status; // "pending" | "confirmed" | "rejected" | "cancelled"
  final String? rejectionReason;
  final String? notes;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  SettlementModel({
    required this.id,
    required this.groupId,
    required this.fromUserId,
    required this.fromUserName,
    required this.toUserId,
    required this.toUserName,
    required this.amountPaise,
    this.currency = 'INR',
    required this.date,
    this.status = 'pending',
    this.rejectionReason,
    this.notes,
    required this.createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  double get amountRupees => amountPaise / 100.0;

  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';
  bool get isRejected => status == 'rejected';
  bool get isCancelled => status == 'cancelled';

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

  factory SettlementModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SettlementModel.fromMap(data, id: doc.id);
  }

  factory SettlementModel.fromMap(Map<String, dynamic> data, {String? id}) {
    return SettlementModel(
      id: id ?? data['id'] ?? '',
      groupId: data['groupId'] ?? '',
      fromUserId: data['fromUserId'] ?? '',
      fromUserName: data['fromUserName'] ?? '',
      toUserId: data['toUserId'] ?? '',
      toUserName: data['toUserName'] ?? '',
      amountPaise: (data['amountPaise'] as num?)?.toInt() ?? 0,
      currency: data['currency'] ?? 'INR',
      date: _parseDateTime(data['date']),
      status: data['status'] ?? 'pending',
      rejectionReason: data['rejectionReason'],
      notes: data['notes'],
      createdBy: data['createdBy'] ?? '',
      createdAt: _parseDateTime(data['createdAt']),
      updatedAt: _parseDateTime(data['updatedAt']),
    );
  }

  static DateTime _parseDateTime(dynamic val) {
    if (val == null) return DateTime.now();
    if (val is Timestamp) return val.toDate();
    if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    return DateTime.now();
  }

  Map<String, dynamic> toFirestore() {
    return {
      'groupId': groupId,
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'toUserId': toUserId,
      'toUserName': toUserName,
      'amountPaise': amountPaise,
      'currency': currency,
      'date': Timestamp.fromDate(date),
      'status': status,
      'rejectionReason': rejectionReason,
      'notes': notes,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groupId': groupId,
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'toUserId': toUserId,
      'toUserName': toUserName,
      'amountPaise': amountPaise,
      'currency': currency,
      'date': date.toIso8601String(),
      'status': status,
      'rejectionReason': rejectionReason,
      'notes': notes,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  SettlementModel copyWith({
    String? status,
    String? rejectionReason,
    String? notes,
    DateTime? updatedAt,
  }) {
    return SettlementModel(
      id: id,
      groupId: groupId,
      fromUserId: fromUserId,
      fromUserName: fromUserName,
      toUserId: toUserId,
      toUserName: toUserName,
      amountPaise: amountPaise,
      currency: currency,
      date: date,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      notes: notes ?? this.notes,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
