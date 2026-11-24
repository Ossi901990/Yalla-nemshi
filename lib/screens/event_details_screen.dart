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
import '../widgets/participants_row.dart';
import '../widgets/user_avatar.dart';
import 'walk_details/walk_details_view.dart';
import '../theme/app_palette.dart';

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

  /// Host-only doc holding the private walk's invite code and expiry.
  late final DocumentReference<Map<String, dynamic>> _inviteRef;
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
    _inviteRef = _walkRef.collection('private').doc('invite');
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
              stream: _inviteRef.snapshots(),
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
      final db = FirebaseFirestore.instance;
      await db.runTransaction((tx) async {
        final invite = await tx.get(_inviteRef);
        final code = invite.data()?['shareCode']?.toString();
        tx.set(_inviteRef, {
          'shareCodeExpiresAt': Timestamp.fromDate(newExpiry),
        }, SetOptions(merge: true));
        if (code != null && code.isNotEmpty) {
          tx.set(InviteService.codeRef(db, code), {
            'walkId': _walkRef.id,
            'hostUid': widget.event.hostUid,
            'expiresAt': Timestamp.fromDate(newExpiry),
          });
        }
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
      final db = FirebaseFirestore.instance;
      final newCodeRef = InviteService.codeRef(db, newCode);
      await db.runTransaction((tx) async {
        final invite = await tx.get(_inviteRef);
        final clash = await tx.get(newCodeRef);
        if (clash.exists) {
          throw StateError('Invite code collision, try again');
        }
        final oldCode = invite.data()?['shareCode']?.toString();
        // Retire the old code so it can no longer be redeemed.
        if (oldCode != null && oldCode.isNotEmpty && oldCode != newCode) {
          tx.delete(InviteService.codeRef(db, oldCode));
        }
        tx.set(newCodeRef, {
          'walkId': _walkRef.id,
          'hostUid': widget.event.hostUid,
          'expiresAt': Timestamp.fromDate(newExpiry),
        });
        tx.set(_inviteRef, {
          'walkId': _walkRef.id,
          'hostUid': widget.event.hostUid,
          'shareCode': newCode,
          'shareCodeExpiresAt': Timestamp.fromDate(newExpiry),
        }, SetOptions(merge: true));
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
      leading: UserAvatar(
        radius: 22,
        name: effectiveDisplayName,
        photoUrl: effectivePhotoUrl,
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

            final joinedUids =
                (data['joinedUids'] as List?)?.whereType<String>().toList() ??
                [];
            data['joined'] =
                currentUid != null && joinedUids.contains(currentUid);

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
                                                child:
                                                    CircularProgressIndicator(
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
                                              margin:
                                                  const EdgeInsets.symmetric(
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

  Widget _buildWalkPhotoGallery(WalkEvent event, ThemeData theme, bool isDark) {
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
  /// Build participant confirmation button (shown when walk starts)
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
        if (snapshot.hasData &&
            snapshot.data == null &&
            snapshot.connectionState != ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: AppPalette.of(context).background,
            body: SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: AppPalette.of(context).textMuted,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'This walk is no longer available',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppPalette.of(context).text,
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

  Widget _buildContent(
    BuildContext context,
    WalkEvent event,
    ThemeData theme,
    bool isDark,
  ) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isConfirmed =
        _didConfirmParticipation ||
        (currentUid != null &&
            event.participantStates[currentUid] == 'confirmed');

    Widget view(int? activeCount) => WalkDetailsView(
      walk: event,
      currentUid: currentUid,
      isConfirmed: isConfirmed,
      activeCount: activeCount,
      hostRating: _buildHostRatingBadge(context, event.hostUid),
      participants: ParticipantsRow(
        userIds: event.joinedUserUids,
        fallbackNames: event.joinedUserNames,
        isDark: isDark,
      ),
      photos: event.photoUrls.isEmpty
          ? null
          : _buildWalkPhotoGallery(event, theme, isDark),
      inviteTools: event.isOwner && !event.cancelled && event.isPrivate
          ? _PrivateInviteManagement(event: event)
          : null,
      actions: WalkDetailsActions(
        onBack: () => Navigator.of(context).pop(),
        onJoin: () {
          widget.onToggleJoin(event);
          Navigator.pop(context);
        },
        onLeave: () {
          widget.onToggleJoin(event);
          Navigator.pop(context);
        },
        onChat: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WalkChatScreen(
              walkId: event.firestoreId,
              walkTitle: event.title,
            ),
          ),
        ),
        onStart: () => _startWalk(context, event),
        onEnd: () => _endWalk(context, event),
        onOpenActive: () => _openActiveWalkScreen(context, event),
        onConfirmHere: () => _confirmParticipation(context, event),
        onDecline: () => _declineParticipation(context, event),
        onToggleInterested: () {
          widget.onToggleInterested(event);
          Navigator.pop(context);
        },
        onReport: () => _openReportDialog(context),
        onCancel: () => _confirmCancel(context),
        onCancelOccurrence: () => _confirmCancelSingle(context),
        onCancelSeries: () => _confirmCancelAllFuture(context),
      ),
    );

    // Host of an active walk: show how many walkers checked in.
    if (event.isOwner && event.status == 'active') {
      return FutureBuilder<int>(
        future: WalkControlService.instance.getActiveParticipantCount(
          event.firestoreId,
        ),
        builder: (context, snapshot) => view(snapshot.data),
      );
    }
    return view(null);
  }
}
