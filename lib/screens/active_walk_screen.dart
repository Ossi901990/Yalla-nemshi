import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/walk_event.dart';
import '../services/crash_service.dart';
import '../services/gps_tracking_service.dart';
import '../services/walk_control_service.dart';
import '../services/walk_history_service.dart';
import '../utils/error_handler.dart';

class ActiveWalkScreen extends StatefulWidget {
  final String walkId;
  final WalkEvent? initialWalk;

  const ActiveWalkScreen({
    super.key,
    required this.walkId,
    this.initialWalk,
  });

  @override
  State<ActiveWalkScreen> createState() => _ActiveWalkScreenState();
}

class _ActiveWalkScreenState extends State<ActiveWalkScreen>
    with SingleTickerProviderStateMixin {
  late final Stream<WalkEvent?> _walkStream;
  WalkEvent? _latestWalk;
  AnimationController? _waveController;
  Timer? _ticker;
  Timer? _trackingPoller;
  late final ValueNotifier<bool> _trackingStatus;

  bool _isEnding = false;
  bool _isConfirming = false;
  bool _isDeclining = false;
  bool _isLeaving = false;

  @override
  void initState() {
    super.initState();
    _walkStream = WalkControlService.instance.watchWalk(widget.walkId);
    _latestWalk = widget.initialWalk;
    _trackingStatus = ValueNotifier<bool>(
      GPSTrackingService.instance.isTracking(widget.walkId),
    );
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _trackingPoller = Timer.periodic(const Duration(seconds: 2), (_) {
      final isTracking = GPSTrackingService.instance.isTracking(widget.walkId);
      if (_trackingStatus.value != isTracking) {
        _trackingStatus.value = isTracking;
      }
    });
    _ensureTrackingForInitialState();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _trackingPoller?.cancel();
    _trackingStatus.dispose();
    _stopTrackingIfNeeded();
    _waveController?.dispose();
    super.dispose();
  }

  void _ensureTicker(WalkEvent? walk) {
    final shouldRun =
        walk != null && walk.status == 'active' && walk.startedAt != null;
    if (!shouldRun) {
      _ticker?.cancel();
      _ticker = null;
      _stopTrackingIfNeeded();
      return;
    }
    if (_ticker != null) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
    _startTrackingIfNeeded(walk);
  }

  void _ensureTrackingForInitialState() {
    final walk = _latestWalk;
    if (walk == null) return;
    if (walk.status == 'active') {
      _startTrackingIfNeeded(walk);
    } else {
      _stopTrackingIfNeeded();
    }
  }

  void _startTrackingIfNeeded([WalkEvent? walk]) {
    final resolved = walk ?? _latestWalk;
    final isHost = resolved != null &&
        FirebaseAuth.instance.currentUser?.uid == resolved.hostUid;
    if (!isHost) return;
    if (!GPSTrackingService.instance.isTracking(widget.walkId)) {
      unawaited(GPSTrackingService.instance.startTracking(widget.walkId));
    }
  }

  void _stopTrackingIfNeeded() {
    if (GPSTrackingService.instance.isTracking(widget.walkId)) {
      unawaited(GPSTrackingService.instance.stopTracking(widget.walkId));
    }
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '--:--';
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  Future<void> _endWalk() async {
    if (_isEnding) return;
    setState(() => _isEnding = true);
    try {
      await WalkControlService.instance.endWalk(widget.walkId);
      await GPSTrackingService.instance.stopTracking(widget.walkId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Walk ended. Collecting stats...')),
      );
    } catch (e, st) {
      CrashService.recordError(e, st);
      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          'Failed to end walk: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _isEnding = false);
    }
  }

  Future<void> _confirmParticipation() async {
    if (_isConfirming) return;
    setState(() => _isConfirming = true);
    try {
      await WalkHistoryService.instance.confirmParticipation(widget.walkId);
      await GPSTrackingService.instance.startTracking(widget.walkId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Great! You\'re marked as walking.')),
      );
    } catch (e, st) {
      CrashService.recordError(e, st);
      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          'Could not confirm participation: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  Future<void> _declineParticipation() async {
    if (_isDeclining) return;
    setState(() => _isDeclining = true);
    try {
      await WalkHistoryService.instance.declineParticipation(widget.walkId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No worries - we\'ll see you next time.')),
      );
    } catch (e, st) {
      CrashService.recordError(e, st);
      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          'Unable to decline right now: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _isDeclining = false);
    }
  }

  Future<void> _leaveWalkEarly() async {
    if (_isLeaving) return;
    setState(() => _isLeaving = true);
    try {
      await WalkHistoryService.instance.leaveWalkEarly(widget.walkId);
      await GPSTrackingService.instance.stopTracking(widget.walkId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You left the walk.')),
      );
    } catch (e, st) {
      CrashService.recordError(e, st);
      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          'Could not leave walk: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _isLeaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<WalkEvent?>(
        stream: _walkStream,
        initialData: _latestWalk,
        builder: (context, snapshot) {
          final walk = snapshot.data ?? _latestWalk;
          _ensureTicker(walk);
          if (walk != null) {
            _latestWalk = walk;
          }

          if (walk == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final status = walk.status;
          final isHost = FirebaseAuth.instance.currentUser?.uid == walk.hostUid;
          final participantState = _participantStateFor(walk);
          final elapsed = (walk.startedAt != null && status == 'active')
              ? DateTime.now().difference(walk.startedAt!)
              : null;

          final showFallback = status == 'ended' || status == 'cancelled';

          return Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _waveController!,
                  builder: (context, _) => CustomPaint(
                    painter: _WavePainter(_waveController!.value),
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xAA001F24), Color(0xAA023F3C)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    children: [
                      _buildTopBar(context, status),
                      const SizedBox(height: 16),
                      Expanded(
                        child: showFallback
                            ? _buildFallback(context, status)
                            : _buildScrollContent(
                                context,
                                walk,
                                elapsed,
                                participantState,
                                isHost,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, String status) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        ),
        Chip(
          label: Text(
            status.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          backgroundColor: Colors.white.withAlpha(40),
        ),
      ],
    );
  }

  Widget _buildScrollContent(
    BuildContext context,
    WalkEvent walk,
    Duration? elapsed,
    String? participantState,
    bool isHost,
  ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            walk.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ) ??
                const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          _buildTrackingChips(context, walk),
          const SizedBox(height: 12),
          _buildMetricsCard(context, walk, elapsed),
          const SizedBox(height: 24),
          _buildParticipantsSection(context, walk),
          const SizedBox(height: 24),
          if (isHost) _buildHostControls(context, walk) else
            _buildParticipantControls(context, walk, participantState),
        ],
      ),
    );
  }

  Widget _buildTrackingChips(BuildContext context, WalkEvent walk) {
    final isHost = FirebaseAuth.instance.currentUser?.uid == walk.hostUid;
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: _trackingStatus,
          builder: (context, isTracking, _) {
            return _StatusChip(
              icon: Icons.gps_fixed,
              label: isTracking ? 'Tracking ON' : 'Tracking OFF',
              description: isHost
                  ? 'Host tracking toggles here in Phase 3'
                  : 'Live map sync coming soon',
            );
          },
        ),
        _StatusChip(
          icon: Icons.timer_outlined,
          label: walk.startedAt != null
              ? 'Started ${TimeOfDay.fromDateTime(walk.startedAt!).format(context)}'
              : 'Waiting for start',
          description: walk.startedAt != null
              ? 'Automatic timer running'
              : 'Host can start within the window',
        ),
      ],
    );
  }

  Widget _buildMetricsCard(
    BuildContext context,
    WalkEvent walk,
    Duration? elapsed,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final distanceDisplay = '--.--';
    final durationText = _formatDuration(elapsed);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: isDark
            ? Colors.white.withAlpha(20)
            : Colors.white.withAlpha(30),
        border: Border.all(
          color: Colors.white.withAlpha(60),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Distance',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                distanceDisplay,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 56,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'km',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'GPS feed arrives with Phase 3 - metrics are placeholders for now.',
            style: TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _MetricChip(
                label: 'Elapsed',
                value: durationText,
              ),
              const _MetricChip(
                label: 'Pace',
                value: '--:-- /km',
              ),
              const _MetricChip(
                label: 'Steps',
                value: '--',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsSection(BuildContext context, WalkEvent walk) {
    final data = _buildParticipantTiles(walk);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Participants',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${data.length} attending',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (data.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'No one has joined yet. Invite friends or wait for confirmations.',
              style: TextStyle(color: Colors.white70),
            ),
          )
        else
          Column(
            children:
                data.map((tile) => _ParticipantTile(tile: tile)).toList(),
          ),
      ],
    );
  }

  Widget _buildHostControls(BuildContext context, WalkEvent walk) {
    final isActive = walk.status == 'active';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Host controls',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: isActive && !_isEnding ? _endWalk : null,
            icon: const Icon(Icons.flag_circle),
            label: Text(_isEnding ? 'Ending...' : 'End Walk'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.pause_circle_outline),
            label: const Text('Pause (coming soon)'),
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantControls(
    BuildContext context,
    WalkEvent walk,
    String? participantState,
  ) {
    final isActive = walk.status == 'active';
    final needsConfirmation = isActive && participantState == 'joined';
    final canLeave = isActive && participantState == 'confirmed';

    if (!needsConfirmation && !canLeave) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your status',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 12),
        if (needsConfirmation) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isConfirming ? null : _confirmParticipation,
              icon: const Icon(Icons.check_circle),
                label:
                  Text(_isConfirming ? 'Confirming...' : 'Confirm - I\'m here'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isDeclining ? null : _declineParticipation,
              icon: const Icon(Icons.close),
              label: Text(_isDeclining ? 'Declining...' : 'Decline - Not coming'),
            ),
          ),
        ],
        if (canLeave) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isLeaving ? null : _leaveWalkEarly,
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              icon: const Icon(Icons.exit_to_app),
              label: Text(_isLeaving ? 'Leaving...' : 'Leave Walk'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFallback(BuildContext context, String status) {
    final message = status == 'cancelled'
        ? 'This walk was cancelled by the host.'
        : 'Walk completed! Summary view arrives in Phase 4.';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            status == 'cancelled' ? Icons.cancel : Icons.celebration,
            color: Colors.white,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Back to Home'),
          ),
        ],
      ),
    );
  }

  List<_ParticipantTileData> _buildParticipantTiles(WalkEvent walk) {
    final map = walk.participantStates;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final joinedPhotos = <String, String>{};
    for (var i = 0; i < walk.joinedUserUids.length; i++) {
      final userId = walk.joinedUserUids[i];
      final photo = i < walk.joinedUserPhotoUrls.length
          ? walk.joinedUserPhotoUrls[i]
          : null;
      if (userId.isNotEmpty && photo != null) {
        joinedPhotos[userId] = photo;
      }
    }

    final List<_ParticipantTileData> tiles = [];
    final hostState = map[walk.hostUid] ?? 'confirmed';
    tiles.add(
      _ParticipantTileData(
        userId: walk.hostUid,
        displayName: walk.hostName ?? 'Host',
        state: hostState,
        photoUrl: walk.hostPhotoUrl,
        isHost: true,
        isCurrentUser: uid == walk.hostUid,
      ),
    );

    map.forEach((userId, state) {
      if (userId == walk.hostUid) return;
      tiles.add(
        _ParticipantTileData(
          userId: userId,
          displayName: _friendlyName(userId),
          state: state,
          photoUrl: joinedPhotos[userId],
          isCurrentUser: uid == userId,
        ),
      );
    });

    for (final userId in walk.joinedUserUids) {
      if (userId == walk.hostUid) continue;
      if (map.containsKey(userId)) continue;
      tiles.add(
        _ParticipantTileData(
          userId: userId,
          displayName: _friendlyName(userId),
          state: 'joined',
          photoUrl: joinedPhotos[userId],
          isCurrentUser: uid == userId,
        ),
      );
    }

    return tiles;
  }

  String _friendlyName(String userId) {
    if (userId.length <= 6) return userId;
    return 'User ${userId.substring(0, 6)}';
  }

  String? _participantStateFor(WalkEvent walk) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return walk.participantStates[uid];
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;

  const _StatusChip({
    required this.icon,
    required this.label,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withAlpha(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetricChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withAlpha(25),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticipantTileData {
  final String userId;
  final String displayName;
  final String state;
  final String? photoUrl;
  final bool isHost;
  final bool isCurrentUser;

  _ParticipantTileData({
    required this.userId,
    required this.displayName,
    required this.state,
    this.photoUrl,
    this.isHost = false,
    this.isCurrentUser = false,
  });
}

class _ParticipantTile extends StatelessWidget {
  final _ParticipantTileData tile;

  const _ParticipantTile({required this.tile});

  Color _badgeColor(String state) {
    switch (state) {
      case 'confirmed':
        return const Color(0xFF00D97E);
      case 'joined':
        return Colors.amberAccent;
      case 'left':
      case 'declined':
        return Colors.redAccent;
      default:
        return Colors.blueGrey;
    }
  }

  String _badgeLabel(String state) {
    switch (state) {
      case 'confirmed':
        return 'Confirmed';
      case 'joined':
        return 'Joined';
      case 'left':
        return 'Left';
      case 'declined':
        return 'Declined';
      case 'invited':
        return 'Invited';
      default:
        return state;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withAlpha(12),
        border: tile.isHost
            ? Border.all(color: Colors.tealAccent.withAlpha(120), width: 1.2)
            : null,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white.withAlpha(40),
            backgroundImage: tile.photoUrl != null
                ? NetworkImage(tile.photoUrl!)
                : null,
            child: tile.photoUrl == null
                ? Text(
                    tile.displayName.isNotEmpty
                        ? tile.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(color: Colors.white),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      tile.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (tile.isHost) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.tealAccent.withAlpha(60),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Host',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    if (tile.isCurrentUser && !tile.isHost) ...[
                      const SizedBox(width: 6),
                      const Text(
                        'You',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _badgeColor(tile.state).withAlpha(60),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _badgeLabel(tile.state),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double progress;

  _WavePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..shader = const LinearGradient(
        colors: [Color(0xFF043F40), Color(0xFF0A6F6A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final waveHeight = 18.0;
    final yOffset = size.height * 0.35;
    path.moveTo(0, size.height);
    path.lineTo(0, yOffset);

    for (double x = 0; x <= size.width; x++) {
      final radians = (x / size.width * 2 * math.pi) + (progress * 2 * math.pi);
      final y = waveHeight * math.sin(radians) + yOffset;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
