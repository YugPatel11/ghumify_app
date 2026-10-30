import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a shared expense within a travel group.
/// Stored in integer paise (1 INR = 100 paise) to eliminate floating-point rounding errors.
class ExpenseModel {
  final String id;
  final String groupId;
  final String title;
  final int amountPaise; // 1 INR = 100 paise (e.g. 15000 = ₹150.00)
  final String currency; // ISO code, defaults to "INR"
  final String paidByUserId;
  final String paidByName;
  final String? paidByPhotoUrl;
  final List<String> splitMemberIds; // User IDs of members splitting this expense
  final String splitType; // "equal" (v1), extensible to "exact", "percentage", "shares"
  final DateTime date;
  final String category; // "food", "travel", "stay", "tickets", "shopping", "other"
  final String? note;
  final String? billPhotoUrl;
  final String? itineraryStopId;
  final int? itineraryDay;
  final String createdBy;
  final bool isDeleted; // Soft delete
  final String? deletedBy;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  ExpenseModel({
    required this.id,
    required this.groupId,
    required this.title,
    required this.amountPaise,
    this.currency = 'INR',
    required this.paidByUserId,
    required this.paidByName,
    this.paidByPhotoUrl,
    required this.splitMemberIds,
    this.splitType = 'equal',
    required this.date,
    this.category = 'other',
    this.note,
    this.billPhotoUrl,
    this.itineraryStopId,
    this.itineraryDay,
    required this.createdBy,
    this.isDeleted = false,
    this.deletedBy,
    this.deletedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Rupee representation of the expense (for UI display only)
  double get amountRupees => amountPaise / 100.0;

  /// Formatted rupee string e.g. "₹1,250.50" or "₹50"
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

  /// Calculates per-person share in paise (equal split base)
  int calculateSharePaise(int totalMembers) {
    if (totalMembers <= 0) return 0;
    return amountPaise ~/ totalMembers;
  }

  factory ExpenseModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExpenseModel.fromMap(data, id: doc.id);
  }

  factory ExpenseModel.fromMap(Map<String, dynamic> data, {String? id}) {
    return ExpenseModel(
      id: id ?? data['id'] ?? '',
      groupId: data['groupId'] ?? '',
      title: data['title'] ?? '',
      amountPaise: (data['amountPaise'] as num?)?.toInt() ?? 0,
      currency: data['currency'] ?? 'INR',
      paidByUserId: data['paidByUserId'] ?? '',
      paidByName: data['paidByName'] ?? '',
      paidByPhotoUrl: data['paidByPhotoUrl'],
      splitMemberIds: List<String>.from(data['splitMemberIds'] ?? []),
      splitType: data['splitType'] ?? 'equal',
      date: _parseDateTime(data['date']),
      category: data['category'] ?? 'other',
      note: data['note'],
      billPhotoUrl: data['billPhotoUrl'],
      itineraryStopId: data['itineraryStopId'],
      itineraryDay: (data['itineraryDay'] as num?)?.toInt(),
      createdBy: data['createdBy'] ?? '',
      isDeleted: data['isDeleted'] ?? false,
      deletedBy: data['deletedBy'],
      deletedAt: _parseNullableDateTime(data['deletedAt']),
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

  static DateTime? _parseNullableDateTime(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is String) return DateTime.tryParse(val);
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    return null;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'groupId': groupId,
      'title': title,
      'amountPaise': amountPaise,
      'currency': currency,
      'paidByUserId': paidByUserId,
      'paidByName': paidByName,
      'paidByPhotoUrl': paidByPhotoUrl,
      'splitMemberIds': splitMemberIds,
      'splitType': splitType,
      'date': Timestamp.fromDate(date),
      'category': category,
      'note': note,
      'billPhotoUrl': billPhotoUrl,
      'itineraryStopId': itineraryStopId,
      'itineraryDay': itineraryDay,
      'createdBy': createdBy,
      'isDeleted': isDeleted,
      'deletedBy': deletedBy,
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groupId': groupId,
      'title': title,
      'amountPaise': amountPaise,
      'currency': currency,
      'paidByUserId': paidByUserId,
      'paidByName': paidByName,
      'paidByPhotoUrl': paidByPhotoUrl,
      'splitMemberIds': splitMemberIds,
      'splitType': splitType,
      'date': date.toIso8601String(),
      'category': category,
      'note': note,
      'billPhotoUrl': billPhotoUrl,
      'itineraryStopId': itineraryStopId,
      'itineraryDay': itineraryDay,
      'createdBy': createdBy,
      'isDeleted': isDeleted,
      'deletedBy': deletedBy,
      'deletedAt': deletedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  ExpenseModel copyWith({
    String? title,
    int? amountPaise,
    String? currency,
    String? paidByUserId,
    String? paidByName,
    String? paidByPhotoUrl,
    List<String>? splitMemberIds,
    String? splitType,
    DateTime? date,
    String? category,
    String? note,
    String? billPhotoUrl,
    String? itineraryStopId,
    int? itineraryDay,
    bool? isDeleted,
    String? deletedBy,
    DateTime? deletedAt,
    DateTime? updatedAt,
  }) {
    return ExpenseModel(
      id: id,
      groupId: groupId,
      title: title ?? this.title,
      amountPaise: amountPaise ?? this.amountPaise,
      currency: currency ?? this.currency,
      paidByUserId: paidByUserId ?? this.paidByUserId,
      paidByName: paidByName ?? this.paidByName,
      paidByPhotoUrl: paidByPhotoUrl ?? this.paidByPhotoUrl,
      splitMemberIds: splitMemberIds ?? this.splitMemberIds,
      splitType: splitType ?? this.splitType,
      date: date ?? this.date,
      category: category ?? this.category,
      note: note ?? this.note,
      billPhotoUrl: billPhotoUrl ?? this.billPhotoUrl,
      itineraryStopId: itineraryStopId ?? this.itineraryStopId,
      itineraryDay: itineraryDay ?? this.itineraryDay,
      createdBy: createdBy,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedBy: deletedBy ?? this.deletedBy,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
