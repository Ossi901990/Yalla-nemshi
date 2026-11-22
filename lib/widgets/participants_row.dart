// lib/widgets/participants_row.dart
import 'package:flutter/material.dart';

import '../models/firestore_user.dart';
import '../services/firestore_user_service.dart';
import 'user_avatar.dart';

/// "People joining" row for a walk: overlapping avatars plus names, built from
/// the joined user ids so it shows current names/photos from each profile.
/// Tapping it opens the full list.
class ParticipantsRow extends StatefulWidget {
  const ParticipantsRow({
    super.key,
    required this.userIds,
    this.fallbackNames = const [],
    this.isDark = false,
  });

  final List<String> userIds;

  /// Names stored on the walk doc, used until (or if) profiles fail to load.
  final List<String> fallbackNames;
  final bool isDark;

  @override
  State<ParticipantsRow> createState() => _ParticipantsRowState();
}

class _Participant {
  const _Participant(this.uid, this.name, this.photoUrl);
  final String uid;
  final String name;
  final String? photoUrl;
}

class _ParticipantsRowState extends State<ParticipantsRow> {
  static const _maxAvatars = 4;
  late Future<List<_Participant>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant ParticipantsRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userIds.join(',') != widget.userIds.join(',')) {
      _future = _load();
    }
  }

  List<_Participant> _fallback() => [
    for (var i = 0; i < widget.userIds.length; i++)
      _Participant(
        widget.userIds[i],
        i < widget.fallbackNames.length ? widget.fallbackNames[i] : 'Walker',
        null,
      ),
  ];

  Future<List<_Participant>> _load() async {
    final uids = widget.userIds;
    if (uids.isEmpty) return const [];
    final profiles = await FirestoreUserService.getUsersByIds(uids);
    if (profiles.isEmpty) return _fallback();
    final byId = <String, FirestoreUser>{for (final p in profiles) p.uid: p};
    final fallback = _fallback();
    return [
      for (var i = 0; i < uids.length; i++)
        if (byId[uids[i]] case final p?)
          _Participant(
            p.uid,
            p.displayName.trim().isNotEmpty ? p.displayName : fallback[i].name,
            p.photoURL,
          )
        else
          fallback[i],
    ];
  }

  String _summary(List<_Participant> people) {
    final names = people.map((p) => p.name).toList();
    switch (names.length) {
      case 0:
        return 'No one has joined yet';
      case 1:
        return names[0];
      case 2:
        return '${names[0]} and ${names[1]}';
      default:
        return '${names[0]}, ${names[1]} +${names.length - 2}';
    }
  }

  void _showAll(List<_Participant> people) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                '${people.length} joining',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final p in people)
              ListTile(
                leading: UserAvatar(name: p.name, photoUrl: p.photoUrl),
                title: Text(p.name),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ringColor = widget.isDark
        ? const Color(0xFF0C2430)
        : const Color(0xFFFBFEF8);

    return FutureBuilder<List<_Participant>>(
      future: _future,
      builder: (context, snapshot) {
        final people = snapshot.data ?? _fallback();
        final shown = people.take(_maxAvatars).toList();

        final avatars = people.isEmpty
            ? SizedBox(
                width: 40,
                height: 40,
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey.withAlpha(77),
                  child: Icon(
                    Icons.person_outline,
                    size: 20,
                    color: Colors.grey[600],
                  ),
                ),
              )
            : SizedBox(
                width: 40 + (shown.length - 1) * 24.0 + 4,
                height: 44,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var i = 0; i < shown.length; i++)
                      Positioned(
                        left: i * 24.0,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: ringColor, width: 2),
                          ),
                          child: UserAvatar(
                            name: shown[i].name,
                            photoUrl: shown[i].photoUrl,
                          ),
                        ),
                      ),
                  ],
                ),
              );

        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: people.isEmpty ? null : () => _showAll(people),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                avatars,
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _summary(people),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: widget.isDark ? Colors.white70 : Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (people.isNotEmpty)
                  Icon(
                    Icons.chevron_right,
                    color: widget.isDark ? Colors.white54 : Colors.black45,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
