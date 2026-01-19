import 'package:cloud_firestore/cloud_firestore.dart';

String? _cleanString(dynamic value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  return trimmed;
}

DateTime? _timestampToDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

class FriendProfile {
  final String uid;
  final String displayName;
  final String? photoUrl;
  final String? bio;
  final double? hostRating;
  final int totalWalksHosted;
  final int totalWalksJoined;
  final double totalDistanceKm;
  final int totalMinutes;
  final DateTime? lastActiveAt;
  final DateTime? updatedAt;

  const FriendProfile({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    this.bio,
    this.hostRating,
    required this.totalWalksHosted,
    required this.totalWalksJoined,
    required this.totalDistanceKm,
    required this.totalMinutes,
    this.lastActiveAt,
    this.updatedAt,
  });

  factory FriendProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Friend profile missing data for ${doc.id}');
    }
    return FriendProfile(
      uid: doc.id,
      displayName: (data['displayName'] ?? 'Walker') as String,
      photoUrl: _cleanString(data['photoUrl']),
      bio: _cleanString(data['bio']),
      hostRating: _toDouble(data['hostRating']),
      totalWalksHosted: _toInt(data['totalWalksHosted']),
      totalWalksJoined: _toInt(data['totalWalksJoined']),
      totalDistanceKm: _toDouble(data['totalDistanceKm']) ?? 0,
      totalMinutes: _toInt(data['totalMinutes']),
      lastActiveAt: _timestampToDate(data['lastActiveAt']),
      updatedAt: _timestampToDate(data['updatedAt']),
    );
  }
}

class FriendWalkSummary {
  final String walkId;
  final String role;
  final String title;
  final String? meetingPlaceName;
  final String category;
  final String visibility;
  final String? status;
  final DateTime? startTime;
  final DateTime? endTime;
  final double? distanceKm;
  final double? estimatedDurationMinutes;
  final String? coverPhotoUrl;
  final String? hostUid;

  const FriendWalkSummary({
    required this.walkId,
    required this.role,
    required this.title,
    this.meetingPlaceName,
    required this.category,
    required this.visibility,
    this.status,
    this.startTime,
    this.endTime,
    this.distanceKm,
    this.estimatedDurationMinutes,
    this.coverPhotoUrl,
    this.hostUid,
  });

  bool get isUpcoming => category == 'upcoming';
  bool get isPast => category == 'past';

  factory FriendWalkSummary.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Friend walk summary missing data for ${doc.id}');
    }
    return FriendWalkSummary(
      walkId: doc.id,
      role: (data['role'] ?? 'participant') as String,
      title: (data['title'] ?? 'Walk') as String,
      meetingPlaceName: _cleanString(data['meetingPlaceName']),
      category: (data['category'] ?? 'unknown') as String,
      visibility: (data['visibility'] ?? 'open') as String,
      status: data['status'] as String?,
      startTime: _timestampToDate(data['startTime']),
      endTime: _timestampToDate(data['endTime']),
      distanceKm: _toDouble(data['distanceKm']),
      estimatedDurationMinutes: _toDouble(data['estimatedDurationMinutes']),
      coverPhotoUrl: _cleanString(data['coverPhotoUrl']),
      hostUid: data['hostUid'] as String?,
    );
  }
}
