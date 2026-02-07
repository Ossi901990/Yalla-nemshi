// lib/screens/event_details_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'walk_chat_screen.dart';
import 'walk_summary_screen.dart';
import 'active_walk_screen.dart';
import '../models/walk_event.dart';
import '../services/invite_service.dart';
import '../services/recurring_walk_service.dart';
import '../services/host_rating_service.dart';
import '../services/walk_control_service.dart';
import '../services/walk_history_service.dart';
import '../services/gps_tracking_service.dart';
import '../utils/invite_utils.dart';

class EventDetailsScreen extends StatefulWidget {
  final WalkEvent event;
  final void Function(WalkEvent) onToggleJoin;
  final void Function(WalkEvent) onToggleInterested;
  final void Function(WalkEvent) onCancelHosted;

  const EventDetailsScreen({
    super.key,
    required this.event,
    required this.onToggleJoin,
    required this.onToggleInterested,
    required this.onCancelHosted,
  });

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _PrivateInviteManagement extends StatefulWidget {
  const _PrivateInviteManagement({required this.event});

  final WalkEvent event;

  @override
  State<_PrivateInviteManagement> createState() =>
      _PrivateInviteManagementState();
}

class _PrivateInviteManagementState extends State<_PrivateInviteManagement> {
  late final DocumentReference<Map<String, dynamic>> _walkRef;
  final InviteService _inviteService = InviteService();
  bool _rotatingCode = false;
  bool _extendingExpiry = false;
  final Set<String> _revoking = <String>{};

