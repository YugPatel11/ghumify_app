import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? photoUrl;
  final String preferredLanguage;
  final String foodPreference;
  final List<String> interests;
  final List<String> savedTripIds;
  final bool isPremium;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
    this.preferredLanguage = 'en',
    this.foodPreference = 'all',
    this.interests = const [],
    this.savedTripIds = const [],
    this.isPremium = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory UserModel.fromMap(Map<String, dynamic> data, {String? uid}) {
    return UserModel(
      uid: uid ?? data['uid'] ?? '',
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      photoUrl: data['photoUrl'],
      preferredLanguage: data['preferredLanguage'] ?? 'en',
      foodPreference: data['foodPreference'] ?? 'all',
      interests: List<String>.from(data['interests'] ?? []),
      savedTripIds: List<String>.from(data['savedTripIds'] ?? []),
      isPremium: data['isPremium'] ?? false,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] is Timestamp
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.tryParse(data['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] is Timestamp
              ? (data['updatedAt'] as Timestamp).toDate()
              : DateTime.tryParse(data['updatedAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel.fromMap(data, uid: doc.id);
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'preferredLanguage': preferredLanguage,
      'foodPreference': foodPreference,
      'interests': interests,
      'savedTripIds': savedTripIds,
      'isPremium': isPremium,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };
  }

  UserModel copyWith({
    String? name,
    String? email,
    String? photoUrl,
    String? preferredLanguage,
    String? foodPreference,
    List<String>? interests,
    List<String>? savedTripIds,
    bool? isPremium,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      foodPreference: foodPreference ?? this.foodPreference,
      interests: interests ?? this.interests,
      savedTripIds: savedTripIds ?? this.savedTripIds,
      isPremium: isPremium ?? this.isPremium,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
