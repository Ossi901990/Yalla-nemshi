// Chat (2026 redesign): group chat and DMs must lay out on every common
// phone size, text-size setting and theme.
//
// Screenshots: `flutter test test/chat_test.dart --update-goldens`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_nemshi/widgets/chat/chat_view.dart';

import 'support/layout_kit.dart';

final _now = DateTime.now();
DateTime _at(int daysAgo, int h, int m) =>
    DateTime(_now.year, _now.month, _now.day - daysAgo, h, m);

// Newest first, like Firestore returns them.
final _group = <ChatMessage>[
  const ChatMessage(id: '9', senderId: 'me', text: 'On my way 🚶'),
  ChatMessage(
    id: '8',
    senderId: 'u2',
    senderName: 'Lejla Kovač',
    text: 'Running 5 minutes late, start without me and I will catch up!',
    sentAt: _at(0, 18, 12),
  ),
  ChatMessage(
    id: '7',
    senderId: 'u2',
    senderName: 'Lejla Kovač',
    text: 'Sorry 🙏',
    sentAt: _at(0, 18, 11),
  ),
  ChatMessage(
    id: '6',
    senderId: 'me',
    text: 'Meet at the gate by the old tram stop',
    sentAt: _at(0, 17, 40),
  ),
  ChatMessage(
    id: '5',
    senderId: 'me',
    text: 'This one got deleted',
    sentAt: _at(0, 17, 39),
    deleted: true,
  ),
  ChatMessage(
    id: '4',
    senderId: 'u3',
    senderName: 'Emir Begić Hadžiomerović-Kapetanović',
    text:
        'Is the route the long loop along the river or the short one through '
        'the park? Bringing my dog if that is ok with everyone.',
    sentAt: _at(1, 20, 5),
  ),
  ChatMessage(
    id: '3',
    senderId: 'u4',
    text: 'Count me in',
    sentAt: _at(1, 19, 58),
  ),
  ChatMessage(
    id: '2',
    senderId: 'me',
    text: 'Welcome everyone! 👋',
    sentAt: _at(4, 9, 0),
  ),
  ChatMessage(
    id: '1',
    senderId: 'u2',
    senderName: 'Lejla Kovač',
    text: 'Supercalifragilisticexpialidocious-walk-anyone?',
    sentAt: _at(12, 8, 30),
  ),
];

Widget _screen(String state, {Future<void> Function(String)? onSend}) {
  final group = state == 'group';
  return ChatView(
    title: group
        ? 'Riverside evening loop along the Miljacka river'
        : 'Amra Mehić',
    subtitle: group ? 'Group chat' : 'Direct message',
    leading: const CircleAvatar(radius: 22, child: Icon(Icons.person)),
    messages: state == 'empty' ? const [] : _group,
    currentUid: 'me',
    showSenderNames: group,
    emptyTitle: 'Say hi to the group',
    emptyText: 'Everyone on this walk can read this chat.',
    onBack: () {},
    onSend: onSend ?? (_) async {},
    onAttach: state == 'dm' ? () {} : null,
    onLongPressMine: (_) {},
  );
}

void main() {
  setUpAll(loadAppFonts);

  fitGrid(
    screen: 'chat',
    states: const ['group', 'dm', 'empty'],
    build: _screen,
    // Newest messages are at the bottom already; drag shows the oldest.
    scroll: () => find.byType(Scrollable).first,
  );

  testWidgets('group chat shows sender names once per run', (tester) async {
    await tester.pumpWidget(themedApp(_screen('group'), ThemeMode.light));
    await tester.pumpAndSettle();
    // Lejla wrote two in a row today: her name shows once there.
    expect(find.text('Lejla Kovač'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Message deleted'), findsOneWidget);
    // No name stored: falls back to "Walker".
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.text('Walker'), findsOneWidget);
  });

  testWidgets('DMs never show names', (tester) async {
    await tester.pumpWidget(themedApp(_screen('dm'), ThemeMode.light));
    await tester.pumpAndSettle();
    expect(find.text('Lejla Kovač'), findsNothing);
  });

  testWidgets('sending passes the text and clears the box', (tester) async {
    String? sent;
    await tester.pumpWidget(
      themedApp(
        _screen('empty', onSend: (t) async => sent = t),
        ThemeMode.light,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  See you there  ');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(sent, 'See you there');
    expect(find.text('  See you there  '), findsNothing);

    // Empty text sends nothing.
    sent = null;
    await tester.tap(find.byTooltip('Send'));
    expect(sent, isNull);
  });
}
