// lib/models/firestore_user.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// User profile stored in Firestore at /users/{uid}
class FirestoreUser {
  final String uid;
  final String email;
  final String displayName;
  final String displayNameLower;
  final String? photoURL; // Firebase Storage URL
  final String? bio;
  final int? age;
  final String? gender;
  final DateTime createdAt;
  final DateTime lastUpdated;

  // Optional stats (can be computed or cached)
  final int walksJoined;
  final int walksHosted;
  final double totalKm;

  // Privacy settings
  final bool profilePublic;

  FirestoreUser({
    required this.uid,
    required this.email,
    required this.displayName,
    String? displayNameLower,
    this.photoURL,
    this.bio,
    this.age,
    this.gender,
    required this.createdAt,
    required this.lastUpdated,
    this.walksJoined = 0,
    this.walksHosted = 0,
    this.totalKm = 0.0,
    this.profilePublic = true,
  }) : displayNameLower = (displayNameLower ?? displayName).toLowerCase();

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'displayNameLower': displayNameLower,
      'bio': bio,
      'age': age,
      'gender': gender,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'walksJoined': walksJoined,
      'walksHosted': walksHosted,
      'totalKm': totalKm,
      'profilePublic': profilePublic,
    };
  }

  /// Create from Firestore document
  factory FirestoreUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FirestoreUser.fromMap(data);
  }

  /// Create from map
  factory FirestoreUser.fromMap(Map<String, dynamic> map) {
    return FirestoreUser(
      uid: map['uid'] as String? ?? '',
      email: map['email'] as String? ?? '',
        displayName: map['displayName'] as String? ?? '',
        displayNameLower: (map['displayNameLower'] as String?) ??
          (map['displayName'] as String? ?? '').toLowerCase(),
      photoURL: map['photoURL'] as String?,
      bio: map['bio'] as String?,
      age: map['age'] as int?,
      gender: map['gender'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastUpdated: (map['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      walksJoined: map['walksJoined'] as int? ?? 0,
      walksHosted: map['walksHosted'] as int? ?? 0,
      totalKm: (map['totalKm'] as num?)?.toDouble() ?? 0.0,
      profilePublic: map['profilePublic'] as bool? ?? true,
    );
  }

  /// Create a copy with modifications
  FirestoreUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? displayNameLower,
    String? photoURL,
    String? bio,
    int? age,
    String? gender,
    DateTime? createdAt,
    DateTime? lastUpdated,
    int? walksJoined,
    int? walksHosted,
    double? totalKm,
    bool? profilePublic,
  }) {
    return FirestoreUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      displayNameLower: displayNameLower ?? this.displayNameLower,
      photoURL: photoURL ?? this.photoURL,
      bio: bio ?? this.bio,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      walksJoined: walksJoined ?? this.walksJoined,
      walksHosted: walksHosted ?? this.walksHosted,
      totalKm: totalKm ?? this.totalKm,
      profilePublic: profilePublic ?? this.profilePublic,
    );
  }
}
