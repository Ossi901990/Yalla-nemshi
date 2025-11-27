// lib/models/walk_event.dart

class WalkEvent {
  final String id;
  final String title;
  final DateTime dateTime;
  final double distanceKm;
  final String gender; // e.g. "Mixed", "Women only", "Men only"
  final bool isOwner;
  final String? meetingPlaceName;
  final double? meetingLat;
  final double? meetingLng;
  final String? description;

  /// Whether the current user has joined this event.
  bool joined;

  /// Whether the current user has marked this event as "interested".
  bool interested;

  /// Whether the host has cancelled this walk.
  final bool cancelled;

  /// Optional: tags for a walk, e.g. ["Scenic", "Dog friendly"] (for future use)
  final List<String> tags;

  /// Optional: comfort/vibe, e.g. "Social", "Quiet", "Workout" (for future use)
  final String? comfortLevel;

  /// Optional: recurring rule text, e.g. "Weekly on Saturday" (for future use)
  final String? recurringRule;

  /// Optional: user’s private notes about this event (for future use)
  final String? userNotes;

  WalkEvent({
    required this.id,
    required this.title,
    required this.dateTime,
    required this.distanceKm,
    required this.gender,
    this.isOwner = false,
    this.joined = false,
    this.interested = false,
    this.meetingPlaceName,
    this.meetingLat,
    this.meetingLng,
    this.description,
    this.cancelled = false,
    List<String>? tags,
    this.comfortLevel,
    this.recurringRule,
    this.userNotes,
  }) : tags = tags ?? const [];

  WalkEvent copyWith({
    String? id,
    String? title,
    DateTime? dateTime,
    double? distanceKm,
    String? gender,
    bool? isOwner,
    bool? joined,
    bool? interested,
    String? meetingPlaceName,
    double? meetingLat,
    double? meetingLng,
    String? description,
    bool? cancelled,
    List<String>? tags,
    String? comfortLevel,
    String? recurringRule,
    String? userNotes,
  }) {
    return WalkEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      dateTime: dateTime ?? this.dateTime,
      distanceKm: distanceKm ?? this.distanceKm,
      gender: gender ?? this.gender,
      isOwner: isOwner ?? this.isOwner,
      joined: joined ?? this.joined,
      interested: interested ?? this.interested,
      meetingPlaceName: meetingPlaceName ?? this.meetingPlaceName,
      meetingLat: meetingLat ?? this.meetingLat,
      meetingLng: meetingLng ?? this.meetingLng,
      description: description ?? this.description,
      cancelled: cancelled ?? this.cancelled,
      tags: tags ?? this.tags,
      comfortLevel: comfortLevel ?? this.comfortLevel,
      recurringRule: recurringRule ?? this.recurringRule,
      userNotes: userNotes ?? this.userNotes,
    );
  }

  // --------- for local persistence ----------

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'dateTime': dateTime.toIso8601String(),
      'distanceKm': distanceKm,
      'gender': gender,
      'isOwner': isOwner,
      'joined': joined,
      'interested': interested,
      'meetingPlaceName': meetingPlaceName,
      'meetingLat': meetingLat,
      'meetingLng': meetingLng,
      'description': description,
      'cancelled': cancelled,
      'tags': tags,
      'comfortLevel': comfortLevel,
      'recurringRule': recurringRule,
      'userNotes': userNotes,
    };
  }

  factory WalkEvent.fromMap(Map<String, dynamic> map) {
    List<String> parsedTags = [];
    if (map['tags'] is List) {
      parsedTags = (map['tags'] as List)
          .whereType<String>()
          .map((e) => e)
          .toList();
    }

    return WalkEvent(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      dateTime: DateTime.tryParse(map['dateTime'] ?? '') ?? DateTime.now(),
      distanceKm: (map['distanceKm'] is int)
          ? (map['distanceKm'] as int).toDouble()
          : (map['distanceKm'] ?? 0.0) is num
              ? (map['distanceKm'] as num).toDouble()
              : 0.0,
      gender: map['gender'] ?? 'Mixed',
      isOwner: map['isOwner'] ?? false,
      joined: map['joined'] ?? false,
      interested: map['interested'] ?? false,
      meetingPlaceName: map['meetingPlaceName'],
      meetingLat: map['meetingLat'] != null
          ? (map['meetingLat'] as num).toDouble()
          : null,
      meetingLng: map['meetingLng'] != null
          ? (map['meetingLng'] as num).toDouble()
          : null,
      description: map['description'],
      cancelled: map['cancelled'] ?? false,
      tags: parsedTags,
      comfortLevel: map['comfortLevel'],
      recurringRule: map['recurringRule'],
      userNotes: map['userNotes'],
    );
  }
}
