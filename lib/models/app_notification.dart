// lib/models/app_notification.dart

enum NotificationType {
  // Walk-related (Host)
  walkJoined,
  walkLeft,
  walkInterested,
  walkFull,
  participantConfirmed,
  participantDeclined,
  walkReviewed,
  
  // Walk-related (Participant)
  walkCancelled,
  walkRescheduled,
  walkLocationChanged,
  walkReminder,
  walkStarting,
  walkEnded,
  walkHostLeft,
  
  // Discovery
  nearbyWalk,
  suggestedWalk,
  
  // Friends
  friendRequest,
  friendAccepted,
  friendJoinedWalk,
  friendHosting,
  friendMilestone,
  friendBadge,
  
  // Messages
  dmMessage,
  walkChatMessage,
  hostAnnouncement,
  mentioned,
  
  // Achievements
  milestoneReached,
  badgeEarned,
  streakMilestone,
  goalAchieved,
  monthlySummary,
  leaderboardUpdate,
  personalRecord,
  
  // Safety
  weatherAlert,
  safetyCheckIn,
  emergencyAlert,
  
  // System
  appUpdate,
  newFeature,
  accountSecurity,
  systemMaintenance,
  
  // Re-engagement
  inactiveReminder,
  missedGoal,
  
  // Analytics
  weeklyDigest,
  monthlyAchievements,
}

class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  
  // Context fields
  final String? walkId;
  final String? userId;
  final String? threadId;
  final Map<String, dynamic>? data;
  
  // Expiry
  final DateTime? expiresAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.walkId,
    this.userId,
    this.threadId,
    this.data,
    this.expiresAt,
  });

  AppNotification copyWith({
    String? id,
    NotificationType? type,
    String? title,
    String? message,
    DateTime? timestamp,
    bool? isRead,
    String? walkId,
    String? userId,
    String? threadId,
    Map<String, dynamic>? data,
    DateTime? expiresAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      walkId: walkId ?? this.walkId,
      userId: userId ?? this.userId,
      threadId: threadId ?? this.threadId,
      data: data ?? this.data,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'walkId': walkId,
      'userId': userId,
      'threadId': threadId,
      'data': data,
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String? ?? '',
      type: _parseNotificationType(json['type'] as String?),
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      timestamp:
          DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      isRead: json['isRead'] as bool? ?? false,
      walkId: json['walkId'] as String?,
      userId: json['userId'] as String?,
      threadId: json['threadId'] as String?,
      data: json['data'] as Map<String, dynamic>?,
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'] as String)
          : null,
    );
  }

  // Firestore constructor
  factory AppNotification.fromFirestore(Map<String, dynamic> data, String docId) {
    return AppNotification(
      id: docId,
      type: _parseNotificationType(data['type'] as String?),
      title: data['title'] as String? ?? '',
      message: data['message'] as String? ?? '',
      timestamp: data['timestamp'] != null
          ? (data['timestamp'] as dynamic).toDate()
          : DateTime.now(),
      isRead: data['isRead'] as bool? ?? false,
      walkId: data['walkId'] as String?,
      userId: data['userId'] as String?,
      threadId: data['threadId'] as String?,
      data: data['data'] as Map<String, dynamic>?,
      expiresAt: data['expiresAt'] != null
          ? (data['expiresAt'] as dynamic).toDate()
          : null,
    );
  }

  // Convert to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'type': type.name,
      'title': title,
      'message': message,
      'timestamp': timestamp,
      'isRead': isRead,
      if (walkId != null) 'walkId': walkId,
      if (userId != null) 'userId': userId,
      if (threadId != null) 'threadId': threadId,
      if (data != null) 'data': data,
      if (expiresAt != null) 'expiresAt': expiresAt,
    };
  }

  static NotificationType _parseNotificationType(String? typeString) {
    if (typeString == null) return NotificationType.systemMaintenance;
    
    try {
      return NotificationType.values.firstWhere(
        (t) => t.name == typeString,
        orElse: () => NotificationType.systemMaintenance,
      );
    } catch (_) {
      return NotificationType.systemMaintenance;
    }
  }

  // Get icon for notification type
  String get icon {
    switch (type) {
      case NotificationType.walkJoined:
      case NotificationType.participantConfirmed:
        return '🎉';
      case NotificationType.walkCancelled:
      case NotificationType.walkLeft:
        return '❌';
      case NotificationType.walkReminder:
      case NotificationType.walkStarting:
        return '⏰';
      case NotificationType.walkEnded:
        return '✅';
      case NotificationType.nearbyWalk:
      case NotificationType.suggestedWalk:
        return '📍';
      case NotificationType.friendRequest:
      case NotificationType.friendAccepted:
        return '👋';
      case NotificationType.dmMessage:
      case NotificationType.walkChatMessage:
        return '💬';
      case NotificationType.badgeEarned:
      case NotificationType.milestoneReached:
        return '🏆';
      case NotificationType.weatherAlert:
      case NotificationType.emergencyAlert:
        return '⚠️';
      case NotificationType.weeklyDigest:
      case NotificationType.monthlyAchievements:
        return '📊';
      default:
        return '🔔';
    }
  }

  // Check if notification is expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  // Get priority level
  int get priority {
    switch (type) {
      case NotificationType.emergencyAlert:
      case NotificationType.safetyCheckIn:
      case NotificationType.weatherAlert:
        return 3; // Critical
      case NotificationType.walkStarting:
      case NotificationType.walkCancelled:
      case NotificationType.dmMessage:
      case NotificationType.friendRequest:
        return 2; // High
      case NotificationType.walkJoined:
      case NotificationType.walkReminder:
      case NotificationType.nearbyWalk:
      case NotificationType.badgeEarned:
        return 1; // Medium
      default:
        return 0; // Low
    }
  }
}
