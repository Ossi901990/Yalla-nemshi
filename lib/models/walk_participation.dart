import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a user's participation in a walk
/// Stored at: /users/{userId}/walks/{walkId}
class WalkParticipation {
  final String userId;
  final String walkId;
  final DateTime joinedAt;
  final bool completed; // User marked walk as completed
  final double? actualDistanceKm; // Distance user actually walked
  final Duration? actualDuration; // How long user walked
  final bool leftEarly; // User left before end
  final DateTime? leftAt; // When user left
  final bool hostCancelled; // Host cancelled this walk
  final String? notes; // User's notes about this walk

  WalkParticipation({
    required this.userId,
    required this.walkId,
    required this.joinedAt,
    this.completed = false,
    this.actualDistanceKm,
    this.actualDuration,
    this.leftEarly = false,
    this.leftAt,
    this.hostCancelled = false,
    this.notes,
  });

  /// Create WalkParticipation from Firestore document
  factory WalkParticipation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WalkParticipation(
      userId: data['userId'] ?? '',
      walkId: doc.id,
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completed: data['completed'] ?? false,
      actualDistanceKm: (data['actualDistanceKm'] as num?)?.toDouble(),
      actualDuration: data['actualDuration'] != null
          ? Duration(seconds: data['actualDuration'] as int)
          : null,
      leftEarly: data['leftEarly'] ?? false,
      leftAt: (data['leftAt'] as Timestamp?)?.toDate(),
      hostCancelled: data['hostCancelled'] ?? false,
      notes: data['notes'],
    );
  }

  /// Convert WalkParticipation to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'completed': completed,
      'actualDistanceKm': actualDistanceKm,
      'actualDuration': actualDuration?.inSeconds,
      'leftEarly': leftEarly,
      'leftAt': leftAt != null ? Timestamp.fromDate(leftAt!) : null,
      'hostCancelled': hostCancelled,
      'notes': notes,
    };
  }

  /// Create a copy with updated fields
  WalkParticipation copyWith({
    String? userId,
    String? walkId,
    DateTime? joinedAt,
    bool? completed,
    double? actualDistanceKm,
    Duration? actualDuration,
    bool? leftEarly,
    DateTime? leftAt,
    bool? hostCancelled,
    String? notes,
  }) {
    return WalkParticipation(
      userId: userId ?? this.userId,
      walkId: walkId ?? this.walkId,
      joinedAt: joinedAt ?? this.joinedAt,
      completed: completed ?? this.completed,
      actualDistanceKm: actualDistanceKm ?? this.actualDistanceKm,
      actualDuration: actualDuration ?? this.actualDuration,
      leftEarly: leftEarly ?? this.leftEarly,
      leftAt: leftAt ?? this.leftAt,
      hostCancelled: hostCancelled ?? this.hostCancelled,
      notes: notes ?? this.notes,
    );
  }
}

/// Model representing user's walking statistics
/// Stored at: /users/{userId}/stats (single document)
class UserWalkStats {
  final String userId;
  final int totalWalksCompleted;
  final int totalWalksJoined;
  final int totalWalksHosted;
  final double totalDistanceKm;
  final Duration totalDuration;
  final int totalParticipants; // Total people user walked with
  final double averageDistancePerWalk;
  final Duration averageDurationPerWalk;
  final DateTime lastWalkDate;
  final DateTime createdAt;
  final DateTime lastUpdated;

  UserWalkStats({
    required this.userId,
    this.totalWalksCompleted = 0,
    this.totalWalksJoined = 0,
    this.totalWalksHosted = 0,
    this.totalDistanceKm = 0.0,
    Duration? totalDuration,
    this.totalParticipants = 0,
    this.averageDistancePerWalk = 0.0,
    Duration? averageDurationPerWalk,
    DateTime? lastWalkDate,
    DateTime? createdAt,
    DateTime? lastUpdated,
  })  : totalDuration = totalDuration ?? Duration.zero,
        averageDurationPerWalk = averageDurationPerWalk ?? Duration.zero,
        lastWalkDate = lastWalkDate ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        lastUpdated = lastUpdated ?? DateTime.now();

  factory UserWalkStats.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserWalkStats(
      userId: data['userId'] ?? '',
      totalWalksCompleted: data['totalWalksCompleted'] ?? 0,
      totalWalksJoined: data['totalWalksJoined'] ?? 0,
      totalWalksHosted: data['totalWalksHosted'] ?? 0,
      totalDistanceKm: (data['totalDistanceKm'] ?? 0.0).toDouble(),
      totalDuration: data['totalDuration'] != null
          ? Duration(seconds: data['totalDuration'] as int)
          : Duration.zero,
      totalParticipants: data['totalParticipants'] ?? 0,
      averageDistancePerWalk:
          (data['averageDistancePerWalk'] ?? 0.0).toDouble(),
      averageDurationPerWalk: data['averageDurationPerWalk'] != null
          ? Duration(seconds: data['averageDurationPerWalk'] as int)
          : Duration.zero,
      lastWalkDate: (data['lastWalkDate'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'totalWalksCompleted': totalWalksCompleted,
      'totalWalksJoined': totalWalksJoined,
      'totalWalksHosted': totalWalksHosted,
      'totalDistanceKm': totalDistanceKm,
      'totalDuration': totalDuration.inSeconds,
      'totalParticipants': totalParticipants,
      'averageDistancePerWalk': averageDistancePerWalk,
      'averageDurationPerWalk': averageDurationPerWalk.inSeconds,
      'lastWalkDate': Timestamp.fromDate(lastWalkDate),
      'createdAt': Timestamp.fromDate(createdAt),
      'lastUpdated': Timestamp.fromDate(DateTime.now()),
    };
  }

  UserWalkStats copyWith({
    int? totalWalksCompleted,
    int? totalWalksJoined,
    int? totalWalksHosted,
    double? totalDistanceKm,
    Duration? totalDuration,
    int? totalParticipants,
    double? averageDistancePerWalk,
    Duration? averageDurationPerWalk,
    DateTime? lastWalkDate,
  }) {
    return UserWalkStats(
      userId: userId,
      totalWalksCompleted: totalWalksCompleted ?? this.totalWalksCompleted,
      totalWalksJoined: totalWalksJoined ?? this.totalWalksJoined,
      totalWalksHosted: totalWalksHosted ?? this.totalWalksHosted,
      totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
      totalDuration: totalDuration ?? this.totalDuration,
      totalParticipants: totalParticipants ?? this.totalParticipants,
      averageDistancePerWalk:
          averageDistancePerWalk ?? this.averageDistancePerWalk,
      averageDurationPerWalk:
          averageDurationPerWalk ?? this.averageDurationPerWalk,
      lastWalkDate: lastWalkDate ?? this.lastWalkDate,
      createdAt: createdAt,
      lastUpdated: DateTime.now(),
    );
  }
}
