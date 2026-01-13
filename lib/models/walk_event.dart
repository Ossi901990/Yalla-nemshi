// lib/models/walk_event.dart
import 'recurrence_rule.dart';

class WalkEvent {
  final String id;
  // ✅ Firestore document ID in /walks (THIS is what we use for chat ids)
  final String firestoreId;

  // ✅ Needed so we can notify the host when someone joins
  final String hostUid;

  final String title;

  final DateTime dateTime;
  final double distanceKm;
  final String gender; // e.g. "Mixed", "Women only", "Men only"
  final String pace; // e.g. "Relaxed", "Normal", "Brisk"
  final bool isOwner;
  final String? meetingPlaceName;
  final double? meetingLat;
  final double? meetingLng;
  // Explicit start/end coordinates for the route (optional)
  final double? startLat;
  final double? startLng;
  final double? endLat;
  final double? endLng;
  final String? description;

  /// City where the walk takes place (auto-detected from coordinates)
  final String? city;

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

  /// Optional: recurring rule text, e.g. "Weekly on Saturday" (deprecated, use recurrence)
  final String? recurringRule;

  /// Optional: user's private notes about this event (for future use)
  final String? userNotes;

  // ===== Recurring Walk Fields =====
  /// Whether this walk is part of a recurring series
  final bool isRecurring;

  /// ID linking all instances of the same recurring walk (null if not recurring)
  final String? recurringGroupId;

  /// Recurrence pattern (only stored on template, null on instances)
  final RecurrenceRule? recurrence;

  /// True if this is the template walk (not shown in lists), false for generated instances
  final bool isRecurringTemplate;

  /// Optional end date for recurring generation
  final DateTime? recurringEndDate;

  /// Photo URLs stored in Firebase Storage
  final List<String> photoUrls;

  WalkEvent({
    required this.id,
    required this.firestoreId,
    required this.hostUid,
    required this.title,
    required this.dateTime,
    required this.distanceKm,
    required this.gender,
    required this.pace,
    this.isOwner = false,
    this.joined = false,
    this.interested = false,
    this.meetingPlaceName,
    this.meetingLat,
    this.meetingLng,
    this.startLat,
    this.startLng,
    this.endLat,
    this.endLng,
    this.description,
    this.cancelled = false,
    List<String>? tags,
    this.comfortLevel,
    this.recurringRule,
    this.userNotes,
    this.city,
    this.isRecurring = false,
    this.recurringGroupId,
    this.recurrence,
    this.isRecurringTemplate = false,
    this.recurringEndDate,
    List<String>? photoUrls,
  }) : tags = tags ?? const [],
       photoUrls = photoUrls ?? const [];

  WalkEvent copyWith({
    String? id,
    String? firestoreId,
    String? hostUid,
    String? title,
    DateTime? dateTime,
    double? distanceKm,
    String? gender,
    String? pace,
    bool? isOwner,
    bool? joined,
    bool? interested,
    String? meetingPlaceName,
    double? meetingLat,
    double? meetingLng,
    double? startLat,
    double? startLng,
    double? endLat,
    double? endLng,
    String? description,
    bool? cancelled,
    List<String>? tags,
    String? comfortLevel,
    String? recurringRule,
    String? userNotes,
    String? city,
    bool? isRecurring,
    String? recurringGroupId,
    RecurrenceRule? recurrence,
    bool? isRecurringTemplate,
    DateTime? recurringEndDate,
    List<String>? photoUrls,
  }) {
    return WalkEvent(
      id: id ?? this.id,
      firestoreId: firestoreId ?? this.firestoreId,
      hostUid: hostUid ?? this.hostUid,

      title: title ?? this.title,
      dateTime: dateTime ?? this.dateTime,
      distanceKm: distanceKm ?? this.distanceKm,
      gender: gender ?? this.gender,
      pace: pace ?? this.pace,
      isOwner: isOwner ?? this.isOwner,
      joined: joined ?? this.joined,
      interested: interested ?? this.interested,
      meetingPlaceName: meetingPlaceName ?? this.meetingPlaceName,
      meetingLat: meetingLat ?? this.meetingLat,
      meetingLng: meetingLng ?? this.meetingLng,
      startLat: startLat ?? this.startLat,
      startLng: startLng ?? this.startLng,
      endLat: endLat ?? this.endLat,
      endLng: endLng ?? this.endLng,
      description: description ?? this.description,
      cancelled: cancelled ?? this.cancelled,
      tags: tags ?? this.tags,
      comfortLevel: comfortLevel ?? this.comfortLevel,
      recurringRule: recurringRule ?? this.recurringRule,
      userNotes: userNotes ?? this.userNotes,
      city: city ?? this.city,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringGroupId: recurringGroupId ?? this.recurringGroupId,
      recurrence: recurrence ?? this.recurrence,
      isRecurringTemplate: isRecurringTemplate ?? this.isRecurringTemplate,
      recurringEndDate: recurringEndDate ?? this.recurringEndDate,
      photoUrls: photoUrls ?? this.photoUrls,
    );
  }

