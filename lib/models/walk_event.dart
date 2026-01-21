// lib/models/walk_event.dart
import 'package:cloud_firestore/cloud_firestore.dart';

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
  final String visibility;
  final String joinPolicy;
  final String? shareCode;
  final DateTime? shareCodeExpiresAt;
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

  // ===== CP-4: Walk Control & Tracking Fields =====
  /// Expected duration of the walk in minutes (host sets when creating walk)
  final int? plannedDurationMinutes;

  /// Current status of the walk (scheduled | active | ended | cancelled)
  /// scheduled: accepting participants, waiting to start
  /// active: walk is in progress / confirmations happening
  /// ended: walk has finished
  /// cancelled: host cancelled the walk
  final String status;

  /// Timestamp when the walk actually started (when host pressed "Start Walk")
  final DateTime? startedAt;

  /// UID of the user who started the walk (should be hostUid)
  final String? startedByUid;

  /// Timestamp when the walk actually ended (when host pressed "End Walk")
  final DateTime? completedAt;

  /// Actual duration in minutes (calculated from startedAt to completedAt)
  final int? actualDurationMinutes;

  /// Actual GPS distance recorded for this walk (in kilometers)
  final double? actualDistanceKm;

  /// Average walking speed recorded by GPS (miles per hour)
  final double? averageSpeed;

  /// Peak walking speed recorded by GPS (miles per hour)
  final double? maxSpeed;

  /// True once GPS tracking has flushed and summarized the route
  final bool trackingCompleted;

  /// Count of GPS points stored while tracking was active
  final int? trackingPointsCount;

  /// Count of GPS points kept in the summary collection
  final int? routePointsCount;

  /// Last time GPS data was written to Firestore
  final DateTime? lastTrackingUpdate;

  /// Optional: tags for a walk, e.g. ["Scenic", "Dog friendly"] (for future use)
  final List<String> tags;

  /// Optional: comfort/vibe, e.g. "Social", "Quiet", "Workout" (for future use)
  final String? comfortLevel;

  /// Experience guidance shown to participants (e.g., "All levels").
  final String experienceLevel;

  /// Cached keywords used by advanced search.
  final List<String> searchKeywords;

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

  // ===== Host & Participants Info =====
  /// Host's display name (nullable for backward compatibility)
  final String? hostName;

  /// Host's profile photo URL (nullable for backward compatibility)
  final String? hostPhotoUrl;

  /// List of user IDs who have joined this walk
  final List<String> joinedUserUids;

  /// List of photo URLs for users who joined (parallel to joinedUserUids)
  final List<String> joinedUserPhotoUrls;

  /// Count of users who joined (fallback to joinedUserUids.length if not provided)
  final int joinedCount;

  /// Per-user participation state (invited/joined/confirmed/left)
  final Map<String, String> participantStates;

  WalkEvent({
    required this.id,
    required this.firestoreId,
    required this.hostUid,
    required this.title,
    required this.dateTime,
    required this.distanceKm,
    required this.gender,
    required this.pace,
    this.visibility = 'open',
    this.joinPolicy = 'request',
    this.shareCode,
    this.shareCodeExpiresAt,
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
    this.plannedDurationMinutes,  // CP-4
    this.status = 'scheduled',  // CP-4
    this.startedAt,  // CP-4
    this.startedByUid,  // CP-4
    this.completedAt,  // CP-4
    this.actualDurationMinutes,  // CP-4
    this.actualDistanceKm,
    this.averageSpeed,
    this.maxSpeed,
    this.trackingCompleted = false,
    this.trackingPointsCount,
    this.routePointsCount,
    this.lastTrackingUpdate,
    List<String>? tags,
    this.comfortLevel,
    this.experienceLevel = 'All levels',
    this.recurringRule,
    this.userNotes,
    this.city,
    this.isRecurring = false,
    this.recurringGroupId,
    this.recurrence,
    this.isRecurringTemplate = false,
    this.recurringEndDate,
    List<String>? photoUrls,
    this.hostName,
    this.hostPhotoUrl,
    List<String>? joinedUserUids,
    List<String>? joinedUserPhotoUrls,
    int? joinedCount,
    List<String>? searchKeywords,
    Map<String, String>? participantStates,
  })  : tags = tags ?? const [],
        photoUrls = photoUrls ?? const [],
        joinedUserUids = joinedUserUids ?? const [],
        joinedUserPhotoUrls = joinedUserPhotoUrls ?? const [],
        joinedCount = joinedCount ?? (joinedUserUids?.length ?? 0),
        searchKeywords = searchKeywords ?? const [],
        participantStates = Map.unmodifiable(participantStates ?? const {});

  WalkEvent copyWith({
    String? id,
    String? firestoreId,
    String? hostUid,
    String? title,
    DateTime? dateTime,
    double? distanceKm,
    String? gender,
    String? pace,
    String? visibility,
    String? joinPolicy,
    String? shareCode,
    DateTime? shareCodeExpiresAt,
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
    int? plannedDurationMinutes,  // CP-4
    String? status,  // CP-4
    DateTime? startedAt,  // CP-4
    String? startedByUid,  // CP-4
    DateTime? completedAt,  // CP-4
    int? actualDurationMinutes,  // CP-4
    double? actualDistanceKm,
    double? averageSpeed,
    double? maxSpeed,
    bool? trackingCompleted,
    int? trackingPointsCount,
    int? routePointsCount,
    DateTime? lastTrackingUpdate,
    List<String>? tags,
    String? comfortLevel,
    String? experienceLevel,
    String? recurringRule,
    String? userNotes,
    String? city,
    bool? isRecurring,
    String? recurringGroupId,
    RecurrenceRule? recurrence,
    bool? isRecurringTemplate,
    DateTime? recurringEndDate,
    List<String>? photoUrls,
    String? hostName,
    String? hostPhotoUrl,
    List<String>? joinedUserUids,
    List<String>? joinedUserPhotoUrls,
    int? joinedCount,
    List<String>? searchKeywords,
    Map<String, String>? participantStates,
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
      visibility: visibility ?? this.visibility,
      joinPolicy: joinPolicy ?? this.joinPolicy,
      shareCode: shareCode ?? this.shareCode,
      shareCodeExpiresAt: shareCodeExpiresAt ?? this.shareCodeExpiresAt,
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
      plannedDurationMinutes: plannedDurationMinutes ?? this.plannedDurationMinutes,  // CP-4
      status: status ?? this.status,  // CP-4
      startedAt: startedAt ?? this.startedAt,  // CP-4
      startedByUid: startedByUid ?? this.startedByUid,  // CP-4
      completedAt: completedAt ?? this.completedAt,  // CP-4
      actualDurationMinutes: actualDurationMinutes ?? this.actualDurationMinutes,  // CP-4
      actualDistanceKm: actualDistanceKm ?? this.actualDistanceKm,
      averageSpeed: averageSpeed ?? this.averageSpeed,
      maxSpeed: maxSpeed ?? this.maxSpeed,
      trackingCompleted: trackingCompleted ?? this.trackingCompleted,
      trackingPointsCount: trackingPointsCount ?? this.trackingPointsCount,
      routePointsCount: routePointsCount ?? this.routePointsCount,
      lastTrackingUpdate: lastTrackingUpdate ?? this.lastTrackingUpdate,
      tags: tags ?? this.tags,
        comfortLevel: comfortLevel ?? this.comfortLevel,
        experienceLevel: experienceLevel ?? this.experienceLevel,
      recurringRule: recurringRule ?? this.recurringRule,
      userNotes: userNotes ?? this.userNotes,
      city: city ?? this.city,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringGroupId: recurringGroupId ?? this.recurringGroupId,
      recurrence: recurrence ?? this.recurrence,
      isRecurringTemplate: isRecurringTemplate ?? this.isRecurringTemplate,
      recurringEndDate: recurringEndDate ?? this.recurringEndDate,
      photoUrls: photoUrls ?? this.photoUrls,
      hostName: hostName ?? this.hostName,
      hostPhotoUrl: hostPhotoUrl ?? this.hostPhotoUrl,
      joinedUserUids: joinedUserUids ?? this.joinedUserUids,
        joinedUserPhotoUrls: joinedUserPhotoUrls ?? this.joinedUserPhotoUrls,
        joinedCount: joinedCount ?? this.joinedCount,
        searchKeywords: searchKeywords ?? this.searchKeywords,
        participantStates: participantStates ?? this.participantStates,
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
      'actualDistanceKm': actualDistanceKm,
      'averageSpeed': averageSpeed,
      'maxSpeed': maxSpeed,
      'trackingCompleted': trackingCompleted,
      'trackingPointsCount': trackingPointsCount,
      'routePointsCount': routePointsCount,
      'lastTrackingUpdate': lastTrackingUpdate?.toIso8601String(),
      'tags': tags,
        'comfortLevel': comfortLevel,
        'experienceLevel': experienceLevel,
      'recurringRule': recurringRule,
      'userNotes': userNotes,
      'city': city,
      'isRecurring': isRecurring,
      'recurringGroupId': recurringGroupId,
      'recurrence': recurrence?.toMap(),
      'isRecurringTemplate': isRecurringTemplate,
      'recurringEndDate': recurringEndDate?.toIso8601String(),
      'photoUrls': photoUrls,
      'hostName': hostName,
      'hostPhotoUrl': hostPhotoUrl,
      'joinedUserUids': joinedUserUids,
        'joinedUserPhotoUrls': joinedUserPhotoUrls,
        'joinedCount': joinedCount,
        'searchKeywords': searchKeywords,
        'participantStates': participantStates,
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

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is num) {
      final millis = value.toInt();
      if (millis <= 0) return null;
      return DateTime.fromMillisecondsSinceEpoch(millis);
    }
    return null;
  }

  static String _normalizeStatus(dynamic value) {
    final raw = _toStringSafe(value, fallback: 'scheduled').toLowerCase();
    switch (raw) {
      case 'active':
      case 'starting':
        return 'active';
      case 'completed':
      case 'ended':
        return 'ended';
      case 'cancelled':
        return 'cancelled';
      default:
        return 'scheduled';
    }
  }

  static Map<String, String> _parseParticipantStates(dynamic value) {
    if (value is Map) {
      final buffer = <String, String>{};
      value.forEach((key, val) {
        final safeKey = key?.toString() ?? '';
        if (safeKey.isEmpty) return;
        buffer[safeKey] = (val ?? 'joined').toString();
      });
      return Map.unmodifiable(buffer);
    }
    return const {};
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
      visibility: _toStringSafe(map['visibility'], fallback: 'open'),
      joinPolicy: _toStringSafe(map['joinPolicy'], fallback: 'request'),
      shareCode: map['shareCode']?.toString(),
      shareCodeExpiresAt: _toDateTime(map['shareCodeExpiresAt']),
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
      experienceLevel: map['experienceLevel']?.toString() ?? 'All levels',
        status: _normalizeStatus(map['status']),
        startedAt: _toDateTime(map['startedAt']),
        startedByUid: map['startedByUid']?.toString(),
        completedAt: _toDateTime(map['completedAt']),
        actualDurationMinutes:
          (map['actualDurationMinutes'] as num?)?.toInt(),
          actualDistanceKm: (map['actualDistanceKm'] as num?)?.toDouble(),
          averageSpeed: (map['averageSpeed'] as num?)?.toDouble(),
          maxSpeed: (map['maxSpeed'] as num?)?.toDouble(),
          trackingCompleted: _toBool(map['trackingCompleted']),
          trackingPointsCount: (map['trackingPointsCount'] as num?)?.toInt(),
          routePointsCount: (map['routePointsCount'] as num?)?.toInt(),
          lastTrackingUpdate: _toDateTime(map['lastTrackingUpdate']),
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
      hostName: map['hostName']?.toString(),
      hostPhotoUrl: map['hostPhotoUrl']?.toString(),
      joinedUserUids: (map['joinedUserUids'] is List)
          ? (map['joinedUserUids'] as List).whereType<String>().toList()
          : <String>[],
      joinedUserPhotoUrls: (map['joinedUserPhotoUrls'] is List)
          ? (map['joinedUserPhotoUrls'] as List).whereType<String>().toList()
          : <String>[],
      joinedCount: map['joinedCount'] != null
          ? _toDouble(map['joinedCount']).toInt()
          : (map['joinedUserUids'] is List
              ? (map['joinedUserUids'] as List).length
              : 0),
        searchKeywords: (map['searchKeywords'] is List)
          ? (map['searchKeywords'] as List).whereType<String>().toList()
          : const [],
      participantStates: _parseParticipantStates(map['participantStates']),
    );
  }

  /// Format date for display
  String get formattedDate {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  bool get isPrivate => visibility == 'private';
}
