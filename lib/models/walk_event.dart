// lib/models/walk_event.dart

class WalkEvent {
  // Local / app-level id (can be timestamp-based in your current code)
  final String id;

  // ✅ Firestore document ID in /walks (THIS is what we use for chat ids)
  final String firestoreId;

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
    required this.firestoreId,
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
    String? firestoreId,
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
      firestoreId: firestoreId ?? this.firestoreId,
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
      'firestoreId': firestoreId,
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

  // ✅ Helpers: safe parsing (prevents "Null is not a subtype of num")
  static double _toDouble(dynamic v, {double fallback = 0.0}) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  static bool _toBool(dynamic v, {bool fallback = false}) {
    if (v == null) return fallback;
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase().trim();
      if (s == 'true' || s == '1' || s == 'yes') return true;
      if (s == 'false' || s == '0' || s == 'no') return false;
    }
    return fallback;
  }

  static String _toStringSafe(dynamic v, {String fallback = ''}) {
    if (v == null) return fallback;
    if (v is String) return v;
    return v.toString();
  }

  factory WalkEvent.fromMap(Map<String, dynamic> map) {
    final parsedTags = (map['tags'] is List)
        ? (map['tags'] as List).whereType<String>().toList()
        : <String>[];

    final String id = _toStringSafe(map['id']);
    final String firestoreId = _toStringSafe(map['firestoreId'], fallback: id);

    // dateTime can arrive as ISO string. If invalid/missing -> now.
    final String dtStr = _toStringSafe(map['dateTime']);
    final DateTime dateTime = DateTime.tryParse(dtStr) ?? DateTime.now();

    // ✅ distanceKm might be null in old docs -> 0.0 (prevents crash)
    final double distanceKm = _toDouble(map['distanceKm'], fallback: 0.0);

    // ✅ meetingLat/Lng might be null -> keep null
    final double? meetingLat =
        map['meetingLat'] == null ? null : _toDouble(map['meetingLat']);
    final double? meetingLng =
        map['meetingLng'] == null ? null : _toDouble(map['meetingLng']);

    return WalkEvent(
      id: id,
      firestoreId: firestoreId,
      title: _toStringSafe(map['title']),
      dateTime: dateTime,
      distanceKm: distanceKm,
      gender: _toStringSafe(map['gender'], fallback: 'Mixed'),
      isOwner: _toBool(map['isOwner']),
      joined: _toBool(map['joined']),
      interested: _toBool(map['interested']),
      meetingPlaceName: map['meetingPlaceName'] as String?,
      meetingLat: meetingLat,
      meetingLng: meetingLng,
      description: map['description'] as String?,
      cancelled: _toBool(map['cancelled']),
      tags: parsedTags,
      comfortLevel: map['comfortLevel'] as String?,
      recurringRule: map['recurringRule'] as String?,
      userNotes: map['userNotes'] as String?,
    );
  }
}
