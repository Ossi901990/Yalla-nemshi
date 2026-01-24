import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/review.dart';
import '../models/walk_event.dart';
import '../models/walk_summary.dart';
import '../services/crash_service.dart';
import '../services/review_service.dart';
import '../services/storage_service.dart';
import '../services/walk_summary_service.dart';

class WalkSummaryScreen extends StatefulWidget {
  const WalkSummaryScreen({
    super.key,
    required this.walkId,
    this.initialWalk,
  });

  final String walkId;
  final WalkEvent? initialWalk;

  static const routeName = '/walk-summary';

  @override
  State<WalkSummaryScreen> createState() => _WalkSummaryScreenState();
}

class _WalkSummaryScreenState extends State<WalkSummaryScreen> {
  final WalkSummaryService _summaryService = WalkSummaryService.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DateFormat _dateFormat = DateFormat('MMM d, h:mm a');

  WalkSummaryData? _summary;
  bool _loading = true;
  bool _error = false;
  bool _reviewSheetAutoPrompted = false;

  GoogleMapController? _mapController;
  Set<Polyline> _polylines = const <Polyline>{};
  LatLngBounds? _routeBounds;
  bool _mapLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadSummary() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final data = await _summaryService.loadSummary(
        widget.walkId,
        initialWalk: widget.initialWalk,
      );
      if (!mounted) return;
      setState(() {
        _summary = data;
        _loading = false;
      });
      if (data.hasRouteTrace) {
        await _loadRoutePolyline();
      } else {
        setState(() => _mapLoading = false);
      }
      _maybePromptForReview();
    } catch (e, st) {
      CrashService.recordError(e, st, reason: 'WalkSummaryScreen._loadSummary');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  void _maybePromptForReview() {
    if (!mounted) return;
    if (_reviewSheetAutoPrompted) return;
    final summary = _summary;
    if (summary == null) return;
    if (summary.reviewSubmitted) return;
    _reviewSheetAutoPrompted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openReviewSheet();
    });
  }

  Future<void> _loadRoutePolyline() async {
    try {
      final snapshot = await _firestore
          .collection('walks')
          .doc(widget.walkId)
          .collection('tracking')
          .orderBy('timestamp')
          .get();

      if (!mounted) return;

      if (snapshot.docs.isEmpty) {
        setState(() => _mapLoading = false);
        return;
      }

      final points = <LatLng>[];
      double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;

      for (final doc in snapshot.docs) {
        final lat = (doc['latitude'] as num).toDouble();
        final lng = (doc['longitude'] as num).toDouble();
        points.add(LatLng(lat, lng));
        minLat = math.min(minLat, lat);
        maxLat = math.max(maxLat, lat);
        minLng = math.min(minLng, lng);
        maxLng = math.max(maxLng, lng);
      }

      final polyline = Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        color: const Color(0xFF1ABFC4),
        width: 5,
        geodesic: true,
      );

      setState(() {
        _polylines = {polyline};
        _routeBounds = LatLngBounds(
          southwest: LatLng(minLat - 0.001, minLng - 0.001),
          northeast: LatLng(maxLat + 0.001, maxLng + 0.001),
        );
        _mapLoading = false;
      });

      await Future.delayed(const Duration(milliseconds: 120));
      final controller = _mapController;
      final bounds = _routeBounds;
      if (controller != null && bounds != null) {
        try {
          await controller.animateCamera(
            CameraUpdate.newLatLngBounds(bounds, 60),
          );
        } catch (_) {
          // Ignore animation failures when map not ready.
        }
      }
    } catch (e, st) {
      CrashService.recordError(e, st, reason: 'WalkSummaryScreen._loadRoutePolyline');
      if (!mounted) return;
      setState(() => _mapLoading = false);
    }
  }

  Future<void> _openReviewSheet() async {
    final summary = _summary;
    if (summary == null) return;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ReviewPromptSheet(
        walkId: widget.walkId,
        hostUid: summary.walk.hostUid,
        isHost: summary.isHost,
        leftEarly: summary.leftEarly,
        existingReview: summary.existingReview,
      ),
    );
    if (!mounted) return;
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks for the review!')),
      );
    }
    await _loadSummary();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error || _summary == null) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            const Text('Unable to load walk summary right now.'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loadSummary,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _loadSummary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _buildHeader(theme),
            const SizedBox(height: 16),
            _buildMapSection(theme),
            const SizedBox(height: 16),
            _buildStatsSection(theme),
            const SizedBox(height: 16),
            _buildTimelineSection(theme),
            if (_summary!.leftEarly) ...[
              const SizedBox(height: 16),
              _buildLeftEarlyBanner(theme),
            ],
            const SizedBox(height: 16),
            _buildReviewSection(theme),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Back to home'),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Walk summary'),
        actions: [
          if (_summary != null)
            IconButton(
              tooltip: 'Leave review',
              onPressed: _openReviewSheet,
              icon: const Icon(Icons.rate_review_outlined),
            ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final summary = _summary!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          summary.walk.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          summary.walk.city ?? 'Unknown location',
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildMapSection(ThemeData theme) {
    if (_mapLoading) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_summary!.hasRouteTrace) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.map_outlined, size: 36),
              const SizedBox(height: 12),
              Text(
                'Route map not available',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    final bounds = _routeBounds;
    final initialTarget = bounds == null
        ? LatLng(
            _summary!.walk.meetingLat ?? 25.2048,
            _summary!.walk.meetingLng ?? 55.2708,
          )
        : LatLng(
            (bounds.southwest.latitude + bounds.northeast.latitude) / 2,
            (bounds.southwest.longitude + bounds.northeast.longitude) / 2,
          );

    return SizedBox(
      height: 220,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: initialTarget, zoom: 12),
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          polylines: _polylines,
          onMapCreated: (controller) => _mapController ??= controller,
        ),
      ),
    );
  }

  Widget _buildStatsSection(ThemeData theme) {
    final summary = _summary!;
    final pace = summary.averagePaceMinutesPerKm;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StatTile(
                  icon: Icons.map_outlined,
                  label: 'Distance',
                  value: _formatDistance(summary.totalDistanceKm),
                ),
                _StatTile(
                  icon: Icons.timelapse,
                  label: 'Duration',
                  value: _formatDuration(summary.duration),
                ),
                _StatTile(
                  icon: Icons.speed,
                  label: 'Avg pace',
                  value: pace == null ? '--' : '${pace.toStringAsFixed(1)} min/km',
                ),
                _StatTile(
                  icon: Icons.directions_walk,
                  label: 'Avg speed',
                  value: _formatSpeed(summary.averageSpeedMph),
                ),
                _StatTile(
                  icon: Icons.bolt,
                  label: 'Max speed',
                  value: _formatSpeed(summary.maxSpeedMph),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineSection(ThemeData theme) {
    final summary = _summary!;
    final start = summary.startedAt;
    final end = summary.completedAt;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Timeline',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _TimelineRow(
              icon: Icons.play_circle_outline,
              label: 'Started',
              value: start == null ? '--' : _dateFormat.format(start),
            ),
            const SizedBox(height: 8),
            _TimelineRow(
              icon: Icons.flag_circle_outlined,
              label: 'Ended',
              value: end == null ? '--' : _dateFormat.format(end),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftEarlyBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_outlined, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'You left this walk early. Stats reflect the time you spent with the group.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewSection(ThemeData theme) {
    final summary = _summary!;
    final review = summary.existingReview;
    if (review == null) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Share your experience',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Rate the walk and help the host improve future events.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _openReviewSheet,
                child: const Text('Rate & review'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.rate_review_outlined),
                const SizedBox(width: 8),
                Text(
                  'Your review',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _RatingBadges(review: review),
            if ((review.reviewText ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(review.reviewText ?? '', style: theme.textTheme.bodyMedium),
            ],
            if (review.photoUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (context, index) {
                    final url = review.photoUrls[index];
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(url, width: 100, height: 80, fit: BoxFit.cover),
                    );
                  },
                  separatorBuilder: (_, index) => const SizedBox(width: 8),
                  itemCount: review.photoUrls.length,
                ),
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _openReviewSheet,
              child: const Text('Update review'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDistance(double? km) {
    if (km == null) return '--';
    return '${km.toStringAsFixed(2)} km';
  }

  String _formatDuration(Duration? duration) {
    if (duration == null || duration == Duration.zero) return '--';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours <= 0) {
      return '${minutes}m';
    }
    return '${hours}h ${minutes}m';
  }

  String _formatSpeed(double? mph) {
    if (mph == null || mph <= 0) return '--';
    return '${mph.toStringAsFixed(1)} mph';
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                Text(label, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
              const SizedBox(height: 2),
              Text(value, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

class _RatingBadges extends StatelessWidget {
  const _RatingBadges({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      _ScoreChip(
        label: 'Walk',
        score: review.walkRating,
      ),
    ];
    if (review.hostRating != null) {
      chips.add(_ScoreChip(label: 'Host', score: review.hostRating!));
    }
    return Wrap(spacing: 8, runSpacing: 4, children: chips);
  }
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({required this.label, required this.score});

  final String label;
  final double score;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: const Icon(Icons.star_rate_rounded, color: Colors.amber, size: 18),
      label: Text('$label ${score.toStringAsFixed(1)}'),
    );
  }
}

class _ReviewPromptSheet extends StatefulWidget {
  const _ReviewPromptSheet({
    required this.walkId,
    required this.hostUid,
    required this.isHost,
    required this.leftEarly,
    this.existingReview,
  });

  final String walkId;
  final String hostUid;
  final bool isHost;
  final bool leftEarly;
  final Review? existingReview;

  @override
  State<_ReviewPromptSheet> createState() => _ReviewPromptSheetState();
}

class _ReviewPromptSheetState extends State<_ReviewPromptSheet> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _controller = TextEditingController();

  late double _walkRating;
  double? _hostRating;
  bool _submittingReview = false;
  final List<_ReviewPhotoDraft> _drafts = [];
  late List<String> _retainedPhotoUrls;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingReview;
    _walkRating = existing?.walkRating ?? 5;
    _hostRating = widget.isHost ? null : (existing?.hostRating ?? 5);
    _controller.text = existing?.reviewText ?? '';
    _retainedPhotoUrls = List<String>.from(existing?.photoUrls ?? const []);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    try {
      final files = await _picker.pickMultiImage(imageQuality: 80);
      if (files.isEmpty) return;
      final drafts = <_ReviewPhotoDraft>[];
      for (final file in files) {
        if (_drafts.length + _retainedPhotoUrls.length + drafts.length >= 6) break;
        final bytes = await file.readAsBytes();
        drafts.add(_ReviewPhotoDraft(bytes));
      }
      if (!mounted) return;
      setState(() => _drafts.addAll(drafts));
    } catch (e, st) {
      CrashService.recordError(e, st, reason: 'ReviewPrompt.pickPhotos');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to pick photos right now.')),
      );
    }
  }

  Future<void> _submit() async {
    if (_submittingReview) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in to leave a review.')),
      );
      return;
    }
    const logTag = '[ReviewSubmit]';
    final retainedCount = _retainedPhotoUrls.length;
    debugPrint(
      '$logTag start walk=${widget.walkId} walkRating=$_walkRating hostRating=${_hostRating ?? 'n/a'} '
      'drafts=${_drafts.length} retained=$retainedCount',
    );
    CrashService.log(
      '$logTag Begin submit walk=${widget.walkId} user=${user.uid} drafts=${_drafts.length}',
    );

    setState(() => _submittingReview = true);
    try {
      var newPhotoUrls = <String>[];
      try {
        newPhotoUrls = await _uploadDraftPhotos(user.uid, logTag);
      } on FirebaseException catch (e, st) {
        if (e.plugin == 'firebase_storage') {
          debugPrint('$logTag upload blocked: ${e.message ?? e.code}');
          CrashService.recordError(e, st, reason: 'ReviewPrompt.uploadBlocked');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Photo upload blocked by storage rules: ${e.message ?? e.code}',
                ),
              ),
            );
          }
          return;
        }
        rethrow;
      }
      final combinedPhotos = [..._retainedPhotoUrls, ...newPhotoUrls];
      final reviewText = _controller.text.trim();

      debugPrint('$logTag Firestore write begin walk=${widget.walkId}');
      CrashService.log('$logTag Writing review doc for walk=${widget.walkId}');
      await ReviewService.addReview(
        walkId: widget.walkId,
        hostUid: widget.hostUid,
        userId: user.uid,
        userName: user.displayName ?? 'Anonymous',
        userProfileUrl: user.photoURL,
        walkRating: _walkRating,
        hostRating: widget.isHost ? null : _hostRating,
        reviewText: reviewText.isEmpty ? null : reviewText,
        photoUrls: combinedPhotos,
        leftEarly: widget.leftEarly,
        reviewerIsHost: widget.isHost,
      );
      debugPrint('$logTag Firestore write success walk=${widget.walkId}');
      CrashService.log('$logTag Review saved walk=${widget.walkId}');

      if (!mounted) return;
      Navigator.of(context).pop(true);
      debugPrint('$logTag Success - sheet closed');
    } catch (e, st) {
      debugPrint('$logTag Error: $e');
      CrashService.recordError(e, st, reason: 'ReviewPrompt.submit');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to submit review: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _submittingReview = false);
      }
      debugPrint('$logTag completed submit cycle');
    }
  }

  Future<List<String>> _uploadDraftPhotos(String userId, String logTag) async {
    final urls = <String>[];
    for (var i = 0; i < _drafts.length; i++) {
      final draft = _drafts[i];
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i';
      debugPrint('$logTag Uploading photo $i for walk=${widget.walkId}');
      CrashService.log('$logTag Upload start path=walk_reviews/${widget.walkId}/$userId/$fileName.jpg');
      final url = await StorageService.uploadReviewPhoto(
        walkId: widget.walkId,
        userId: userId,
        photoBytes: draft.bytes,
        contentType: 'image/jpeg',
        fileName: fileName,
      );
      debugPrint('$logTag Upload success photo $i');
      CrashService.log('$logTag Upload success path=walk_reviews/${widget.walkId}/$userId/$fileName.jpg');
      urls.add(url);
    }
    return urls;
  }

  void _removeDraft(String id) {
    setState(() => _drafts.removeWhere((draft) => draft.id == id));
  }

  void _removeExistingPhoto(String url) {
    setState(() => _retainedPhotoUrls.remove(url));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 24, 16, bottomInset + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rate_review_outlined),
              const SizedBox(width: 8),
              Text(
                widget.existingReview == null ? 'Rate this walk' : 'Update your review',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (widget.leftEarly)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Looks like you left early. Let the host know what happened.',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange.shade700),
              ),
            ),
          const SizedBox(height: 16),
          Text('Walk rating', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          _StarSelector(value: _walkRating, onChanged: (value) => setState(() => _walkRating = value)),
          const SizedBox(height: 16),
          if (!widget.isHost) ...[
            Text('Host rating', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _StarSelector(
              value: _hostRating ?? 5,
              onChanged: (value) => setState(() => _hostRating = value),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _controller,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Share more (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          _PhotoPickerRow(
            retainedPhotoUrls: _retainedPhotoUrls,
            drafts: _drafts,
            onAddPhotos: _pickPhotos,
            onRemoveDraft: _removeDraft,
            onRemoveExisting: _removeExistingPhoto,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
                onPressed: _submittingReview ? null : _submit,
                child: _submittingReview
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.existingReview == null ? 'Submit review' : 'Save changes'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewPhotoDraft {
  _ReviewPhotoDraft(this.bytes)
      : id = DateTime.now().microsecondsSinceEpoch.toString();

  final String id;
  final Uint8List bytes;
}

class _PhotoPickerRow extends StatelessWidget {
  const _PhotoPickerRow({
    required this.retainedPhotoUrls,
    required this.drafts,
    required this.onAddPhotos,
    required this.onRemoveDraft,
    required this.onRemoveExisting,
  });

  final List<String> retainedPhotoUrls;
  final List<_ReviewPhotoDraft> drafts;
  final VoidCallback onAddPhotos;
  final void Function(String id) onRemoveDraft;
  final void Function(String url) onRemoveExisting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = <Widget>[];

    for (final url in retainedPhotoUrls) {
      items.add(_PhotoPreview(
        image: Image.network(url, fit: BoxFit.cover),
        onRemove: () => onRemoveExisting(url),
      ));
    }

    for (final draft in drafts) {
      items.add(
        _PhotoPreview(
          image: Image.memory(draft.bytes, fit: BoxFit.cover),
          onRemove: () => onRemoveDraft(draft.id),
        ),
      );
    }

    items.add(
      InkWell(
        onTap: onAddPhotos,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
          ),
          child: const Center(child: Icon(Icons.add_a_photo_outlined)),
        ),
      ),
    );

    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) => items[index],
        separatorBuilder: (_, index) => const SizedBox(width: 12),
        itemCount: items.length,
      ),
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({
    required this.image,
    required this.onRemove,
  });

  final Widget image;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(width: 80, height: 80, child: image),
        ),
        Positioned(
          right: 4,
          top: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(2),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _StarSelector extends StatelessWidget {
  const _StarSelector({
    required this.value,
    required this.onChanged,
  });

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        final filled = starValue <= value;
        return IconButton(
          onPressed: () => onChanged(starValue.toDouble()),
          icon: Icon(
            filled ? Icons.star : Icons.star_border,
            color: filled ? Colors.amber : Colors.grey,
            size: 32,
          ),
        );
      }),
    );
  }
}