  @override
  void initState() {
    super.initState();
    _walkRef = FirebaseFirestore.instance
        .collection('walks')
        .doc(widget.event.firestoreId);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.event.firestoreId.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      color: isDark ? const Color(0xFF0F2734) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: (isDark ? Colors.white : Colors.black).withAlpha(
            (0.08 * 255).round(),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Private invites',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withAlpha(
                      (0.18 * 255).round(),
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Host only',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _walkRef.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const LinearProgressIndicator();
                }

                final data = snapshot.data?.data();
                final shareCode = (data?['shareCode'] ?? widget.event.shareCode)
                    ?.toString();
                final expiresAt =
                    _asDateTime(data?['shareCodeExpiresAt']) ??
                    widget.event.shareCodeExpiresAt;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: isDark
                            ? Colors.white.withAlpha((0.05 * 255).round())
                            : Colors.black.withAlpha((0.03 * 255).round()),
                        border: Border.all(
                          color: (isDark ? Colors.white : Colors.black)
                              .withAlpha((0.12 * 255).round()),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Invite code',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                SelectableText(
                                  shareCode ?? '------',
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        letterSpacing: 2,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF111827),
                                      ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Copy invite code',
                            onPressed: (shareCode == null || shareCode.isEmpty)
                                ? null
                                : () => _copyCode(shareCode),
                            icon: const Icon(Icons.copy),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _expiryDescription(expiresAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    Text(
                      expiresAt != null
                          ? 'Active until ${_formatAbsolute(expiresAt)}'
                          : 'Set an expiry to keep codes secure.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _extendingExpiry || shareCode == null
                                ? null
                                : _extendExpiry,
                            icon: _extendingExpiry
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.schedule),
                            label: const Text('Extend 7 days'),
                          ),
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed:
                            _rotatingCode ||
                                shareCode == null ||
                                shareCode.isEmpty
                            ? null
                            : _regenerateShareCode,
                        icon: _rotatingCode
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh),
                        label: const Text('Regenerate code'),
                      ),
                    ),
                    Text(
                      'Regenerating immediately invalidates the previous link.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              'People with access',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _buildInviteeList(theme, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteeList(ThemeData theme, bool isDark) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _walkRef
          .collection('allowed')
          .orderBy('redeemedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const LinearProgressIndicator();
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Text(
            'No invitees yet. Share the code to pre-approve walkers.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          );
        }

        // Batch fetch all user profiles (fixes N+1 query issue)
        return FutureBuilder<Map<String, Map<String, dynamic>>>(
          future: _batchFetchUserProfiles(docs.map((d) => d.id).toList()),
          builder: (context, profilesSnapshot) {
            if (!profilesSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final userProfiles = profilesSnapshot.data!;

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              separatorBuilder: (context, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final uid = doc.id;
                final redeemedAt = _asDateTime(doc.data()['redeemedAt']);
                final isRevoking = _revoking.contains(uid);
                final userProfile = userProfiles[uid];

                return _InviteeListTile(
                  userId: uid,
                  displayName: userProfile?['displayName'] as String?,
                  photoUrl: userProfile?['photoUrl'] as String?,
                  redeemedAt: redeemedAt,
                  isRevoking: isRevoking,
                  onRevoke: () => _revokeInvite(uid),
                );
              },
            );
          },
        );
      },
    );
  }

  /// Batch fetch user profiles to avoid N+1 query issue
  /// Makes 1 read instead of N reads for N invitees
  Future<Map<String, Map<String, dynamic>>> _batchFetchUserProfiles(
    List<String> userIds,
  ) async {
    if (userIds.isEmpty) return {};

    final profiles = <String, Map<String, dynamic>>{};

    // Firestore 'in' queries are limited to 10 items, so batch in chunks
    const chunkSize = 10;
    for (int i = 0; i < userIds.length; i += chunkSize) {
      final chunk = userIds.skip(i).take(chunkSize).toList();

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final doc in snapshot.docs) {
        profiles[doc.id] = doc.data();
      }
    }

    return profiles;
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    _showSnack('Invite code copied');
  }

  Future<void> _extendExpiry() async {
    setState(() {
      _extendingExpiry = true;
    });

    try {
      final newExpiry = InviteUtils.nextExpiry();
      await _walkRef.update({
        'shareCodeExpiresAt': Timestamp.fromDate(newExpiry),
      });
      _showSnack('Invite extended to ${_formatAbsolute(newExpiry)}');
    } catch (error) {
      _showSnack('Unable to extend invite right now.');
    } finally {
      if (mounted) {
        setState(() {
          _extendingExpiry = false;
        });
      }
    }
  }

  Future<void> _regenerateShareCode() async {
    setState(() {
      _rotatingCode = true;
    });

    try {
      final newCode = InviteUtils.generateShareCode();
      final newExpiry = InviteUtils.nextExpiry();
      await _walkRef.update({
        'shareCode': newCode,
        'shareCodeExpiresAt': Timestamp.fromDate(newExpiry),
      });
      _showSnack('Invite code regenerated');
    } catch (_) {
      _showSnack('Unable to regenerate invite code.');
    } finally {
      if (mounted) {
        setState(() {
          _rotatingCode = false;
        });
      }
    }
  }

  Future<void> _revokeInvite(String userId) async {
    if (_revoking.contains(userId)) return;
    setState(() {
      _revoking.add(userId);
    });

    try {
      await _inviteService.revokeInvite(
        walkId: widget.event.firestoreId,
        userId: userId,
      );
      _showSnack('Invite revoked');
    } catch (_) {
      _showSnack('Unable to revoke invite right now.');
    } finally {
      if (mounted) {
        setState(() {
          _revoking.remove(userId);
        });
      }
    }
  }

  DateTime? _asDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return null;
  }

  String _expiryDescription(DateTime? expiresAt) {
    if (expiresAt == null) {
      return 'No expiry set';
    }

    final now = DateTime.now().toUtc();
    if (expiresAt.isBefore(now)) {
      final elapsed = now.difference(expiresAt);
      if (elapsed.inDays >= 1) {
        return 'Expired ${elapsed.inDays}d ago';
      }
      if (elapsed.inHours >= 1) {
        return 'Expired ${elapsed.inHours}h ago';
      }
      return 'Expired recently';
    }

    final remaining = expiresAt.difference(now);
    if (remaining.inDays >= 1) {
      return 'Expires in ${remaining.inDays}d';
    }
    if (remaining.inHours >= 1) {
      return 'Expires in ${remaining.inHours}h';
    }
    return 'Expires in ${remaining.inMinutes}m';
  }

  String _formatAbsolute(DateTime dateTime) {
    final local = dateTime.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year • $hour:$minute';
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _InviteeListTile extends StatelessWidget {
  const _InviteeListTile({
    required this.userId,
    required this.displayName,
    required this.photoUrl,
    required this.redeemedAt,
    required this.onRevoke,
    required this.isRevoking,
  });

  final String userId;
  final String? displayName;
  final String? photoUrl;
  final DateTime? redeemedAt;
  final VoidCallback onRevoke;
  final bool isRevoking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Use provided data instead of fetching from Firestore
    final rawName = displayName?.trim();
    final effectiveDisplayName = (rawName != null && rawName.isNotEmpty)
        ? rawName
        : 'User ${_shortId(userId)}';
    final effectivePhotoUrl = photoUrl?.trim();

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: theme.colorScheme.primary.withAlpha(30),
        backgroundImage:
            (effectivePhotoUrl != null && effectivePhotoUrl.isNotEmpty)
            ? NetworkImage(effectivePhotoUrl)
            : null,
        child: (effectivePhotoUrl == null || effectivePhotoUrl.isEmpty)
            ? Text(
                effectiveDisplayName.isNotEmpty
                    ? effectiveDisplayName.substring(0, 1).toUpperCase()
                    : '?',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              )
            : null,
      ),
      title: Text(
        effectiveDisplayName,
        style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
      ),
      subtitle: Text(
        _formatRedeemedAt(redeemedAt),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withAlpha(160),
        ),
      ),
      trailing: isRevoking
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              tooltip: 'Revoke invite',
              icon: const Icon(Icons.block),
              onPressed: onRevoke,
            ),
    );
  }

  String _shortId(String value) {
    if (value.length <= 6) return value;
    return value.substring(0, 6);
  }

  String _formatRedeemedAt(DateTime? redeemedAt) {
    if (redeemedAt == null) {
      return 'Awaiting redemption';
    }

    final local = redeemedAt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);

    if (diff.inDays >= 1) {
      return 'Redeemed ${diff.inDays}d ago';
    }
    if (diff.inHours >= 1) {
      return 'Redeemed ${diff.inHours}h ago';
    }
    final minutes = diff.inMinutes;
    if (minutes <= 0) {
      return 'Redeemed just now';
    }
    return 'Redeemed ${minutes}m ago';
  }
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  bool _didConfirmParticipation = false;
  Stream<WalkEvent?>? _walkStream;

  static const double _photoThumbSize = 78;
  static const double _photoThumbPadding = 6;

  @override
  void initState() {
    super.initState();
    _didConfirmParticipation = _isCurrentUserConfirmed(widget.event);
    _initWalkStream();
  }

  void _initWalkStream() {
    final walkId = widget.event.firestoreId.isNotEmpty 
        ? widget.event.firestoreId 
        : widget.event.id;
    
    if (walkId.isEmpty) {
      _walkStream = null;
      return;
    }

    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    _walkStream = FirebaseFirestore.instance
        .collection('walks')
        .doc(walkId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      try {
        final data = Map<String, dynamic>.from(snapshot.data()!);
        data['firestoreId'] = snapshot.id;
        data['id'] ??= snapshot.id;

        final hostUid = data['hostUid'] as String?;
        data['isOwner'] = currentUid != null && hostUid == currentUid;

        final joinedUids = (data['joinedUids'] as List?)?.whereType<String>().toList() ?? [];
        data['joined'] = currentUid != null && joinedUids.contains(currentUid);

        return WalkEvent.fromMap(data);
      } catch (e) {
        debugPrint('Error parsing walk update: $e');
        return null;
      }
    });
  }

  bool _isCurrentUserConfirmed(WalkEvent event) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    return event.participantStates[uid] == 'confirmed';
  }

  String _formatDateTime(DateTime dt) {
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yyyy = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy • $hh:$min';
  }

  void _openPhotoViewer(List<String> urls, int initialIndex) {
    if (urls.isEmpty) return;

    final pageController = PageController(initialPage: initialIndex);
    final currentIndex = ValueNotifier<int>(initialIndex);

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).pop(),
          child: Scaffold(
            backgroundColor: Colors.black54,
            body: SafeArea(
              child: Center(
                child: GestureDetector(
                  onTap: () {},
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final maxWidth = constraints.maxWidth * 0.85;
                      final maxHeight = constraints.maxHeight * 0.7;

                      return SizedBox(
                        width: maxWidth,
                        height: maxHeight,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Stack(
                            children: [
                              PageView.builder(
                                controller: pageController,
                                onPageChanged: (index) {
                                  currentIndex.value = index;
                                },
                                itemCount: urls.length,
                                itemBuilder: (context, index) {
                                  final url = urls[index];

                                  return Container(
                                    color: Colors.black,
                                    child: Center(
                                      child: Image.network(
                                        url,
                                        fit: BoxFit.contain,
                                        loadingBuilder:
                                            (context, child, loadingProgress) {
                                          if (loadingProgress == null) {
                                            return child;
                                          }
                                          return const SizedBox(
                                            height: 40,
                                            width: 40,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 3,
                                              color: Colors.white,
                                            ),
                                          );
                                        },
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return const Icon(
                                            Icons.broken_image_outlined,
                                            size: 48,
                                            color: Colors.white70,
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                              if (urls.length > 1)
                                Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: ValueListenableBuilder<int>(
                                      valueListenable: currentIndex,
                                      builder: (context, value, _) {
                                        return Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: List.generate(urls.length, (
                                            index,
                                          ) {
                                            final isActive = index == value;
                                            return AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 180,
                                              ),
                                              margin: const EdgeInsets.symmetric(
                                                horizontal: 3,
                                              ),
                                              width: isActive ? 8 : 6,
                                              height: isActive ? 8 : 6,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: isActive
                                                    ? Colors.white70
                                                    : Colors.white38,
                                              ),
                                            );
                                          }),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWalkPhotoGallery(
    WalkEvent event,
    ThemeData theme,
    bool isDark,
  ) {
    if (event.photoUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Walk photos',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: _photoThumbSize + _photoThumbPadding * 2,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: event.photoUrls.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final url = event.photoUrls[index];

              return InkWell(
                onTap: () => _openPhotoViewer(event.photoUrls, index),
                borderRadius: BorderRadius.circular(14),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: _photoThumbSize,
                    height: _photoThumbSize,
                    color: isDark
                        ? Colors.white.withAlpha((0.08 * 255).round())
                        : Colors.black.withAlpha((0.04 * 255).round()),
                    child: Image.network(
                      url,
                      fit: BoxFit.cover,
                      cacheWidth: 240,
                      cacheHeight: 240,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: 24,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ✅ Match Nearby/Home “pill” style
  Widget _eventPill({
    required bool isDark,
    required ThemeData theme,
    required IconData icon,
    required String label,
    bool danger = false,
    Color? iconColorOverride,
  }) {
    final bg = danger
        ? theme.colorScheme.error.withAlpha(
            (isDark ? 0.14 : 0.10 * 255).round(),
          )
        : (isDark
              ? Colors.white.withAlpha((0.06 * 255).round())
              : theme.colorScheme.surface);

    final border = danger
        ? theme.colorScheme.error.withAlpha(
            (isDark ? 0.45 : 0.35 * 255).round(),
          )
        : (isDark
              ? Colors.white.withAlpha((0.18 * 255).round())
              : Colors.black.withAlpha((0.12 * 255).round()));

    final fg = danger
        ? theme.colorScheme.error
        : (isDark ? Colors.white : Colors.black87);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColorOverride ?? fg),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Build host rating badge for walk cards
  Widget _buildHostRatingBadge(BuildContext context, String hostUid) {
    final theme = Theme.of(context);

    return FutureBuilder<Map<String, dynamic>>(
      future: HostRatingService.instance.getHostRating(hostUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final ratingData = snapshot.data!;
        final rating = ratingData['rating'] as double? ?? 5.0;
        final reviewCount = ratingData['reviewCount'] as int? ?? 0;

        // Only show if host has reviews
        if (reviewCount == 0) {
          return const SizedBox.shrink();
        }

        final tier = HostRatingService.getRatingTier(rating);
        final emoji = HostRatingService.getRatingEmoji(rating);

        return Row(
          children: [
            Text(
              emoji,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
            ),
            const SizedBox(width: 4),
            Text(
              '$rating • $tier',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: Colors.amber[700],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final theme = Theme.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this walk?'),
        content: const Text(
          'Are you sure you want to cancel this walk? '
          'Participants will no longer see it as active.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep walk'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            child: const Text('Cancel walk'),
          ),
        ],
      ),
    );

    if (ok == true) {
      if (!context.mounted) return;
      widget.onCancelHosted(widget.event);
      Navigator.pop(context); // close details
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Walk cancelled')));
    }
  }

  Future<void> _confirmCancelSingle(BuildContext context) async {
    final theme = Theme.of(context);
    final dateStr =
        '${widget.event.dateTime.day}/${widget.event.dateTime.month}/${widget.event.dateTime.year}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this occurrence?'),
        content: Text(
          'This will only cancel this single walk on $dateStr. '
          'Other walks in the series will remain active.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep walk'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            child: const Text('Cancel this occurrence'),
          ),
        ],
      ),
    );

    if (ok == true) {
      if (!context.mounted) return;
      widget.onCancelHosted(widget.event);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Walk occurrence cancelled')),
      );
    }
  }

  Future<void> _confirmCancelAllFuture(BuildContext context) async {
    final theme = Theme.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel all future walks?'),
        content: const Text(
          'This will cancel all future walks in this recurring series. '
          'Past walks will remain visible. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep walks'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            child: const Text('Cancel all future'),
          ),
        ],
      ),
    );

    if (ok == true) {
      if (!context.mounted) return;

      final groupId = widget.event.recurringGroupId;
      if (groupId == null || groupId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: No recurring group ID found')),
        );
        return;
      }

      try {
        await RecurringWalkService.cancelAllFutureInstances(groupId);
        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All future walks cancelled')),
        );
        Navigator.pop(context);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error cancelling walks: $e')));
      }
    }
  }

  Future<void> _openReportDialog(BuildContext context) async {
    final noteController = TextEditingController();
    final reasons = [
      'Fake event',
      'Inappropriate behaviour or harassment',
      'User lied about their gender',
      'Unsafe location or behaviour',
      'Wrong location or time',
      'No-show / did not appear',
      'Other',
    ];
    String selectedReason = reasons.first;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Report walk or user'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...reasons.map(
                      (reason) => ListTile(
                        title: Text(reason),
                        leading: Icon(
                          selectedReason == reason
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: Theme.of(ctx).colorScheme.primary,
                        ),
                        onTap: () {
                          setState(() {
                            selectedReason = reason;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: noteController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Additional details (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok == true) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Thank you. Your report was submitted: $selectedReason',
          ),
        ),
      );
    }
  }

  // ===== CP-4: Host Control Methods =====

  /// Build host control buttons (Start/End walk)
  Widget _buildHostControlButtons(
    BuildContext context,
    WalkEvent event,
    ThemeData theme,
    bool isDark,
  ) {
    return Column(
      children: [
        // Show start button if walk hasn't started
        if (event.status == 'scheduled') ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _startWalk(context, event),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                backgroundColor: const Color(0xFF00D97E),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Walk'),
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Show end button if walk is starting or in progress
        if (event.status == 'active') ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _endWalk(context, event),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                backgroundColor: Colors.orange[600],
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('End Walk'),
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Show participant count if walk has started
        if (event.status == 'active') ...[
          FutureBuilder<int>(
            future: WalkControlService.instance.getActiveParticipantCount(
              event.firestoreId,
            ),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withAlpha((0.06 * 255).round())
                      : Colors.black.withAlpha((0.05 * 255).round()),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withAlpha((0.18 * 255).round())
                        : Colors.black.withAlpha((0.12 * 255).round()),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.group, color: const Color(0xFF00D97E), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '$count participants registered',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  /// Build participant confirmation button (shown when walk starts)
  Widget _buildParticipantConfirmationButton(
    BuildContext context,
    WalkEvent event,
    ThemeData theme,
    bool isDark,
  ) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _confirmParticipation(context, event),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: const Color(0xFF00D97E),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.check_circle),
            label: const Text('Register - I\'m Joining Now'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _declineParticipation(context, event),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Decline - I\'m Not Coming'),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ===== CP-4: Walk Control Actions =====

  Future<void> _startWalk(BuildContext context, WalkEvent event) async {
    try {
      await WalkControlService.instance.startWalk(event.firestoreId);

      // Start GPS tracking for the host
      await GPSTrackingService.instance.startTracking(event.firestoreId);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Walk started! GPS tracking enabled...'),
        ),
      );
      // Refresh the screen
      setState(() {});
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Error starting walk: $e')));
    }
  }

  Future<void> _endWalk(BuildContext context, WalkEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End this walk?'),
        content: const Text(
          'All participants will be marked as completed. '
          'Their walk statistics will be calculated and saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep walking'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End Walk'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Stop GPS tracking and persist stats server-side
      await GPSTrackingService.instance.stopTracking(event.firestoreId);

      // End the walk on Firestore
      await WalkControlService.instance.endWalk(event.firestoreId);

      if (!context.mounted) return;

      // Navigate to summary screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) =>
              WalkSummaryScreen(walkId: event.firestoreId, initialWalk: event),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Error ending walk: $e')));
    }
  }

  Future<void> _confirmParticipation(
    BuildContext context,
    WalkEvent event,
  ) async {
    try {
      await WalkHistoryService.instance.confirmParticipation(event.firestoreId);
      await GPSTrackingService.instance.startTracking(event.firestoreId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Registered! You\'re walking with us!')),
      );
      setState(() {
        _didConfirmParticipation = true;
      });
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Error confirming: $e')));
    }
  }

  void _openActiveWalkScreen(BuildContext context, WalkEvent event) {
    final walkId = event.firestoreId.isNotEmpty ? event.firestoreId : event.id;
    if (walkId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open active walk right now.')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActiveWalkScreen(walkId: walkId, initialWalk: event),
      ),
    );
  }

  Future<void> _declineParticipation(
    BuildContext context,
    WalkEvent event,
  ) async {
    try {
      await WalkHistoryService.instance.declineParticipation(event.firestoreId);
      await GPSTrackingService.instance.stopTracking(event.firestoreId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Declined. You can join another time!')),
      );
      setState(() {});
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Error declining: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // If no stream available, fall back to static widget.event
    if (_walkStream == null) {
      return _buildContent(context, widget.event, theme, isDark);
    }

    return StreamBuilder<WalkEvent?>(
      stream: _walkStream,
      initialData: widget.event,
      builder: (context, snapshot) {
        // Use the latest data from stream, or fall back to initial event
        final event = snapshot.data ?? widget.event;
        
        // If walk was deleted, show a message
        if (snapshot.hasData && snapshot.data == null && snapshot.connectionState != ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: isDark ? const Color(0xFF071B26) : const Color(0xFF1ABFC4),
            body: SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: isDark ? Colors.white70 : Colors.white),
                    const SizedBox(height: 16),
                    Text(
                      'This walk is no longer available',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isDark ? Colors.white : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return _buildContent(context, event, theme, isDark);
      },
    );
  }

  Widget _buildContent(BuildContext context, WalkEvent event, ThemeData theme, bool isDark) {
    // Shortcuts to avoid widget. prefix everywhere
    final onToggleJoin = widget.onToggleJoin;
    final onToggleInterested = widget.onToggleInterested;

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final participantState = currentUid != null
        ? event.participantStates[currentUid]
        : null;
    final bool isConfirmed =
        _didConfirmParticipation || participantState == 'confirmed';

    final canJoin = !event.isOwner && !event.cancelled;
    final joinText = event.joined
        ? (event.status == 'active' ? 'Leave Walk' : 'Cancel Join')
        : 'Join walk';

    final canInterested = !event.isOwner && !event.cancelled;
    final interestedText = event.interested
        ? 'Remove from interested'
        : 'Mark as interested';

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF071B26)
          : const Color(0xFF1ABFC4),
      body: Column(
        children: [
          // ===== HEADER (match Home/Nearby sizing) =====
          if (isDark)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 18,
                      ),
                      splashRadius: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              height: 64,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1ABFC4), Color(0xFF1DB8C0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: 18,
                        ),
                        splashRadius: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          event.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ===== MAIN AREA (same structure as other screens) =====
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  gradient: isDark
                      ? const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFF071B26), // top (dark blue)
                            Color(0xFF041016), // bottom (almost black)
                          ],
                        )
                      : null,
                  color: isDark ? null : const Color(0xFFF7F9F2),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),

                  child: Card(
                    color: isDark
                        ? const Color(0xFF0C2430)
                        : const Color(0xFFFBFEF8),
                    elevation: isDark ? 0.0 : 0.6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(
                        color: (isDark ? Colors.white : Colors.black).withAlpha(
                          (0.06 * 255).round(),
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title inside card
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  event.title,
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF111827),
                                      ),
                                ),
                              ),
                              if (event.interested)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withAlpha(
                                      (0.15 * 255).round(),
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: Colors.amber.withAlpha(
                                        (0.35 * 255).round(),
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.star,
                                        size: 14,
                                        color: Colors.amber,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Interested',
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.labelSmall?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: Colors.amber,
                                            ) ??
                                            const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.amber,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Date & time
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 18,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDateTime(event.dateTime),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // ✅ Pills (match Nearby look)
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _eventPill(
                                isDark: isDark,
                                theme: theme,
                                icon: Icons.straighten,
                                label:
                                    '${event.distanceKm.toStringAsFixed(1)} km',
                                iconColorOverride: isDark
                                    ? Colors.white70
                                    : Colors.black54,
                              ),
                              _eventPill(
                                isDark: isDark,
                                theme: theme,
                                icon: Icons.directions_walk,
                                label: event.pace,
                                iconColorOverride: isDark
                                    ? Colors.white70
                                    : Colors.black54,
                              ),
                              _eventPill(
                                isDark: isDark,
                                theme: theme,
                                icon: Icons.person,
                                label: event.gender,
                                iconColorOverride: isDark
                                    ? Colors.white70
                                    : Colors.black54,
                              ),
                              if (event.isOwner)
                                _eventPill(
                                  isDark: isDark,
                                  theme: theme,
                                  icon: Icons.star,
                                  label: 'You are hosting',
                                  iconColorOverride: isDark
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                              if (event.cancelled)
                                _eventPill(
                                  isDark: isDark,
                                  theme: theme,
                                  icon: Icons.error_outline,
                                  label: 'Cancelled',
                                  danger: true,
                                ),
                              if (event.isRecurring &&
                                  !event.isRecurringTemplate)
                                _eventPill(
                                  isDark: isDark,
                                  theme: theme,
                                  icon: Icons.repeat,
                                  label: 'Recurring',
                                  iconColorOverride: theme.colorScheme.primary,
                                ),
                            ],
                          ),

                          if (event.isRecurring &&
                              !event.isRecurringTemplate &&
                              event.recurrence != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer
                                    .withAlpha((0.3 * 255).round()),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: theme.colorScheme.primary.withAlpha(
                                    (0.3 * 255).round(),
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.repeat,
                                        size: 18,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Part of a recurring series',
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: isDark
                                                  ? Colors.white
                                                  : theme.colorScheme.primary,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    event.recurrence!.getDescription(),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),

                          // Meeting point
                          Text(
                            'Meeting point',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (event.meetingPlaceName != null &&
                              event.meetingPlaceName!.trim().isNotEmpty)
                            Text(
                              event.meetingPlaceName!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            )
                          else if (event.startLat != null &&
                              event.startLng != null &&
                              event.endLat != null &&
                              event.endLng != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Start: ${event.startLat!.toStringAsFixed(5)}, ${event.startLng!.toStringAsFixed(5)}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                ),
                                Text(
                                  'End: ${event.endLat!.toStringAsFixed(5)}, ${event.endLng!.toStringAsFixed(5)}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              event.meetingLat != null &&
                                      event.meetingLng != null
                                  ? 'Lat: ${event.meetingLat!.toStringAsFixed(5)}, '
                                        'Lng: ${event.meetingLng!.toStringAsFixed(5)}'
                                  : 'Custom location (no coordinates)',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),

                          const SizedBox(height: 16),

                          // ===== HOSTED BY CARD =====
                          Text(
                            'Hosted by',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withAlpha((0.05 * 255).round())
                                  : Colors.black.withAlpha(
                                      (0.03 * 255).round(),
                                    ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: (isDark ? Colors.white : Colors.black)
                                    .withAlpha((0.08 * 255).round()),
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: theme.colorScheme.primary
                                      .withAlpha((0.2 * 255).round()),
                                  backgroundImage:
                                      (event.hostPhotoUrl != null &&
                                          event.hostPhotoUrl!.isNotEmpty)
                                      ? NetworkImage(event.hostPhotoUrl!)
                                      : null,
                                  child:
                                      (event.hostPhotoUrl == null ||
                                          event.hostPhotoUrl!.isEmpty)
                                      ? Icon(
                                          Icons.person,
                                          size: 28,
                                          color: theme.colorScheme.primary,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        event.hostName ??
                                            'Host ${event.hostUid.substring(0, 6)}',
                                        style: theme.textTheme.bodyLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      _buildHostRatingBadge(
                                        context,
                                        event.hostUid,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ===== PEOPLE JOINING =====
                          Text(
                            'People joining',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              // Overlapping avatars
                              SizedBox(
                                width: event.joinedUserPhotoUrls.isEmpty
                                    ? 88
                                    : (event.joinedUserPhotoUrls.length > 4
                                          ? 120
                                          : (event.joinedUserPhotoUrls.length *
                                                    24.0 +
                                                16)),
                                height: 40,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    if (event.joinedUserPhotoUrls.isEmpty)
                                    // Show 3 placeholder avatars when no one joined
                                    ...[
                                      Positioned(
                                        left: 0,
                                        child: CircleAvatar(
                                          radius: 20,
                                          backgroundColor: Colors.grey
                                              .withAlpha((0.3 * 255).round()),
                                          child: Icon(
                                            Icons.person_outline,
                                            size: 20,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        left: 24,
                                        child: CircleAvatar(
                                          radius: 20,
                                          backgroundColor: Colors.grey
                                              .withAlpha((0.3 * 255).round()),
                                          child: Icon(
                                            Icons.person_outline,
                                            size: 20,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        left: 48,
                                        child: CircleAvatar(
                                          radius: 20,
                                          backgroundColor: Colors.grey
                                              .withAlpha((0.3 * 255).round()),
                                          child: Icon(
                                            Icons.person_outline,
                                            size: 20,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                    ] else
                                      // Show actual participant avatars (max 4)
                                      ...List.generate(
                                        event.joinedUserPhotoUrls.length > 4
                                            ? 4
                                            : event.joinedUserPhotoUrls.length,
                                        (index) {
                                          final photoUrl =
                                              event.joinedUserPhotoUrls[index];
                                          return Positioned(
                                            left: index * 24.0,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: isDark
                                                      ? const Color(0xFF0C2430)
                                                      : const Color(0xFFFBFEF8),
                                                  width: 2,
                                                ),
                                              ),
                                              child: CircleAvatar(
                                                radius: 20,
                                                backgroundColor: theme
                                                    .colorScheme
                                                    .primary
                                                    .withAlpha(
                                                      (0.2 * 255).round(),
                                                    ),
                                                backgroundImage:
                                                    photoUrl.isNotEmpty
                                                    ? NetworkImage(photoUrl)
                                                    : null,
                                                child: photoUrl.isEmpty
                                                    ? Icon(
                                                        Icons.person,
                                                        size: 20,
                                                        color: theme
                                                            .colorScheme
                                                            .primary,
                                                      )
                                                    : null,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                event.joinedCount > 0
                                    ? (event.joinedCount > 4
                                          ? '+${event.joinedCount - 4} others joining'
                                          : event.joinedCount == 1
                                          ? '1 person joining'
                                          : '${event.joinedCount} people joining')
                                    : '+0 others joining',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                            _buildWalkPhotoGallery(event, theme, isDark),

                          // Description
                          if (event.description != null &&
                              event.description!.trim().isNotEmpty) ...[
                            Text(
                              'Description',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              event.description!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Join / leave button
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: canJoin
                                  ? () {
                                      onToggleJoin(event);
                                      Navigator.pop(context);
                                    }
                                  : null,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                backgroundColor: const Color(0xFF00D97E),
                                foregroundColor: Colors.white,
                              ),
                              icon: Icon(
                                event.joined
                                    ? Icons.check_circle_outline
                                    : Icons.directions_walk,
                              ),
                              label: Text(
                                event.isOwner
                                    ? "You're the host"
                                    : (event.cancelled
                                          ? 'Walk cancelled'
                                          : joinText),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Group chat button
                          if ((event.joined || event.isOwner) &&
                              event.firestoreId.isNotEmpty) ...[
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  debugPrint(
                                    'OPEN WALK CHAT: walk_${event.id}',
                                  );
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => WalkChatScreen(
                                        walkId: event.firestoreId,
                                        walkTitle: event.title,
                                      ),
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(52),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                icon: const Icon(Icons.forum_outlined),
                                label: const Text('Chat with participants'),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // CP-4: Host walk control buttons (start/end walk)
                          if (event.isOwner && !event.cancelled) ...[
                            _buildHostControlButtons(
                              context,
                              event,
                              theme,
                              isDark,
                            ),
                          ],

                          if (event.status == 'active' &&
                              (event.isOwner ||
                                  (currentUid != null &&
                                      event.participantStates.containsKey(
                                        currentUid,
                                      )))) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _openActiveWalkScreen(context, event),
                                icon: const Icon(Icons.directions_walk),
                                label: const Text('Open Active Walk'),
                              ),
                            ),
                          ],

                          if (event.isOwner &&
                              !event.cancelled &&
                              event.isPrivate) ...[
                            const SizedBox(height: 16),
                            _PrivateInviteManagement(event: event),
                          ],

                          // CP-4: Participant confirmation button (shown when walk is starting)
                          if (!event.isOwner &&
                              event.joined &&
                              !event.cancelled &&
                              event.status == 'active' &&
                              !isConfirmed) ...[
                            _buildParticipantConfirmationButton(
                              context,
                              event,
                              theme,
                              isDark,
                            ),
                          ],

                          const SizedBox(height: 24),

                          // Host-only cancel button(s)
                          if (event.isOwner && !event.cancelled) ...[
                            if (event.isRecurring &&
                                !event.isRecurringTemplate &&
                                event.recurringGroupId != null) ...[
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(52),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    foregroundColor: theme.colorScheme.error,
                                    side: BorderSide(
                                      color: theme.colorScheme.error,
                                    ),
                                  ),
                                  onPressed: () =>
                                      _confirmCancelSingle(context),
                                  icon: const Icon(Icons.cancel_outlined),
                                  label: const Text('Cancel this occurrence'),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(52),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    foregroundColor: theme.colorScheme.error,
                                    side: BorderSide(
                                      color: theme.colorScheme.error,
                                    ),
                                  ),
                                  onPressed: () =>
                                      _confirmCancelAllFuture(context),
                                  icon: const Icon(Icons.event_busy),
                                  label: const Text('Cancel all future walks'),
                                ),
                              ),
                            ] else
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(52),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    foregroundColor: theme.colorScheme.error,
                                    side: BorderSide(
                                      color: theme.colorScheme.error,
                                    ),
                                  ),
                                  onPressed: () => _confirmCancel(context),
                                  icon: const Icon(Icons.cancel_outlined),
                                  label: const Text('Cancel this walk'),
                                ),
                              ),
                            const SizedBox(height: 16),
                          ],

                          // Interested button
                          SizedBox(
                            width: double.infinity,
                            child: TextButton.icon(
                              onPressed: canInterested
                                  ? () {
                                      onToggleInterested(event);
                                      Navigator.pop(context);
                                    }
                                  : null,
                              icon: Icon(
                                event.interested
                                    ? Icons.star
                                    : Icons.star_border_outlined,
                                color: event.interested ? Colors.amber : null,
                              ),
                              label: Text(interestedText),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Report
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => _openReportDialog(context),
                              icon: const Icon(Icons.flag_outlined),
                              label: const Text('Report'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
