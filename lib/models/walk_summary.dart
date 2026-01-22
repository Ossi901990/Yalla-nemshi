import 'walk_event.dart';
import 'walk_participation.dart';
import 'review.dart';

/// Aggregated data for displaying the post-walk summary.
class WalkSummaryData {
  const WalkSummaryData({
    required this.walk,
    required this.isHost,
    this.participation,
    this.existingReview,
    this.totalDistanceKm,
    this.durationMinutes,
    this.averageSpeedMph,
    this.maxSpeedMph,
    this.routePointsCount = 0,
    this.reviewSubmitted = false,
  });

  final WalkEvent walk;
  final WalkParticipation? participation;
  final Review? existingReview;
  final bool isHost;
  final bool reviewSubmitted;

  /// Distance recorded by GPS (kilometers).
  final double? totalDistanceKm;

  /// Duration recorded for the walk (minutes).
  final int? durationMinutes;

  /// Average speed recorded on device (mph).
  final double? averageSpeedMph;

  /// Peak speed recorded on device (mph).
  final double? maxSpeedMph;

  /// Count of stored GPS points (zero if no tracking data).
  final int routePointsCount;

  bool get hasRouteTrace => routePointsCount > 1;

  DateTime? get startedAt => walk.startedAt;

  DateTime? get completedAt => walk.completedAt;

  Duration? get duration =>
      durationMinutes != null ? Duration(minutes: durationMinutes!) : null;

  bool get leftEarly {
    final status = participation?.status.toLowerCase() ?? '';
    if (status == 'completed_early' || participation?.leftEarly == true) {
      return true;
    }
    if ((participation?.participationState ?? '') == 'left') {
      return true;
    }
    return false;
  }

  double? get averagePaceMinutesPerKm {
    final distance = totalDistanceKm;
    final minutes = durationMinutes;
    if (distance == null || distance <= 0) return null;
    if (minutes == null || minutes <= 0) return null;
    return minutes / distance;
  }
}
