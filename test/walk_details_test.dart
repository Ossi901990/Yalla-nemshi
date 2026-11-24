// Walk details (2026 redesign): every situation on every common phone size,
// text-size setting and theme must lay out without errors.
//
// Screenshots: `flutter test test/walk_details_test.dart --update-goldens`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_nemshi/models/recurrence_rule.dart';
import 'package:yalla_nemshi/models/walk_event.dart';
import 'package:yalla_nemshi/screens/walk_details/walk_details_view.dart';

import 'support/layout_kit.dart';

const _me = 'me';

WalkEvent _walk({
  bool owner = false,
  bool joined = false,
  String status = 'scheduled',
  bool cancelled = false,
  bool private = false,
  bool recurring = false,
  String? description,
  Map<String, String> states = const {},
}) {
  final when = DateTime.now().add(const Duration(days: 1, hours: 2));
  return WalkEvent(
    id: 'w1',
    firestoreId: 'w1',
    hostUid: owner ? _me : 'host1',
    hostName: owner ? 'Osaid Abdullah' : 'Amra Mehić',
    title: 'Riverside evening loop along the Miljacka',
    dateTime: when,
    distanceKm: 4.5,
    plannedDurationMinutes: 75,
    gender: 'Mixed',
    pace: 'Easy',
    isOwner: owner,
    joined: joined,
    status: status,
    cancelled: cancelled,
    visibility: private ? 'private' : 'open',
    meetingPlaceName: 'Wilsonovo šetalište, near the old tram stop',
    city: 'Sarajevo',
    description: description,
    isRecurring: recurring,
    recurringGroupId: recurring ? 'g1' : null,
    recurrence: recurring
        ? const RecurrenceRule(type: RecurrenceType.weekly, weekDays: [2, 4])
        : null,
    joinedUserUids: ['u1', 'u2', 'u3', if (joined) _me],
    joinedUserNames: const ['Lejla Kovač', 'Sara Hadžić', 'Emir Begić'],
    joinedCount: 11,
    participantStates: states,
  );
}

final _states = <String, (WalkEvent, bool)>{
  'visitor': (_walk(), false),
  'joined': (_walk(joined: true), false),
  'joined_active_check_in': (_walk(joined: true, status: 'active'), false),
  'joined_active_walking': (
    _walk(joined: true, status: 'active', states: const {_me: 'confirmed'}),
    true,
  ),
  'host_scheduled': (_walk(owner: true), false),
  'host_active': (_walk(owner: true, status: 'active'), false),
  'cancelled': (_walk(joined: true, cancelled: true), false),
  'ended': (_walk(joined: true, status: 'completed'), false),
  'host_private_series_long': (
    _walk(
      owner: true,
      private: true,
      recurring: true,
      description:
          'We meet at the tram stop, walk east along the river to Vrelo Bosne '
          'and back. Bring water and comfortable shoes. Dogs welcome! '
          'If it rains we move to the covered walkway.',
    ),
    false,
  ),
};

WalkDetailsActions _noActions() => WalkDetailsActions(
  onBack: () {},
  onJoin: () {},
  onLeave: () {},
  onChat: () {},
  onStart: () {},
  onEnd: () {},
  onOpenActive: () {},
  onConfirmHere: () {},
  onDecline: () {},
  onToggleInterested: () {},
  onReport: () {},
  onCancel: () {},
  onCancelOccurrence: () {},
  onCancelSeries: () {},
);

Widget _screen(String state) {
  final (walk, confirmed) = _states[state]!;
  return WalkDetailsView(
    walk: walk,
    currentUid: _me,
    isConfirmed: confirmed,
    actions: _noActions(),
    activeCount: walk.isOwner && walk.status == 'active' ? 7 : null,
    // Stand-ins for the pieces that load their own data.
    hostRating: const Text('⭐ 4.8 · 23 reviews'),
    participants: const SizedBox(height: 48, child: Placeholder()),
    inviteTools: walk.isPrivate
        ? const SizedBox(height: 120, child: Placeholder())
        : null,
  );
}

void main() {
  setUpAll(loadAppFonts);

  fitGrid(
    screen: 'details',
    states: _states.keys.toList(),
    build: _screen,
    scroll: () => find.byType(ListView),
  );

  testWidgets('action bar shows the right main button per situation', (
    tester,
  ) async {
    const expected = {
      'visitor': "I'm in",
      'joined': 'Group chat',
      'joined_active_check_in': "I'm here",
      'joined_active_walking': 'Open walk',
      'host_scheduled': 'Start walk',
      'host_active': 'End walk',
      'cancelled': 'This walk was cancelled',
      'ended': 'This walk has ended',
    };
    for (final MapEntry(key: state, value: label) in expected.entries) {
      await tester.pumpWidget(themedApp(_screen(state), ThemeMode.light));
      await tester.pumpAndSettle();
      expect(find.text(label), findsOneWidget, reason: state);
    }
  });
}
