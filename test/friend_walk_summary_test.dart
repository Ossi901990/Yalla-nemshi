import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_nemshi/models/friend_profile.dart';

void main() {
  final now = DateTime(2026, 6, 1, 12);
  Timestamp ts(DateTime d) => Timestamp.fromDate(d);

  group('FriendWalkSummary.fromWalk', () {
    test('future walk is upcoming', () {
      final s = FriendWalkSummary.fromWalk(
        'w1',
        {'title': 'Corniche', 'dateTime': ts(now.add(const Duration(days: 1)))},
        'host',
        now: now,
      );
      expect(s.category, 'upcoming');
      expect(s.role, 'host');
      expect(s.title, 'Corniche');
    });

    test('started or completed walk is past', () {
      final started = FriendWalkSummary.fromWalk(
        'w2',
        {'dateTime': ts(now.subtract(const Duration(hours: 1)))},
        'participant',
        now: now,
      );
      final completed = FriendWalkSummary.fromWalk(
        'w3',
        {
          'dateTime': ts(now.add(const Duration(days: 1))),
          'status': 'completed',
        },
        'participant',
        now: now,
      );
      expect(started.category, 'past');
      expect(completed.category, 'past');
    });

    test('cancelled wins over everything', () {
      final s = FriendWalkSummary.fromWalk(
        'w4',
        {'cancelled': true, 'status': 'completed'},
        'host',
        now: now,
      );
      expect(s.category, 'cancelled');
    });

    test('loop walks use loop distance and minutes', () {
      final s = FriendWalkSummary.fromWalk(
        'w5',
        {'loopDistanceKm': 4.5, 'loopMinutes': 50},
        'host',
        now: now,
      );
      expect(s.distanceKm, 4.5);
      expect(s.estimatedDurationMinutes, 50);
      expect(s.title, 'Walk');
    });
  });
}
