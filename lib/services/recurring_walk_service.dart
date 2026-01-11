import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/walk_event.dart';
import '../models/recurrence_rule.dart';
import 'crash_service.dart';

/// Service to manage recurring walks
class RecurringWalkService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _walksCollection = 'walks';

  /// Create a recurring walk: stores template + generates instances
  /// Returns the template walk ID (recurringGroupId)
  static Future<String> createRecurringWalk({
    required WalkEvent templateWalk,
    required RecurrenceRule recurrence,
    DateTime? endDate,
    int monthsAhead = 2,
  }) async {
    try {
      // Calculate actual end date
      final DateTime generationEnd =
          endDate ?? DateTime.now().add(Duration(days: monthsAhead * 30));

      // Create template walk (not shown in regular lists)
      final template = templateWalk.copyWith(
        isRecurring: true,
        isRecurringTemplate: true,
        recurrence: recurrence,
        recurringEndDate: endDate,
      );

        // Store template (not shown in lists) with required visibility/joinPolicy
        final templateMap = template.toMap();
        templateMap['visibility'] = 'open';
        templateMap['joinPolicy'] = 'request';

        final templateRef = await _firestore
          .collection(_walksCollection)
          .add(templateMap);

      final recurringGroupId = templateRef.id;

      // Generate instances
      final instances = _generateInstances(
        template: template.copyWith(
          id: recurringGroupId,
          firestoreId: recurringGroupId,
          recurringGroupId: recurringGroupId,
        ),
        recurrence: recurrence,
        endDate: generationEnd,
      );

      // Store all instances
      final batch = _firestore.batch();
      for (final instance in instances) {
        final docRef = _firestore.collection(_walksCollection).doc();
        final instanceMap = instance.toMap();
        // Add visibility and joinPolicy so home screen query works
        instanceMap['visibility'] = 'open';
        instanceMap['joinPolicy'] = 'request';
        batch.set(docRef, instanceMap);
      }
      await batch.commit();

      CrashService.log(
        'Created recurring walk: $recurringGroupId with ${instances.length} instances',
      );

      return recurringGroupId;
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'RecurringWalkService.createRecurringWalk',
      );
      rethrow;
    }
  }

  /// Generate future instances from template
  static List<WalkEvent> _generateInstances({
    required WalkEvent template,
    required RecurrenceRule recurrence,
    required DateTime endDate,
  }) {
    final instances = <WalkEvent>[];
    DateTime current = template.dateTime;

    // Safety limit
    int maxInstances = 100;
    int count = 0;

    while (current.isBefore(endDate) && count < maxInstances) {
      // Find next occurrence
      final next = _getNextOccurrence(current, recurrence);
      if (next == null || next.isAfter(endDate)) break;

      // Create instance
      instances.add(
        template.copyWith(
          id: '', // Firestore will assign
          firestoreId: '', // Will be set by Firestore
          dateTime: next,
          isRecurringTemplate: false,
          recurrence: null, // Instances don't store the rule
        ),
      );

      current = next;
      count++;
    }

    return instances;
  }

  /// Calculate next occurrence based on recurrence rule
  static DateTime? _getNextOccurrence(
    DateTime current,
    RecurrenceRule recurrence,
  ) {
    if (recurrence.type == RecurrenceType.weekly) {
      return _getNextWeeklyOccurrence(current, recurrence);
    } else {
      return _getNextMonthlyOccurrence(current, recurrence);
    }
  }

  /// Find next weekly occurrence
  static DateTime _getNextWeeklyOccurrence(
    DateTime current,
    RecurrenceRule recurrence,
  ) {
    final weekDays = recurrence.weekDays ?? [current.weekday];
    final interval = recurrence.interval;

    // Start from next day, preserving time
    DateTime candidate = current.add(const Duration(days: 1));
    candidate = DateTime(
      candidate.year,
      candidate.month,
      candidate.day,
      current.hour,
      current.minute,
      current.second,
    );

    // Search for next matching weekday
    int daysSearched = 0;
    while (daysSearched < 365) {
      // Check if weekday matches
      if (weekDays.contains(candidate.weekday)) {
        // For interval > 1, only accept if it's the right week
        if (interval == 1) {
          return candidate;
        } else {
          // Check if this is the correct interval
          final daysDiff = candidate.difference(current).inDays;
          if (daysDiff % (7 * interval) < 7) {
            return candidate;
          }
        }
      }
      candidate = candidate.add(const Duration(days: 1));
      daysSearched++;
    }

    return candidate; // Fallback (shouldn't reach here)
  }

  /// Find next monthly occurrence
  static DateTime _getNextMonthlyOccurrence(
    DateTime current,
    RecurrenceRule recurrence,
  ) {
    final targetDay = recurrence.monthDay ?? current.day;
    final interval = recurrence.interval;

    // Try next month
    DateTime candidate = DateTime(current.year, current.month + interval, 1);

    // Clamp day to valid range for that month
    final lastDay = DateTime(candidate.year, candidate.month + 1, 0).day;
    final actualDay = targetDay > lastDay ? lastDay : targetDay;

    return DateTime(
      candidate.year,
      candidate.month,
      actualDay,
      current.hour,
      current.minute,
    );
  }

  /// Get all instances of a recurring walk
  static Future<List<WalkEvent>> getRecurringInstances(
    String recurringGroupId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(_walksCollection)
          .where('recurringGroupId', isEqualTo: recurringGroupId)
          .where('isRecurringTemplate', isEqualTo: false)
          .orderBy('dateTime')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return WalkEvent.fromMap({
          ...data,
          'id': doc.id,
          'firestoreId': doc.id,
        });
      }).toList();
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'RecurringWalkService.getRecurringInstances',
      );
      return [];
    }
  }

  /// Delete a single instance
  static Future<void> cancelSingleInstance(String walkId) async {
    try {
      await _firestore.collection(_walksCollection).doc(walkId).update({
        'cancelled': true,
      });

      CrashService.log('Cancelled single recurring instance: $walkId');
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'RecurringWalkService.cancelSingleInstance',
      );
      rethrow;
    }
  }

  /// Cancel all future instances (including template)
  static Future<void> cancelAllFutureInstances(String recurringGroupId) async {
    try {
      final now = DateTime.now();

      // Get all future instances
      final snapshot = await _firestore
          .collection(_walksCollection)
          .where('recurringGroupId', isEqualTo: recurringGroupId)
          .where('dateTime', isGreaterThan: Timestamp.fromDate(now))
          .get();

      // Cancel them all
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'cancelled': true});
      }

      // Cancel template
      batch.update(
        _firestore.collection(_walksCollection).doc(recurringGroupId),
        {'cancelled': true},
      );

      await batch.commit();

      CrashService.log('Cancelled all future instances: $recurringGroupId');
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'RecurringWalkService.cancelAllFutureInstances',
      );
      rethrow;
    }
  }
}