  // --------- for local persistence ----------

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firestoreId': firestoreId,
      'hostUid': hostUid,
      'title': title,
      'dateTime': dateTime.toIso8601String(),
      'distanceKm': distanceKm,
      'gender': gender,
      'pace': pace,
      'isOwner': isOwner,
      'joined': joined,
      'interested': interested,
      'meetingPlaceName': meetingPlaceName,
      'meetingLat': meetingLat,
      'meetingLng': meetingLng,
      'startLat': startLat,
      'startLng': startLng,
      'endLat': endLat,
      'endLng': endLng,
      'description': description,
      'cancelled': cancelled,
      'tags': tags,
      'comfortLevel': comfortLevel,
      'recurringRule': recurringRule,
      'userNotes': userNotes,
      'city': city,
      'isRecurring': isRecurring,
      'recurringGroupId': recurringGroupId,
      'recurrence': recurrence?.toMap(),
      'isRecurringTemplate': isRecurringTemplate,
      'recurringEndDate': recurringEndDate?.toIso8601String(),
      'photoUrls': photoUrls,
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

    // dateTime can be ISO string. If invalid/missing -> now.
    final String dtStr = _toStringSafe(map['dateTime']);
    final DateTime dateTime = DateTime.tryParse(dtStr) ?? DateTime.now();

    // ✅ distanceKm might be null/int/double/string -> safe
    final double distanceKm = _toDouble(map['distanceKm'], fallback: 0.0);
    final String pace = _toStringSafe(map['pace'], fallback: 'Relaxed');

    // ✅ meetingLat/Lng might be null -> keep null
    final double? meetingLat = map['meetingLat'] == null
        ? null
        : _toDouble(map['meetingLat']);
    final double? meetingLng = map['meetingLng'] == null
        ? null
        : _toDouble(map['meetingLng']);
    final double? startLat = map['startLat'] == null
        ? null
        : _toDouble(map['startLat']);
    final double? startLng = map['startLng'] == null
        ? null
        : _toDouble(map['startLng']);
    final double? endLat = map['endLat'] == null
        ? null
        : _toDouble(map['endLat']);
    final double? endLng = map['endLng'] == null
        ? null
        : _toDouble(map['endLng']);

    return WalkEvent(
      id: id,
      hostUid: (map['hostUid'] ?? '').toString(),

      firestoreId: firestoreId,
      title: _toStringSafe(map['title']),
      dateTime: dateTime,
      distanceKm: distanceKm,
      gender: _toStringSafe(map['gender'], fallback: 'Mixed'),
      pace: pace,
      isOwner: _toBool(map['isOwner']),
      joined: _toBool(map['joined']),
      interested: _toBool(map['interested']),
      meetingPlaceName: map['meetingPlaceName']?.toString(),
      meetingLat: meetingLat,
      meetingLng: meetingLng,
      startLat: startLat,
      startLng: startLng,
      endLat: endLat,
      endLng: endLng,
      description: map['description']?.toString(),
      cancelled: _toBool(map['cancelled']),
      tags: parsedTags,
      comfortLevel: map['comfortLevel']?.toString(),
      recurringRule: map['recurringRule']?.toString(),
      userNotes: map['userNotes']?.toString(),
      city: map['city']?.toString(),
      isRecurring: _toBool(map['isRecurring']),
      recurringGroupId: map['recurringGroupId']?.toString(),
      recurrence: map['recurrence'] != null
          ? RecurrenceRule.fromMap(map['recurrence'] as Map<String, dynamic>)
          : null,
      isRecurringTemplate: _toBool(map['isRecurringTemplate']),
      recurringEndDate: map['recurringEndDate'] != null
          ? DateTime.tryParse(map['recurringEndDate'].toString())
          : null,
      photoUrls: (map['photoUrls'] is List)
          ? (map['photoUrls'] as List).whereType<String>().toList()
          : <String>[],
    );
  }

  /// Format date for display
  String get formattedDate {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
